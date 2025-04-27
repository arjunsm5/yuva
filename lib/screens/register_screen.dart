import 'dart:io'; // Import for file handling (e.g., college ID image)
import 'dart:async'; // Import for timeout handling
import 'package:flutter/material.dart'; // Core Flutter UI library
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore for user data storage
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Authentication for OTP
import 'package:firebase_storage/firebase_storage.dart'; // Firebase Storage for image upload
import 'package:image_picker/image_picker.dart'; // Library for picking images
import 'package:intl/intl.dart'; // Date formatting
import 'package:permission_handler/permission_handler.dart'; // Permission handling
import 'package:device_info_plus/device_info_plus.dart'; // Device info for platform checks
import 'package:geolocator/geolocator.dart'; // Geolocation services
import 'package:geocoding/geocoding.dart'; // Geocoding for location names
import 'package:yuva/screens/home_screen.dart'; // Navigation to HomeScreen (adjust 'yuva' to your app name)
import 'package:flutter_image_compress/flutter_image_compress.dart'; // Import for image compression
import 'package:yuva/utils/app_theme.dart'; // Import AppTheme for colors
import 'package:provider/provider.dart'; // Import Provider for theme access
import 'package:yuva/utils/theme_provider.dart'; // Import ThemeProvider for theme state

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PageController _pageController = PageController(); // Controls page navigation
  final GlobalKey _pageViewKey = GlobalKey(); // Key for the PageView widget
  int _currentPage = 0; // Tracks the current step (0, 1, or 2)
  bool _isLoading = false; // Loading state for buttons
  bool _isLayoutReady = false; // Ensures layout is ready after initialization

  // Text controllers for form fields
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _collegeNameController = TextEditingController();
  final _otpController = TextEditingController();
  File? _collegeIdImage; // Stores the selected college ID image

  DateTime? _selectedDate; // Stores the selected date of birth
  String? _verificationId; // Stores the verification ID from Firebase for OTP
  int? _resendToken; // Token for resending OTP without reCAPTCHA

  // Lazy access to FirebaseAuth instance
  FirebaseAuth get _auth => FirebaseAuth.instance;

  // Animation duration constant
  static const animationDuration = Duration(milliseconds: 300); // Define animation duration

  @override
  void initState() {
    super.initState();
    // Ensure layout is ready after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _isLayoutReady = true);
    });
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _nameController.dispose();
    _dobController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _collegeNameController.dispose();
    _otpController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Fetch the user's current location with timeout
  Future<void> _fetchLocation() async {
    setState(() => _isLoading = true);
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        if (androidInfo.isPhysicalDevice != true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services may not be available on emulators. Please enter manually.')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(const Duration(seconds: 5));
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled. Please enter manually.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission().timeout(const Duration(seconds: 5));
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(const Duration(seconds: 5));
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied. Please enter manually.')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission permanently denied. Please enable it in settings or enter manually.'),
            action: SnackBarAction(label: 'Open Settings', onPressed: () => openAppSettings()),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('Location fetch timed out'));

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 5));

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        String city = placemark.locality ?? placemark.subAdministrativeArea ?? 'Unknown';
        setState(() => _locationController.text = city);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to fetch location. Please enter manually.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching location: $e. Please enter manually.')),
      );
      print('Location fetch error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Open date picker for DOB
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Theme.of(context).primaryColor ?? Colors.blue, // Fallback to blue if null
            onPrimary: Colors.white,
            onSurface: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87, // Fallback to black87
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor ?? Colors.blue, // Fallback to blue
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // Pick an image from gallery
  Future<void> _pickImage() async {
    setState(() => _isLoading = true);
    Permission permission = Platform.isAndroid && (await DeviceInfoPlugin().androidInfo).version.sdkInt >= 33 ? Permission.photos : Permission.storage;
    var status = await permission.status;
    if (!status.isGranted) status = await permission.request();

    if (status.isGranted) {
      try {
        final pickedImage = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (pickedImage != null) setState(() => _collegeIdImage = File(pickedImage.path));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    } else if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Photo access is permanently denied. Please enable it in settings.'),
          action: SnackBarAction(label: 'Open Settings', onPressed: () => openAppSettings()),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo access denied')));
    }
    setState(() => _isLoading = false);
  }

  // Compress the image before upload
  Future<File?> _compressImage(File imageFile) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        tempFile.path,
        quality: 70,
        minWidth: 800,
        minHeight: 600,
      );

      if (compressedImage == null) throw Exception('Image compression failed');
      print('Original size: ${(await imageFile.length()) / 1024} KB');
      print('Compressed size: ${(await compressedImage.length()) / 1024} KB');
      return File(compressedImage.path);
    } catch (e) {
      print('Error compressing image: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error compressing image: $e')));
      return null;
    }
  }

  // Validate Step 1 (Personal Information) with phone number check
  Future<bool> _validateStep1() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your full name')));
      return false;
    }
    if (_dobController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your date of birth')));
      return false;
    }
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your location')));
      return false;
    }
    if (_phoneController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid 10-digit phone number')));
      return false;
    }

    final phoneNumber = "+91${_phoneController.text.trim()}";
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('users').where('phone', isEqualTo: phoneNumber).get();
      if (querySnapshot.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This phone number is already registered')));
        return false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error checking phone number: $e')));
      return false;
    }
    return true;
  }

  // Validate Step 2 (College Details)
  bool _validateStep2() {
    if (_collegeNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your college name')));
      return false;
    }
    if (_collegeIdImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload your college ID')));
      return false;
    }
    return true;
  }

  // Validate Step 3 (OTP)
  bool _validateStep3() {
    if (_otpController.text.trim().isEmpty || _otpController.text.trim().length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid 6-digit OTP')));
      return false;
    }
    return true;
  }

  // Send OTP to the user's phone number with resend support
  Future<void> _sendOTP({int? resendToken}) async {
    setState(() => _isLoading = true);
    try {
      final phoneNumber = "+91${_phoneController.text.trim()}";
      print('Sending OTP to: $phoneNumber with resendToken: $resendToken');
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('Verification completed automatically: ${credential.smsCode}');
          await _auth.signInWithCredential(credential);
          _navigateToHome();
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.message}, Code: ${e.code}');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send OTP: ${e.message}')));
        },
        codeSent: (String verificationId, int? resendToken) {
          print('OTP sent, verificationId: $verificationId, resendToken: $resendToken');
          setState(() {
            _verificationId = verificationId;
            this._resendToken = resendToken;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Auto retrieval timeout, verificationId: $verificationId');
          setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      print('Error sending OTP: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending OTP: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Verify OTP and complete registration with image compression
  Future<void> _verifyOTPAndSubmit() async {
    if (!_validateStep3()) return;

    setState(() => _isLoading = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await _auth.signInWithCredential(credential);
      print('User authenticated: ${_auth.currentUser?.uid}');

      await Future.delayed(const Duration(milliseconds: 500));

      String imageUrl = '';
      if (_collegeIdImage != null) {
        if (!_collegeIdImage!.existsSync()) throw Exception('College ID image file does not exist');

        File? compressedImage = await _compressImage(_collegeIdImage!);
        if (compressedImage == null) throw Exception('Failed to compress image, cannot proceed with upload');

        final storageRef = FirebaseStorage.instance.ref('college_ids/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(compressedImage);
        await Future.delayed(const Duration(seconds: 1));
        imageUrl = await storageRef.getDownloadURL();
      }

      if (_auth.currentUser != null) {
        await FirebaseFirestore.instance.collection('users').add({
          'name': _nameController.text.trim(),
          'dob': _dobController.text.trim(),
          'location': _locationController.text.trim(),
          'phone': "+91${_phoneController.text.trim()}",
          'collegeName': _collegeNameController.text.trim(),
          'collegeIdUrl': imageUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'uid': _auth.currentUser!.uid,
        });
        print('User data saved to Firestore');
      } else {
        throw Exception('No authenticated user found');
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful')));
      _navigateToHome();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to verify OTP or register: $e')));
      print('Error details: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Navigate to HomeScreen
  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(userName: _nameController.text.trim())),
    );
  }

  // Build step indicators (dots) for multi-step form
  Widget _buildStepIndicator(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final indicatorWidth = screenWidth * 0.15;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedContainer(
          duration: animationDuration,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          height: 12,
          width: _currentPage == index ? indicatorWidth : 12,
          decoration: BoxDecoration(
            color: _currentPage == index ? (Theme.of(context).primaryColor ?? Colors.blue) : Colors.grey[300], // Fallback to blue if primaryColor is null
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }

  // Build a modern text field with custom styling
  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    IconData? suffixIcon,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    int? maxLength,
    bool readOnly = false,
    String? prefixText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixText: prefixText,
          suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: Theme.of(context).primaryColor ?? Colors.blue) : null, // Fallback to blue
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor ?? Colors.blue, width: 2), // Fallback to blue
          ),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        keyboardType: keyboardType,
        maxLength: maxLength,
        readOnly: readOnly,
        onTap: onTap,
        textCapitalization: label == 'Full Name' ? TextCapitalization.words : TextCapitalization.none,
      ),
    );
  }

  // Build an animated button with loading state
  Widget _buildAnimatedButton({
    required String label,
    required VoidCallback onPressed,
    bool isLoading = false,
    double? width,
  }) {
    final primaryColor = Theme.of(context).primaryColor ?? Colors.blue; // Fallback to blue if primaryColor is null
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: width ?? 100, minHeight: 48),
      child: GestureDetector(
        onTap: (_isLoading || !_isLayoutReady) ? null : onPressed,
        child: AnimatedContainer(
          duration: animationDuration,
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, primaryColor.withOpacity(0.8)], // Use primaryColor with fallback
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3), // Use primaryColor with fallback
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                : Text(
              label,
              style: TextStyle(
                color: Theme.of(context).elevatedButtonTheme.style?.foregroundColor?.resolve({}) ?? Colors.white, // Fallback to white
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build UI for Step 1 (Personal Information)
  Widget _buildStep1(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: TextStyle(fontSize: screenWidth * 0.05, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87),
          ),
          const SizedBox(height: 16),
          _buildModernTextField(controller: _nameController, label: 'Full Name'),
          _buildModernTextField(
            controller: _dobController,
            label: 'Date of Birth',
            suffixIcon: Icons.calendar_today,
            readOnly: true,
            onTap: _selectDate,
          ),
          _buildModernTextField(controller: _locationController, label: 'Location', onTap: _fetchLocation),
          _buildModernTextField(
            controller: _phoneController,
            label: 'Phone Number',
            keyboardType: TextInputType.phone,
            maxLength: 10,
            prefixText: '+91 ',
          ),
        ],
      ),
    );
  }

  // Build UI for Step 2 (College Details)
  Widget _buildStep2(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'College Details',
            style: TextStyle(fontSize: screenWidth * 0.05, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87),
          ),
          const SizedBox(height: 16),
          _buildModernTextField(controller: _collegeNameController, label: 'College Name'),
          const SizedBox(height: 16),
          _buildAnimatedButton(label: 'Upload College ID', onPressed: _pickImage, width: screenWidth * 0.5),
          const SizedBox(height: 8),
          if (_collegeIdImage != null) ...[
            Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('College ID selected', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            Image.file(_collegeIdImage!, height: 100, width: 100, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Text('Error loading image')),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _collegeIdImage = null),
              child: const Text('Clear Image', style: TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }

  // Build UI for Step 3 (OTP Verification)
  Widget _buildStep3(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verify OTP',
            style: TextStyle(fontSize: screenWidth * 0.05, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the OTP sent to +91 ${_phoneController.text.trim()}',
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          _buildModernTextField(
            controller: _otpController,
            label: 'OTP',
            keyboardType: TextInputType.number,
            maxLength: 6,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading || _resendToken == null ? null : () => _sendOTP(resendToken: _resendToken),
            child: Text(
              'Resend OTP',
              style: TextStyle(color: _isLoading || _resendToken == null ? Colors.grey : (Theme.of(context).primaryColor ?? Colors.blue)),
            ),
          ),
          const SizedBox(height: 16),
          _buildAnimatedButton(label: 'Complete Registration', onPressed: _verifyOTPAndSubmit, isLoading: _isLoading),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final steps = [_buildStep1(context), _buildStep2(context), _buildStep3(context)];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: Theme.of(context).appBarTheme.foregroundColor ?? Colors.black87, // Fallback to black87
          fontSize: screenWidth * 0.05,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Builder(
        builder: (context) {
          try {
            return LayoutBuilder(
              builder: (context, constraints) {
                final padding = screenWidth * 0.05;
                return Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    children: [
                      _buildStepIndicator(context),
                      SizedBox(height: screenHeight * 0.02),
                      Expanded(
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: Theme.of(context).cardColor,
                          child: Padding(
                            padding: EdgeInsets.all(padding),
                            child: AnimatedSwitcher(
                              duration: animationDuration,
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(animation),
                                  child: child,
                                ),
                              ),
                              child: PageView(
                                key: _pageViewKey,
                                controller: _pageController,
                                physics: const NeverScrollableScrollPhysics(),
                                onPageChanged: (index) {
                                  setState(() {
                                    _isLayoutReady = false;
                                    _currentPage = index;
                                    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() => _isLayoutReady = true));
                                  });
                                },
                                children: steps,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_currentPage > 0)
                            TextButton(
                              onPressed: _isLayoutReady
                                  ? () => _pageController.previousPage(duration: animationDuration, curve: Curves.easeInOut)
                                  : null,
                              child: Text(
                                'Back',
                                style: TextStyle(
                                  color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87).withOpacity(0.5),
                                  fontSize: screenWidth * 0.04,
                                ),
                              ),
                            )
                          else
                            const SizedBox(),
                          _buildAnimatedButton(
                            label: _currentPage == 2 ? 'Submit' : 'Next',
                            onPressed: () async {
                              if (_currentPage == 0) {
                                if (await _validateStep1()) {
                                  setState(() => _isLoading = true);
                                  await _sendOTP();
                                  setState(() => _isLoading = false);
                                  if (_verificationId != null) {
                                    _pageController.nextPage(duration: animationDuration, curve: Curves.easeInOut);
                                  }
                                }
                              } else if (_currentPage == 1 && _validateStep2()) {
                                _pageController.nextPage(duration: animationDuration, curve: Curves.easeInOut);
                              }
                            },
                            isLoading: _isLoading,
                            width: screenWidth * 0.4,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          } catch (e) {
            return Center(child: Text('Error: $e', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87)));
          }
        },
      ),
    );
  }
}