import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:cached_network_image/cached_network_image.dart';

class AddCompanyScreen extends StatefulWidget {
  final String? companyId; // Optional: Pass companyId for editing an existing company
  final String? companyName; // New: Pass company name to prefill

  const AddCompanyScreen({super.key, this.companyId, this.companyName});

  @override
  _AddCompanyScreenState createState() => _AddCompanyScreenState();
}

class _AddCompanyScreenState extends State<AddCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _webLinkController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _selectedLogo;
  String? _logoUrl;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  Map<String, dynamic>? _existingCompany;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    if (widget.companyName != null) {
      _companyNameController.text = widget.companyName!; // Prefill company name
    }
    _companyNameController.addListener(_onCompanyNameChanged);
    if (widget.companyId != null) {
      _fetchCompany();
    }
  }

  @override
  void dispose() {
    _companyNameController.removeListener(_onCompanyNameChanged);
    _companyNameController.dispose();
    _locationController.dispose();
    _webLinkController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Check if the user is an admin based on phone number
  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.phoneNumber == '+919876543210') {
      setState(() {
        _isAdmin = true;
      });
    }
  }

  // Fetch existing company data if editing
  Future<void> _fetchCompany() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .get();
      if (snapshot.exists) {
        setState(() {
          _existingCompany = snapshot.data();
          _companyNameController.text = _existingCompany!['companyName'] ?? '';
          _locationController.text = _existingCompany!['location'] ?? '';
          _webLinkController.text = _existingCompany!['webLink'] ?? '';
          _descriptionController.text = _existingCompany!['description'] ?? '';
          _logoUrl = _existingCompany!['logoUrl'];
        });
      }
    } catch (e) {
      print('Error fetching company: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching company: $e')),
      );
    }
  }

  // Search for company details as the user types (case-sensitive)
  void _onCompanyNameChanged() async {
    final query = _companyNameController.text.trim();
    if (query.length < 3) {
      setState(() {
        _existingCompany = null;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .where('companyName', isEqualTo: query)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _existingCompany = snapshot.docs.first.data();
          _locationController.text = _existingCompany!['location'] ?? '';
          _webLinkController.text = _existingCompany!['webLink'] ?? '';
          _descriptionController.text = _existingCompany!['description'] ?? '';
          _logoUrl = _existingCompany!['logoUrl'];
        });
      } else {
        setState(() {
          _existingCompany = null;
          _locationController.clear();
          _webLinkController.clear();
          _descriptionController.clear();
          _logoUrl = null;
        });
      }
    } catch (e) {
      print('Error searching company: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching company: $e')),
      );
    }
  }

  // Simulate fetching logo and description from web link
  Future<void> _fetchDetailsFromWebLink(String webLink) async {
    try {
      final response = await http.get(Uri.parse(webLink));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);
        final metaDescription = document.querySelector('meta[name="description"]')?.attributes['content'] ?? '';
        setState(() {
          _descriptionController.text = metaDescription;
          _logoUrl = 'https://b.zmtcdn.com/images/square_zomato_logo_new.svg'; // Placeholder
        });
      }
    } catch (e) {
      print('Error fetching details from web link: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching details: $e')),
      );
    }
  }

  // Pick an image for the company logo
  Future<void> _pickLogo() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedLogo = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking logo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking logo: $e')),
      );
    }
  }

  // Upload the logo to Firebase Storage and get the download URL
  Future<String?> _uploadLogo(String companyName) async {
    if (_selectedLogo == null) return _logoUrl;

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('company_logos')
          .child('$companyName.jpg');
      final uploadTask = storageRef.putFile(_selectedLogo!);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading logo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading logo: $e')),
      );
      return null;
    }
  }

  // Save or update the company in Firestore
  Future<void> _saveCompany() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final companyName = _companyNameController.text.trim();

      // If web link is provided, fetch details (logo and description)
      if (_webLinkController.text.isNotEmpty && !_isAdmin) {
        await _fetchDetailsFromWebLink(_webLinkController.text.trim());
      }

      // Upload new logo if selected (for admins)
      String? logoUrl = _logoUrl ?? '';
      if (_selectedLogo != null && _isAdmin) {
        logoUrl = await _uploadLogo(companyName);
        if (logoUrl == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      final companyData = {
        'companyName': companyName,
        'location': _locationController.text.trim(),
        'webLink': _webLinkController.text.trim(),
        'description': _descriptionController.text.trim(),
        'logoUrl': logoUrl,
      };

      if (widget.companyId != null) {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(widget.companyId)
            .set(companyData, SetOptions(merge: true));
      } else {
        final docRef = await FirebaseFirestore.instance.collection('companies').add(companyData);
        print('New company added with ID: ${docRef.id}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company saved successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error saving company: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving company: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.companyId != null ? 'Edit Company' : 'Add Company',
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Company Name Section
              const Text(
                'Company Name',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _companyNameController,
                label: 'Type to search or add company',
                validator: (value) => value!.isEmpty ? 'Enter company name' : null,
              ),
              if (_existingCompany != null) ...[
                const SizedBox(height: 16),
                // Display Existing Company Details
                const Text(
                  'Company Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDetailField(
                  label: 'Location',
                  controller: _locationController,
                  enabled: _isAdmin,
                ),
                const SizedBox(height: 8),
                _buildDetailField(
                  label: 'Web Link',
                  controller: _webLinkController,
                  enabled: _isAdmin,
                ),
                if (_isAdmin) ...[
                  const SizedBox(height: 8),
                  _buildDetailField(
                    label: 'Description',
                    controller: _descriptionController,
                    maxLines: 5,
                    enabled: _isAdmin,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Company Logo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickLogo,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: _selectedLogo != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedLogo!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 150,
                        ),
                      )
                          : _logoUrl != null && _logoUrl!.isNotEmpty
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: _logoUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 150,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                          errorWidget: (context, url, error) => const Center(child: Icon(Icons.error, color: Colors.red)),
                        ),
                      )
                          : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload, color: Colors.grey, size: 40),
                            SizedBox(height: 8),
                            Text(
                              'Upload Logo',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              Center(
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.deepPurple)
                    : ElevatedButton(
                  onPressed: _saveCompany,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Custom TextField for input
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple),
        ),
      ),
      validator: validator,
    );
  }

  // Custom Detail Field for display/edit
  Widget _buildDetailField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    bool enabled = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: maxLines,
          enabled: enabled,
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? Colors.grey[900] : Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: enabled ? Colors.grey[700]! : Colors.grey[600]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: enabled ? const BorderSide(color: Colors.deepPurple) : BorderSide.none,
            ),
          ),
          validator: enabled ? (value) => value!.isEmpty ? 'Enter $label' : null : null,
        ),
      ],
    );
  }
}