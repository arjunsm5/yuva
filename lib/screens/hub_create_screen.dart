import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for user authentication
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class HubCreateScreen extends StatefulWidget {
  const HubCreateScreen({Key? key}) : super(key: key);

  @override
  _HubCreateScreenState createState() => _HubCreateScreenState();
}

class _HubCreateScreenState extends State<HubCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _backgroundImage;
  File? _hubImage;
  bool _isLoading = false;

  Future<File?> _compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = tempDir.path;
    final image = img.decodeImage(await file.readAsBytes());

    if (image == null) return null;

    // Resize and compress
    final compressedImage = img.copyResize(image, width: 800);
    final compressedFile = File('$tempPath/compressed_${file.path.split('/').last}');
    await compressedFile.writeAsBytes(img.encodeJpg(compressedImage, quality: 80));//compression quality

    return compressedFile;
  }

  Future<String?> _uploadImage(File image, String folder) async {
    try {
      final compressedImage = await _compressImage(image);
      if (compressedImage == null) return null;

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('$folder/${const Uuid().v4()}.jpg');
      final uploadTask = await storageRef.putFile(compressedImage);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }

  Future<void> _pickImage(ImageSource source, bool isBackground) async {
    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(source: source);
    if (pickedImage != null) {
      setState(() {
        if (isBackground) {
          _backgroundImage = File(pickedImage.path);
        } else {
          _hubImage = File(pickedImage.path);
        }
      });
    }
  }

  Future<void> _createHub() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        String? backgroundUrl;
        String? hubImageUrl;
        final user = FirebaseAuth.instance.currentUser; // Get current user

        if (user == null) {
          throw Exception('User not authenticated');
        }

        // Upload images if selected
        if (_backgroundImage != null) {
          backgroundUrl = await _uploadImage(_backgroundImage!, 'backgrounds');
        }
        if (_hubImage != null) {
          hubImageUrl = await _uploadImage(_hubImage!, 'hub_images');
        }

        // Save to Firestore with creatorId
        await FirebaseFirestore.instance.collection('hubs').add({
          'name': _nameController.text,
          'description': _descriptionController.text,
          'backgroundImage': backgroundUrl,
          'hubImage': hubImageUrl,
          'creatorId': user.uid, // Save creator's user ID
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hub created successfully!')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating hub: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Hub'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.purple.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 100),
              // Hub Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Hub Name',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter hub name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Background Image
              const Text(
                'Background Image',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _pickImage(ImageSource.gallery, true),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    image: _backgroundImage != null
                        ? DecorationImage(
                      image: FileImage(_backgroundImage!),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: _backgroundImage == null
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.image, size: 40, color: Colors.grey),
                        Text('Select Background Image'),
                      ],
                    ),
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Hub Image
              const Text(
                'Hub Image',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _pickImage(ImageSource.gallery, false),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    image: _hubImage != null
                        ? DecorationImage(
                      image: FileImage(_hubImage!),
                      fit: BoxFit.cover,
                    )
                        : null,
                  ),
                  child: _hubImage == null
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.image, size: 40, color: Colors.grey),
                        Text('Select Hub Image'),
                      ],
                    ),
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 24),

              // Create Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createHub,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Create Hub',
                    style: TextStyle(fontSize: 16),
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