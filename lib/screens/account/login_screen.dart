import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore
import 'package:yuva/screens/ui/home_screen.dart';
import 'package:yuva/screens/account/register_screen.dart'; // Import RegisterScreen
import 'dart:async';
import 'package:pin_code_fields/pin_code_fields.dart';

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

  @override
  void initState() {
    super.initState();
    // Add listener to validate phone number dynamically
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
    super.dispose();
  }

  Future<void> _verifyPhoneNumber() async {
    final phoneNumber = '+91${_phoneController.text}';

    // Validate phone number format
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
      print('Attempting to send OTP to $phoneNumber');

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('Verification completed: $credential');
          await FirebaseAuth.instance.signInWithCredential(credential);
          await _checkUserRegistration();
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
          setState(() => _isLoading = false);
        },
        codeSent: (String verificationId, int? resendToken) {
          print('Code sent: $verificationId, Resend token: $resendToken');
          setState(() {
            _verificationId = verificationId;
            _isLoading = false;
          });
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
      await _checkUserRegistration();
    } catch (e) {
      print('Error verifying OTP: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invalid OTP: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkUserRegistration() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user signed in');
      setState(() => _isLoading = false);
      return;
    }

    // Check if the user is registered in Firestore using UID
    try {
      print('Checking user registration for UID: ${user.uid}');
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .where('uid', isEqualTo: user.uid)
              .get();

      if (userDoc.docs.isNotEmpty) {
        // User is registered, navigate to HomeScreen
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
        // User is not registered, navigate to RegisterScreen
        print('User not registered, navigating to RegisterScreen');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const RegisterScreen()),
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
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withOpacity(0.9),
              theme.colorScheme.primary.withOpacity(0.5),
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
                  // Corrected alignment
                  children: [
                    // 🔹 App Logo and Title
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Yuva Pulse',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
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
                        color: Colors.white70,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 40),

                    // 🔹 Login Form Card
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      color: Colors.white.withOpacity(0.95),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          // Corrected alignment
                          children: [
                            Text(
                              _verificationId == null
                                  ? 'Enter Your Phone'
                                  : 'Verify OTP',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _verificationId == null
                                  ? 'We’ll send you an OTP to verify'
                                  : 'Enter the 6-digit code sent to +91${_phoneController.text}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
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
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  labelStyle: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                ),
                              ),

                            // OTP Input
                            if (_verificationId != null)
                              PinCodeTextField(
                                appContext: context,
                                length: 6,
                                controller: _pinController,
                                animationType: AnimationType.fade,
                                animationDuration: const Duration(
                                  milliseconds: 200,
                                ),
                                obscureText: false,
                                pinTheme: PinTheme(
                                  shape: PinCodeFieldShape.box,
                                  borderRadius: BorderRadius.circular(10),
                                  fieldHeight: 50,
                                  fieldWidth: 45,
                                  activeFillColor: Colors.white,
                                  inactiveFillColor: Colors.grey[200],
                                  selectedFillColor: theme.colorScheme.primary
                                      .withOpacity(0.1),
                                  activeColor: theme.colorScheme.primary,
                                  inactiveColor: Colors.grey[400],
                                  selectedColor: theme.colorScheme.primary,
                                ),
                                onChanged: (value) {},
                              ),

                            const SizedBox(height: 30),

                            // Submit Button
                            Center(
                              child: AnimatedOpacity(
                                opacity: _isLoading ? 0.7 : 1.0,
                                duration: const Duration(milliseconds: 300),
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading || !_isPhoneValid
                                          ? null
                                          : (_verificationId == null
                                              ? _verifyPhoneNumber
                                              : _signInWithCode),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 40,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 5,
                                  ),
                                  child:
                                      _isLoading
                                          ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : Text(
                                            _verificationId == null
                                                ? 'Send OTP'
                                                : 'Verify OTP',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.white,
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
