import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:yuva/utils/app_theme.dart';
import 'package:provider/provider.dart';
import '../ui/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String? phoneNumber;

  const RegisterScreen({super.key, required this.phoneNumber});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final PageController _pageController = PageController();
  final GlobalKey _pageViewKey = GlobalKey();
  int _currentPage = 0;
  bool _isLoading = false;
  bool _isLayoutReady = true;

  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _locationController = TextEditingController();
  final _collegeNameController = TextEditingController();
  final _otherInterestController = TextEditingController();

  File? _collegeIdImage;
  DateTime? _selectedDate;

  String? _gender;
  final List<String> _genders = ['Male', 'Female', 'Other'];

  final List<String> _trendingInterests = [
    'Book Nerd', 'Music Enthusiast', 'Video Games', 'Traveling',
    'Technology', 'Swimming', 'Shopping', 'Art',
    'Photography', 'Design', 'Cooking', 'Gaming',
    'Fitness', 'Reading'
  ];
  final List<String> _selectedInterests = [];
  List<String> _filteredInterests = [];

  static const animationDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _filteredInterests = _trendingInterests;
    _otherInterestController.addListener(_filterInterests);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _isLayoutReady = true);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _locationController.dispose();
    _collegeNameController.dispose();
    _otherInterestController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _filterInterests() {
    final query = _otherInterestController.text.toLowerCase();
    setState(() {
      _filteredInterests = _trendingInterests
          .where((interest) => interest.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _fetchLocation() async {
    setState(() => _isLoading = true);
    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        if (androidInfo.isPhysicalDevice != true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location services may not be available on emulators. Please enter manually.')),
          );
          return;
        }
      }
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(const Duration(seconds: 5));
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location services are disabled. Please enter manually.')),
        );
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission().timeout(const Duration(seconds: 5));
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(const Duration(seconds: 5));
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location permission denied. Please enter manually.')),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location permission permanently denied. Please enable it in settings or enter manually.'),
            action: SnackBarAction(
              label: 'Open Settings',
              onPressed: () => openAppSettings(),
              textColor: AppTheme.getPrimary(context),
            ),
          ),
        );
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
          SnackBar(content: Text('Unable to fetch location. Please enter manually.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching location: $e. Please enter manually.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDarkMode = AppTheme.isDark(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDarkMode
                ? ColorScheme.dark(
              primary: AppTheme.getPrimary(context),
              onPrimary: AppTheme.getTextPrimary(context),
              surface: AppTheme.getSurface(context),
              onSurface: AppTheme.getTextPrimary(context),
              background: AppTheme.getBackground(context),
              onBackground: AppTheme.getTextPrimary(context),
            )
                : ColorScheme.light(
              primary: AppTheme.getPrimary(context),
              onPrimary: AppTheme.getTextPrimary(context),
              surface: AppTheme.getSurface(context),
              onSurface: AppTheme.getTextPrimary(context),
              background: AppTheme.getBackground(context),
              onBackground: AppTheme.getTextPrimary(context),
            ),
            dialogBackgroundColor: AppTheme.getSurface(context),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.getPrimary(context),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: AppTheme.getSurface(context),
              headerBackgroundColor: AppTheme.getPrimary(context),
              headerForegroundColor: AppTheme.getTextPrimary(context),
              dayForegroundColor: WidgetStateProperty.all(AppTheme.getTextPrimary(context)),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.getPrimary(context);
                }
                return null;
              }),
              todayForegroundColor: WidgetStateProperty.all(AppTheme.getAccent(context)),
              todayBorder: BorderSide(color: AppTheme.getAccent(context)),
              yearForegroundColor: WidgetStateProperty.all(AppTheme.getTextPrimary(context)),
              surfaceTintColor: Colors.transparent,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

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
          content: Text('Photo access is permanently denied. Please enable it in settings.'),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: () => openAppSettings(),
            textColor: AppTheme.getPrimary(context),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo access denied')));
    }
    setState(() => _isLoading = false);
  }

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

  Future<bool> _validateStep1() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter your full name')));
      return false;
    }
    if (_dobController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select your date of birth')));
      return false;
    }
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter your location')));
      return false;
    }
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select your gender')));
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_collegeNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter your college name')));
      return false;
    }
    if (_collegeIdImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please upload your college ID')));
      return false;
    }
    return true;
  }

  bool _validateStep3() {
    if (_selectedInterests.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select at least 3 interests')));
      return false;
    }
    return true;
  }

  Future<void> _submitRegistration() async {
    setState(() => _isLoading = true);
    try {
      String imageUrl = '';
      if (_collegeIdImage != null) {
        File? compressedImage = await _compressImage(_collegeIdImage!);
        if (compressedImage == null) throw Exception('Failed to compress image');
        final storageRef = FirebaseStorage.instance.ref('college_ids/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(compressedImage);
        await Future.delayed(const Duration(seconds: 1));
        imageUrl = await storageRef.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').add({
        'name': _nameController.text.trim(),
        'dob': _dobController.text.trim(),
        'location': _locationController.text.trim(),
        'gender': _gender,
        'phone': widget.phoneNumber,
        'collegeName': _collegeNameController.text.trim(),
        'collegeIdUrl': imageUrl,
        'interests': _selectedInterests,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Registration successful'),
        backgroundColor: AppTheme.getSuccess(context),
      ));
      _navigateToHome();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Registration failed: $e'),
        backgroundColor: AppTheme.getError(context),
      ));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(userName: _nameController.text.trim())),
    );
  }

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
            color: _currentPage == index
                ? AppTheme.getPrimary(context)
                : AppTheme.getTextSecondary(context).withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }

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
      child: SizedBox(
        height: 56,
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixText: prefixText,
            suffixIcon: suffixIcon != null ? Icon(suffixIcon, color: AppTheme.getPrimary(context)) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.getTextSecondary(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.getTextSecondary(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.getPrimary(context),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: AppTheme.getSurface(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          keyboardType: keyboardType,
          maxLength: maxLength,
          readOnly: readOnly,
          onTap: onTap,
          textCapitalization: label == 'Full Name' ? TextCapitalization.words : TextCapitalization.none,
          style: TextStyle(color: AppTheme.getTextPrimary(context)),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 56,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Gender',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.getTextSecondary(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.getTextSecondary(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.getPrimary(context),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: AppTheme.getSurface(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _gender,
              isExpanded: true,
              hint: Text(
                'Select your gender',
                style: TextStyle(color: AppTheme.getTextSecondary(context)),
              ),
              style: TextStyle(color: AppTheme.getTextPrimary(context)),
              items: _genders.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(color: AppTheme.getTextPrimary(context)),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _gender = newValue;
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: TextStyle(
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimary(context),
            ),
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
          _buildGenderDropdown(),
        ],
      ),
    );
  }

  Widget _buildStep2(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'College Details',
            style: TextStyle(
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          _buildModernTextField(controller: _collegeNameController, label: 'College Name'),
          const SizedBox(height: 16),
          _buildAnimatedButton(label: 'Upload College ID', onPressed: _pickImage, width: screenWidth * 0.5),
          const SizedBox(height: 8),
          if (_collegeIdImage != null) ...[
            Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.getSuccess(context)),
                SizedBox(width: 16),
                Text('College ID selected', style: TextStyle(color: AppTheme.getSuccess(context), fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            Image.file(
              _collegeIdImage!,
              height: 100,
              width: 100,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Text('Error loading image', style: TextStyle(color: AppTheme.getError(context))),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _collegeIdImage = null),
              child: Text('Clear Image', style: TextStyle(color: AppTheme.getError(context))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep3(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxInterestsPerRow = (screenWidth ~/ 120).clamp(1, 4);
    final visibleInterests = _trendingInterests.take(maxInterestsPerRow * 4).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Interests',
            style: TextStyle(
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
              color: AppTheme.getTextPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Select at least 3 interests',
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              color: AppTheme.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...visibleInterests.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedInterests.remove(interest);
                      } else {
                        _selectedInterests.add(interest);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: animationDuration,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.getPrimary(context)
                          : AppTheme.getSurface(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.getPrimary(context)
                            : AppTheme.getTextSecondary(context).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          interest,
                          style: TextStyle(
                            color: isSelected
                                ? AppTheme.getTextPrimary(context)
                                : AppTheme.getTextPrimary(context),
                            fontSize: screenWidth * 0.04,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedInterests.remove(interest);
                              });
                            },
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: AppTheme.getTextPrimary(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppTheme.getSurface(context),
                      title: Text(
                        'Add Other Interest',
                        style: TextStyle(color: AppTheme.getTextPrimary(context)),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildModernTextField(
                            controller: _otherInterestController,
                            label: 'Enter Interest',
                            keyboardType: TextInputType.text,
                          ),
                          const SizedBox(height: 10),
                          if (_otherInterestController.text.isNotEmpty && _filteredInterests.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _filteredInterests.map((interest) {
                                return ListTile(
                                  title: Text(
                                    interest,
                                    style: TextStyle(color: AppTheme.getTextPrimary(context)),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      if (!_selectedInterests.contains(interest)) {
                                        _selectedInterests.add(interest);
                                      }
                                    });
                                    _otherInterestController.clear();
                                    Navigator.pop(context);
                                  },
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            if (_otherInterestController.text.trim().isNotEmpty) {
                              setState(() {
                                final newInterest = _otherInterestController.text.trim();
                                if (!_selectedInterests.contains(newInterest)) {
                                  _selectedInterests.add(newInterest);
                                }
                              });
                              _otherInterestController.clear();
                            }
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Add',
                            style: TextStyle(color: AppTheme.getPrimary(context)),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: AppTheme.getPrimary(context)),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: AnimatedContainer(
                  duration: animationDuration,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.getSurface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.getTextSecondary(context).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    'Other',
                    style: TextStyle(
                      color: AppTheme.getTextPrimary(context),
                      fontSize: screenWidth * 0.04,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedButton({
    required String label,
    required VoidCallback onPressed,
    bool isLoading = false,
    double? width,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: width ?? 100, minHeight: 48),
      child: GestureDetector(
        onTap: (_isLoading || !_isLayoutReady) ? null : onPressed,
        child: AnimatedContainer(
          duration: animationDuration,
          padding: const EdgeInsets.symmetric(vertical: 16),
          width: width,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.getPrimary(context), AppTheme.getPrimary(context).withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.getPrimary(context).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.getTextPrimary(context)))
                : Text(
              label,
              style: TextStyle(
                color: AppTheme.getTextPrimary(context),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final steps = [_buildStep1(context), _buildStep2(context), _buildStep3(context)];
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context),
      appBar: AppBar(
        title: Text('Create Account'),
        centerTitle: true,
        backgroundColor: AppTheme.getSurface(context),
        elevation: 0,
        titleTextStyle: TextStyle(
          color: AppTheme.getTextPrimary(context),
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
                          color: AppTheme.getSurface(context),
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
                                    WidgetsBinding.instance.addPostFrameCallback((_) =>
                                        setState(() => _isLayoutReady = true));
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
                                  color: AppTheme.getTextSecondary(context),
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
                                final isValid = await _validateStep1();
                                if (isValid) {
                                  _pageController.nextPage(
                                      duration: animationDuration,
                                      curve: Curves.easeInOut);
                                }
                              } else if (_currentPage == 1) {
                                if (_validateStep2()) {
                                  _pageController.nextPage(
                                      duration: animationDuration,
                                      curve: Curves.easeInOut);
                                }
                              } else if (_currentPage == 2) {
                                if (_validateStep3()) {
                                  _submitRegistration();
                                }
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
            return Center(child: Text('Error: $e', style: TextStyle(color: AppTheme.getError(context))));
          }
        },
      ),
    );
  }
}