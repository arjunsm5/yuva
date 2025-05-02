import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:yuva/screens/ui/home_screen.dart';
import 'package:yuva/screens/account/register_screen.dart';
import 'dart:async';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:yuva/utils/app_theme.dart'; // Import AppTheme

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();

  String? _verificationId;
  bool _isLoading = false;
  bool _isPhoneValid = false;
  bool _canResendOtp = false;
  int _resendCountdown = 30;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      setState(() {
        _isPhoneValid = _phoneController.text.length == 10;
      });
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _canResendOtp = false;
      _resendCountdown = 30;
    });

    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          _canResendOtp = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verifyPhoneNumber({bool isResend = false}) async {
    final phoneNumber = '+91${_phoneController.text}';

    if (!_isPhoneValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit phone number'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('Attempting to send OTP to $phoneNumber (Resend: $isResend)');

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('Verification completed: $credential');
          await FirebaseAuth.instance.signInWithCredential(credential);
          await _checkUserRegistration(phoneNumber);
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.code}, ${e.message}');
          String errorMessage;
          switch (e.code) {
            case 'invalid-phone-number':
              errorMessage =
              'The phone number is invalid. Please check and try again.';
              break;
            case 'too-many-requests':
              errorMessage = 'Too many requests. Please try again later.';
              break;
            case 'network-request-failed':
              errorMessage =
              'Network error. Please check your internet connection.';
              break;
            default:
              errorMessage = 'Verification failed: ${e.message}';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
          setState(() => _isLoading = false);
        },
        codeSent: (String verificationId, int? resendToken) {
          print('Code sent: $verificationId, Resend token: $resendToken');
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
            if (isResend) {
              _pinController.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('OTP resent successfully')),
              );
            }
          });
          _startResendTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Code auto-retrieval timeout: $verificationId');
          setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      print('Unexpected error during OTP request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (_canResendOtp) {
      await _verifyPhoneNumber(isResend: true);
    }
  }

  Future<void> _signInWithCode() async {
    if (_verificationId == null) {
      print('No verification ID available');
      return;
    }

    setState(() => _isLoading = true);

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: _pinController.text,
    );

    try {
      print('Attempting to sign in with OTP: ${_pinController.text}');
      await FirebaseAuth.instance.signInWithCredential(credential);
      final phoneNumber = '+91${_phoneController.text}';
      await _checkUserRegistration(phoneNumber);
    } catch (e) {
      print('Error verifying OTP: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid OTP: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkUserRegistration(String phoneNumber) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user signed in');
      setState(() => _isLoading = false);
      return;
    }

    try {
      print('Checking user registration for UID: ${user.uid}');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isEqualTo: user.uid)
          .get();

      if (userDoc.docs.isNotEmpty) {
        String userName =
            userDoc.docs.first['name'] ?? user.phoneNumber ?? 'User';
        print('User registered, navigating to HomeScreen with name: $userName');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(userName: userName),
            ),
          );
        }
      } else {
        print(
            'User not registered, navigating to RegisterScreen with phone: $phoneNumber');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => RegisterScreen(phoneNumber: phoneNumber)),
          );
        }
      }
    } catch (e) {
      print('Error checking registration: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking registration: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.getPrimary(context).withOpacity(0.9),
              AppTheme.getPrimary(context).withOpacity(0.5),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 40.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // App Logo and Title
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.getSurface(context).withOpacity(0.1),
                      ),
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 80,
                        color: AppTheme.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Yuva Pulse',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.getTextPrimary(context),
                        fontFamily: 'Poppins',
                        shadows: [
                          Shadow(
                            color: AppTheme.getTextSecondary(context)
                                .withOpacity(0.3),
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Connect with the Future 🌟',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.getTextSecondary(context),
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Login Form Card
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: AppTheme.getSurface(context).withOpacity(0.95),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _verificationId == null
                                  ? 'Enter Your Phone'
                                  : 'Verify OTP',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.getPrimary(context),
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _verificationId == null
                                  ? "We'll send you an OTP to verify"
                                  : "Enter the 6-digit code sent to +91${_phoneController.text}",
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.getTextSecondary(context),
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Phone Number Input
                            if (_verificationId == null)
                              TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                decoration: InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixText: '+91 ',
                                  prefixStyle: TextStyle(
                                    color: AppTheme.getPrimary(context),
                                    fontWeight: FontWeight.bold,
                                  ),
                                  labelStyle: TextStyle(
                                    color: AppTheme.getTextSecondary(context),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor:
                                  AppTheme.getSurface(context).withOpacity(0.5),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  color: AppTheme.getTextPrimary(context),
                                ),
                              ),

                            // OTP Input
                            if (_verificationId != null)
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final availableWidth = constraints.maxWidth;
                                  double fieldWidth = (availableWidth - (5 * 10)) / 6;
                                  fieldWidth = fieldWidth.clamp(30.0, 45.0);

                                  return PinCodeTextField(
                                    appContext: context,
                                    length: 6,
                                    controller: _pinController,
                                    animationType: AnimationType.fade,
                                    animationDuration:
                                    const Duration(milliseconds: 200),
                                    keyboardType: TextInputType.number,
                                    obscureText: false,
                                    pinTheme: PinTheme(
                                      shape: PinCodeFieldShape.box,
                                      borderRadius: BorderRadius.circular(10),
                                      fieldHeight: 50,
                                      fieldWidth: fieldWidth,
                                      activeFillColor: AppTheme.getSurface(context),
                                      inactiveFillColor: AppTheme.getSurface(context)
                                          .withOpacity(0.5),
                                      selectedFillColor: AppTheme.getPrimary(context)
                                          .withOpacity(0.1),
                                      activeColor: AppTheme.getPrimary(context),
                                      inactiveColor:
                                      AppTheme.getTextSecondary(context),
                                      selectedColor: AppTheme.getPrimary(context),
                                    ),
                                    onChanged: (value) {},
                                    beforeTextPaste: (text) {
                                      if (text != null) {
                                        return text.contains(RegExp(r'^[0-9]+$'));
                                      }
                                      return true;
                                    },
                                  );
                                },
                              ),

                            if (_verificationId != null) ...[
                              const SizedBox(height: 10),
                              Center(
                                child: TextButton(
                                  onPressed: _canResendOtp ? _resendOtp : null,
                                  child: Text(
                                    _canResendOtp
                                        ? 'Resend OTP'
                                        : 'Resend OTP in $_resendCountdown s',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: _canResendOtp
                                          ? AppTheme.getPrimary(context)
                                          : AppTheme.getTextSecondary(context),
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 30),

                            // Submit Button
                            Center(
                              child: AnimatedOpacity(
                                opacity: _isLoading ? 0.7 : 1.0,
                                duration: const Duration(milliseconds: 300),
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : (_verificationId == null
                                      ? (_isPhoneValid
                                      ? _verifyPhoneNumber
                                      : null)
                                      : _signInWithCode),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.getPrimary(context),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color:
                                      AppTheme.getTextPrimary(context),
                                      strokeWidth: 2,
                                    ),
                                  )
                                      : Text(
                                    _verificationId == null
                                        ? 'Send OTP'
                                        : 'Verify OTP',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color:
                                      AppTheme.getTextPrimary(context),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}