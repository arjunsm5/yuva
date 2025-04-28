import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:yuva/utils/app_theme.dart';
import 'package:yuva/utils/theme_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert'; // For base64 encoding
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(),
    ),
  );
}

// Main app widget
class MyApp extends StatelessWidget {
  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: AppTheme.primaryLight,
        scaffoldBackgroundColor: AppTheme.backgroundLight,
        appBarTheme: AppBarTheme(
          backgroundColor: AppTheme.backgroundLight,
          foregroundColor: AppTheme.textPrimaryLight,
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: AppTheme.textPrimaryLight),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryLight,
            foregroundColor: AppTheme.textPrimaryLight,
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: AppTheme.primaryDark,
        scaffoldBackgroundColor: AppTheme.backgroundDark,
        appBarTheme: AppBarTheme(
          backgroundColor: AppTheme.backgroundDark,
          foregroundColor: AppTheme.textPrimaryDark,
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: AppTheme.textPrimaryDark),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryDark,
            foregroundColor: AppTheme.textPrimaryDark,
          ),
        ),
      ),
      themeMode: themeProvider.themeMode,
      home: SellScreen(),
    );
  }
}

// SellScreen widget to display the list of items
class SellScreen extends StatelessWidget {
  final List<_SellItem> items = [
    _SellItem("Roommates & Flatmates", Icons.people_alt_outlined),
    _SellItem("Pg & Hostels", Icons.apartment_outlined),
    _SellItem("Books & Notes", Icons.menu_book_outlined),
    _SellItem("Service Request", Icons.handshake_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: themeProvider.themeMode == ThemeMode.dark
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: themeProvider.themeMode == ThemeMode.dark
            ? AppTheme.backgroundDark
            : AppTheme.backgroundLight,
        elevation: 0,
        title: Text(
          "What are you offering",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: themeProvider.themeMode == ThemeMode.dark
                ? AppTheme.textPrimaryDark
                : AppTheme.textPrimaryLight,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          color: themeProvider.themeMode == ThemeMode.dark
              ? AppTheme.textPrimaryDark
              : AppTheme.textPrimaryLight,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView.builder(
        itemCount: items.length,
        padding: EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SellFormScreen(category: item.title),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                decoration: BoxDecoration(
                  color: themeProvider.themeMode == ThemeMode.dark
                      ? Colors.grey.shade800
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    )
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: themeProvider.themeMode == ThemeMode.dark
                              ? Colors.white12
                              : Colors.black12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.all(12),
                        child: Icon(item.icon,
                            color: themeProvider.themeMode == ThemeMode.dark
                                ? Colors.white
                                : Colors.black,
                            size: 28),
                      ),
                      SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: themeProvider.themeMode == ThemeMode.dark
                                ? AppTheme.textPrimaryDark
                                : AppTheme.textPrimaryLight,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          color: themeProvider.themeMode == ThemeMode.dark
                              ? Colors.white38
                              : Colors.black38,
                          size: 18),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// SellFormScreen widget for entering item details
class SellFormScreen extends StatefulWidget {
  final String category;

  SellFormScreen({Key? key, required this.category}) : super(key: key);

  @override
  _SellFormScreenState createState() => _SellFormScreenState();
}

class _SellFormScreenState extends State<SellFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _depositController = TextEditingController();
  final _locationController = TextEditingController();
  String? _occupancy;
  String? _lookingFor;
  String? _availableFor;
  String? _type;
  List<String> _amenities = [];
  List<XFile> _images = [];
  List<String> _imageBase64Strings = []; // Store base64 strings of images
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _depositController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // Function to compress the image and return the compressed file
  Future<File> _compressImage(XFile image) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = tempDir.path;
    final fileName = image.name;
    final targetPath = '$tempPath/compressed_$fileName';

    // Compress the image to 50% quality, max width/height of 800px to reduce size
    final compressedImage = await FlutterImageCompress.compressAndGetFile(
      image.path,
      targetPath,
      quality: 50, // Lower quality to reduce size for Firestore
      minWidth: 800,
      minHeight: 800,
    );

    if (compressedImage == null) {
      throw Exception('Image compression failed');
    }

    return File(compressedImage.path);
  }

  // Function to convert image to base64 string
  Future<String> _imageToBase64(XFile image) async {
    // Compress the image first
    final compressedImage = await _compressImage(image);

    // Read the compressed image as bytes
    final bytes = await compressedImage.readAsBytes();

    // Convert to base64 string
    return base64Encode(bytes);
  }

  // Function to pick images and convert them to base64
  Future<void> _pickImages() async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage(
      imageQuality: 80,
      limit: 3,
    );
    if (pickedFiles != null) {
      setState(() {
        _images = pickedFiles.take(3).toList();
      });

      // Convert each image to base64
      _imageBase64Strings = [];
      for (var image in _images) {
        final base64String = await _imageToBase64(image);
        _imageBase64Strings.add(base64String);
      }

      // Check if the total size of base64 strings is within Firestore limits (roughly 1MB)
      final totalSize = _imageBase64Strings.fold<int>(0, (sum, str) => sum + str.length);
      if (totalSize > 700000) { // Approximate limit (leaving room for other fields)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Images are too large. Please select smaller images.')),
        );
        setState(() {
          _images = [];
          _imageBase64Strings = [];
        });
      }
    }
  }

  // Function to submit the form and save data to Firestore
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not authenticated. Please sign in.');
        }

        Map<String, dynamic> data = {
          'category': widget.category,
          'title': _titleController.text,
          'description': _descriptionController.text,
          'location': _locationController.text,
          'createdAt': Timestamp.now(),
          'userId': user.uid, // Store the user ID for ownership checks
          'images': _imageBase64Strings, // Store images as base64 strings
        };

        if (widget.category == "Service Request") {
          data['price'] = double.parse(_priceController.text);
        } else if (widget.category == "Books & Notes") {
          data['price'] = double.parse(_priceController.text);
          data['type'] = _type;
        } else if (widget.category == "Roommates & Flatmates") {
          data['rentPerPerson'] = double.parse(_priceController.text);
          data['occupancy'] = _occupancy;
          data['lookingFor'] = _lookingFor;
          data['amenities'] = _amenities;
        } else if (widget.category == "Pg & Hostels") {
          data['expectedRent'] = double.parse(_priceController.text);
          data['expectedDeposit'] = double.parse(_depositController.text);
          data['occupancy'] = _occupancy;
          data['availableFor'] = _availableFor;
          data['amenities'] = _amenities;
        }

        // Add the item to Firestore in the sellitems collection
        await FirebaseFirestore.instance.collection('sellitems').add(data);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item listed successfully!')),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error listing item: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Build a text field with dynamic styling
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
          prefixIcon: icon != null ? Icon(icon, color: Theme.of(context).textTheme.bodyMedium?.color) : null,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        keyboardType: keyboardType,
        validator: validator,
        maxLines: maxLines,
      ),
    );
  }

  // Build a dropdown field with dynamic styling
  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white24),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        dropdownColor: Theme.of(context).scaffoldBackgroundColor,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (value) => value == null ? 'Please select an option' : null,
      ),
    );
  }

  // Build an amenities selection field with chips
  Widget _buildAmenitiesField() {
    final List<String> allAmenities = [
      'Wi-Fi',
      'AC',
      'Parking',
      'Laundry',
      'Gym',
      'Kitchen',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amenities',
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 16),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allAmenities.map((amenity) {
              final isSelected = _amenities.contains(amenity);
              return ChoiceChip(
                label: Text(amenity),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _amenities.add(amenity);
                    } else {
                      _amenities.remove(amenity);
                    }
                  });
                },
                selectedColor: Theme.of(context).primaryColor,
                labelStyle: TextStyle(
                  color: isSelected ? Theme.of(context).scaffoldBackgroundColor : Theme.of(context).textTheme.bodyMedium?.color,
                ),
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white24),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Build an image picker section
  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upload Images (Up to 3)',
          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 16),
        ),
        SizedBox(height: 8),
        Row(
          children: List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  child: index < _images.length
                      ? Icon(Icons.image, color: Theme.of(context).textTheme.bodyMedium?.color)
                      : Icon(Icons.add, color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    List<Widget> formFields = [];

    formFields.add(_buildImagePicker());
    formFields.add(_buildTextField(
      controller: _locationController,
      label: 'Location',
      icon: Icons.location_on,
      validator: (value) => value!.isEmpty ? 'Please enter a location' : null,
    ));

    if (widget.category == "Service Request") {
      formFields.add(_buildTextField(
        controller: _titleController,
        label: 'Gig Title',
        validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
      ));
      formFields.add(_buildTextField(
        controller: _descriptionController,
        label: 'Gig Description',
        maxLines: 4,
        validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
      ));
      formFields.add(_buildTextField(
        controller: _priceController,
        label: 'Amount (in RS)',
        icon: Icons.currency_rupee,
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value!.isEmpty) return 'Please enter a price';
          if (double.tryParse(value) == null) return 'Please enter a valid number';
          return null;
        },
      ));
    } else if (widget.category == "Books & Notes") {
      formFields.add(_buildDropdownField(
        label: 'Type',
        value: _type,
        items: ['Books', 'Notes', 'Other'],
        onChanged: (value) => setState(() => _type = value),
      ));
      formFields.add(_buildTextField(
        controller: _titleController,
        label: 'Title',
        validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
      ));
      formFields.add(_buildTextField(
        controller: _priceController,
        label: 'Price',
        icon: Icons.currency_rupee,
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value!.isEmpty) return 'Please enter a price';
          if (double.tryParse(value) == null) return 'Please enter a valid number';
          return null;
        },
      ));
      formFields.add(_buildTextField(
        controller: _descriptionController,
        label: 'Description',
        maxLines: 4,
        validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
      ));
    } else if (widget.category == "Roommates & Flatmates") {
      formFields.add(_buildTextField(
        controller: _priceController,
        label: 'Rent per person',
        icon: Icons.currency_rupee,
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value!.isEmpty) return 'Please enter a rent amount';
          if (double.tryParse(value) == null) return 'Please enter a valid number';
          return null;
        },
      ));
      formFields.add(_buildDropdownField(
        label: 'Searching',
        value: _lookingFor,
        items: ['Male', 'Female', 'Any'],
        onChanged: (value) => setState(() => _lookingFor = value),
      ));
      formFields.add(_buildDropdownField(
        label: 'Occupancy',
        value: _occupancy,
        items: ['Single', 'Double', 'Triple', 'More'],
        onChanged: (value) => setState(() => _occupancy = value),
      ));
      formFields.add(_buildAmenitiesField());
      formFields.add(_buildTextField(
        controller: _descriptionController,
        label: 'Description',
        maxLines: 4,
        validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
      ));
    } else if (widget.category == "Pg & Hostels") {
      formFields.add(_buildTextField(
        controller: _priceController,
        label: 'Expected Rent',
        icon: Icons.currency_rupee,
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value!.isEmpty) return 'Please enter a rent amount';
          if (double.tryParse(value) == null) return 'Please enter a valid number';
          return null;
        },
      ));
      formFields.add(_buildTextField(
        controller: _depositController,
        label: 'Expected Deposit',
        icon: Icons.currency_rupee,
        keyboardType: TextInputType.number,
        validator: (value) {
          if (value!.isEmpty) return 'Please enter a deposit amount';
          if (double.tryParse(value) == null) return 'Please enter a valid number';
          return null;
        },
      ));
      formFields.add(_buildDropdownField(
        label: 'Occupancy',
        value: _occupancy,
        items: ['Single', 'Double', 'Triple', 'More'],
        onChanged: (value) => setState(() => _occupancy = value),
      ));
      formFields.add(_buildDropdownField(
        label: 'Available for',
        value: _availableFor,
        items: ['Male', 'Female', 'Any'],
        onChanged: (value) => setState(() => _availableFor = value),
      ));
      formFields.add(_buildAmenitiesField());
      formFields.add(_buildTextField(
        controller: _titleController,
        label: 'Title',
        validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
      ));
      formFields.add(_buildTextField(
        controller: _descriptionController,
        label: 'Description',
        maxLines: 4,
        validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
      ));
    }

    return Scaffold(
      backgroundColor: themeProvider.themeMode == ThemeMode.dark
          ? AppTheme.backgroundDark
          : AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: themeProvider.themeMode == ThemeMode.dark
            ? AppTheme.backgroundDark
            : AppTheme.backgroundLight,
        elevation: 0,
        title: Text(
          widget.category == "Service Request"
              ? 'Post Help Request'
              : widget.category == "Roommates & Flatmates"
              ? 'Add Your Room Details'
              : widget.category == "Pg & Hostels"
              ? 'Add PG & Hostel Details'
              : 'Books & Notes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: themeProvider.themeMode == ThemeMode.dark
                ? AppTheme.textPrimaryDark
                : AppTheme.textPrimaryLight,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          color: themeProvider.themeMode == ThemeMode.dark
              ? AppTheme.textPrimaryDark
              : AppTheme.textPrimaryLight,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              ...formFields,
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeProvider.themeMode == ThemeMode.dark
                      ? AppTheme.primaryDark
                      : AppTheme.primaryLight,
                  foregroundColor: themeProvider.themeMode == ThemeMode.dark
                      ? AppTheme.textPrimaryDark
                      : AppTheme.textPrimaryLight,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(
                  color: themeProvider.themeMode == ThemeMode.dark
                      ? AppTheme.textPrimaryDark
                      : AppTheme.textPrimaryLight,
                )
                    : Text(
                  'Submit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Data model for sell items
class _SellItem {
  final String title;
  final IconData icon;

  _SellItem(this.title, this.icon);
}