import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'add_company_screen.dart'; // Import the AddCompanyScreen

class WorkExperienceScreen extends StatefulWidget {
  @override
  _WorkExperienceScreenState createState() => _WorkExperienceScreenState();
}

class _WorkExperienceScreenState extends State<WorkExperienceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jobTitleController = TextEditingController();
  final _companyController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _summaryController = TextEditingController();
  bool _isCurrentlyWorking = false;
  bool _isLoading = false;
  bool _isLoadingCompanies = false;
  String? _selectedCompanyLogoUrl;
  List<Map<String, String>> _companies = [];
  String? _selectedCompanyName;

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
  }

  @override
  void dispose() {
    _jobTitleController.dispose();
    _companyController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  // Fetch all companies from Firestore
  Future<void> _fetchCompanies() async {
    setState(() {
      _isLoadingCompanies = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('companies')
          .orderBy('companyName')
          .get();
      setState(() {
        _companies = snapshot.docs.map((doc) {
          return {
            'name': doc['companyName'] as String,
            'logoUrl': doc['logoUrl'] as String,
          };
        }).toList();
      });
    } catch (e) {
      print('Error fetching companies: $e');
    } finally {
      setState(() {
        _isLoadingCompanies = false;
      });
    }
  }

  // Pick a date for start or end date
  Future<void> _pickDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.deepPurple,
              onPrimary: Colors.white,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.black,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  // Save work experience to Firestore
  Future<void> _saveExperience() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No authenticated user found.');

      final companyName = _companyController.text.trim();
      final companyQuery = await FirebaseFirestore.instance
          .collection('companies')
          .where('companyName', isEqualTo: companyName)
          .limit(1)
          .get();

      String companyLogoUrl = _selectedCompanyLogoUrl ?? '';
      if (companyQuery.docs.isEmpty) {
        // Show dialog to add new company
        final shouldAddCompany = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text('Company Not Found', style: TextStyle(color: Colors.white)),
            content: Text(
              'The company "$companyName" does not exist. Would you like to add it?',
              style: const TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add Company', style: TextStyle(color: Colors.deepPurple)),
              ),
            ],
          ),
        );

        if (shouldAddCompany == true) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddCompanyScreen(companyName: companyName),
            ),
          );
          // Refresh companies after returning
          await _fetchCompanies();
        }
        setState(() {
          _isLoading = false;
        });
        return;
      } else {
        companyLogoUrl = companyQuery.docs.first['logoUrl'] as String;
      }

      final experienceData = {
        'jobTitle': _jobTitleController.text.trim(),
        'company': companyName,
        'companyLogoUrl': companyLogoUrl,
        'startDate': _startDateController.text,
        'endDate': _isCurrentlyWorking ? 'Present' : _endDateController.text,
        'summary': _summaryController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'experiences': FieldValue.arrayUnion([experienceData]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Experience added successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error saving experience: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving experience: $e')),
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
        title: const Text(
          'Add Experience',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _isLoading
                ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : ElevatedButton(
              onPressed: _saveExperience,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Basic Info',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _jobTitleController,
                label: 'Job Title',
                validator: (value) => value!.isEmpty ? 'Enter job title' : null,
              ),
              const SizedBox(height: 16),
              _buildCompanyDropdown(),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _startDateController,
                label: 'Started in',
                readOnly: true,
                suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                onTap: () => _pickDate(context, _startDateController),
                validator: (value) => value!.isEmpty ? 'Select start date' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _isCurrentlyWorking,
                    onChanged: (value) {
                      setState(() {
                        _isCurrentlyWorking = value!;
                        if (_isCurrentlyWorking) {
                          _endDateController.clear();
                        }
                      });
                    },
                    activeColor: Colors.deepPurple,
                    checkColor: Colors.white,
                  ),
                  const Text(
                    'Currently Working Here',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              if (!_isCurrentlyWorking) ...[
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _endDateController,
                  label: 'Worked till',
                  readOnly: true,
                  suffixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                  onTap: () => _pickDate(context, _endDateController),
                  validator: (value) =>
                  value!.isEmpty && !_isCurrentlyWorking ? 'Select end date' : null,
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _summaryController,
                label: 'Tell us about your experience',
                maxLines: 5,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Custom TextField with modern design
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    bool readOnly = false,
    Widget? suffixIcon,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      maxLines: maxLines,
      readOnly: readOnly,
      onTap: onTap,
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
        suffixIcon: suffixIcon,
      ),
      validator: validator,
    );
  }

  // Dropdown for company name selection
  Widget _buildCompanyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Company Name',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCompanyName,
          hint: const Text('Select or type company', style: TextStyle(color: Colors.grey)),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
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
          items: _isLoadingCompanies
              ? [const DropdownMenuItem(child: CircularProgressIndicator())]
              : _companies.map<DropdownMenuItem<String>>((Map<String, String> company) {
            return DropdownMenuItem<String>(
              value: company['name'],
              child: Row(
                children: [
                  if (company['logoUrl'] != null && company['logoUrl']!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: company['logoUrl']!,
                      width: 30,
                      height: 30,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) => const Icon(Icons.business, color: Colors.white, size: 30),
                    )
                  else
                    const Icon(Icons.business, color: Colors.white, size: 30),
                  const SizedBox(width: 12),
                  Expanded(child: Text(company['name']!)),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedCompanyName = newValue;
              _companyController.text = newValue ?? '';
              final selectedCompany = _companies.firstWhere(
                    (company) => company['name'] == newValue,
                orElse: () => {'name': '', 'logoUrl': ''},
              );
              _selectedCompanyLogoUrl = selectedCompany['logoUrl'];
            });
          },
          validator: (value) => value == null || value.isEmpty ? 'Select a company' : null,
          dropdownColor: Colors.grey[900],
        ),
      ],
    );
  }
}