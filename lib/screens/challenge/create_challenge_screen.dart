import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_auth/firebase_auth.dart';

// This screen allows users to create new challenges with details like name, image, and dates.
class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> with SingleTickerProviderStateMixin {
  // Form key to validate user input in the form fields.
  final _formKey = GlobalKey<FormState>();

  // Text controllers for each input field to manage user input.
  final _challengeNameController = TextEditingController();
  final _postTypeController = TextEditingController();
  final _rewardController = TextEditingController();
  final _participantsController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _linkController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _winDescriptionController = TextEditingController();

  // Variables to store selected skill category, sub-skill, and the picked image file.
  String? _skillCategory;
  String? _subSkill;
  File? _imageFile;

  // Instances for Firebase Firestore, Storage, ImagePicker, and Auth.
  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State variables for UI feedback.
  bool _isSaving = false;
  bool _isAuthenticated = false;

  // Animation controller and fade animation for a smooth UI transition effect.
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Map of skill categories and their corresponding sub-skills (complete list).
  final Map<String, List<String>> _subSkillsMap = {
    "Art & Design": [
      "Visual design", "Creative thinking", "Color theory", "Typography", "Layout design",
      "Digital illustration", "UI/UX design", "Graphic design", "Animation", "Photography",
      "Drawing", "Sketching", "Art direction", "Brand design", "Print design", "Web design",
      "Motion graphics", "Video editing", "Image editing", "Design systems", "Design thinking",
      "Packaging design", "Composition", "Aesthetics", "Product design"
    ],
    "Business": [
      "Business management", "Scheduling", "Economics", "Markets", "Sales", "Strategic thinking",
      "Project management", "Business analysis", "Entrepreneurship", "Human resources",
      "Adaptability", "Leadership", "Time management", "Multitasking", "Networking",
      "Collaboration", "Negotiation", "Problem solving", "Risk taking", "KPIs",
      "Product management", "Financial literacy", "Customer focus", "Commitment",
      "E-commerce", "Organization"
    ],
    "Communication": [
      "Written communication", "Verbal communication", "Public speaking", "Active listening",
      "Presentation skills", "Technical writing", "Storytelling", "Content writing",
      "Copywriting", "Email communication", "Social media", "Report writing", "Documentation",
      "Cross-cultural communication", "Team communication", "Conflict resolution",
      "Interpersonal skills", "Body language", "Persuasion", "Feedback delivery",
      "Meeting facilitation", "Networking", "Crisis communication", "Diplomatic communication",
      "Media relations", "Professional etiquette"
    ],
    "Computer Science": [
      "Programming", "Software development", "Web development", "Mobile development",
      "Database management", "Cloud computing", "Cybersecurity", "Network administration",
      "System architecture", "DevOps", "Machine learning", "Artificial intelligence",
      "Data science", "Algorithms", "Data structures", "Version control", "Testing",
      "Debugging", "API development", "Full-stack development", "Frontend development",
      "Backend development", "Operating systems", "Computer networks", "IT support",
      "Systems analysis"
    ],
    "Education": [
      "Teaching", "Curriculum development", "Lesson planning", "Assessment design",
      "Educational technology", "Classroom management", "Special education", "Student counseling",
      "Educational psychology", "Learning theories", "Instructional design", "E-learning",
      "Adult education", "Early childhood education", "STEM education", "Language teaching",
      "Educational leadership", "Student engagement", "Differentiated instruction",
      "Educational assessment", "Distance learning", "Pedagogical methods", "Educational research",
      "Professional development", "Mentoring", "Educational administration"
    ],
    "Engineering": [
      "Mechanical engineering", "Electrical engineering", "Civil engineering",
      "Software engineering", "Chemical engineering", "Industrial engineering",
      "Systems engineering", "Automation", "CAD/CAM", "Process engineering",
      "Quality engineering", "Manufacturing", "Robotics", "Control systems",
      "Product development", "Technical design", "Structural analysis", "Circuit design",
      "Thermal systems", "Materials engineering", "Environmental engineering",
      "Project engineering", "Safety engineering", "Maintenance engineering",
      "Reliability engineering", "Engineering management"
    ],
    "Environment": [
      "Environmental science", "Sustainability", "Conservation", "Climate science",
      "Renewable energy", "Waste management", "Environmental impact",
      "Natural resource management", "Pollution control", "Environmental policy",
      "Ecological restoration", "Green technology", "Environmental monitoring",
      "Biodiversity management", "Environmental education", "Sustainable development",
      "Environmental compliance", "Environmental planning", "Water management",
      "Environmental health", "Ecosystem management", "Carbon management",
      "Environmental consulting", "Wildlife conservation", "Marine conservation",
      "Environmental advocacy"
    ],
    "Fashion": [
      "Fashion design", "Pattern making", "Garment construction", "Textile design",
      "Fashion illustration", "Trend forecasting", "Fashion merchandising", "Costume design",
      "Fashion styling", "Fashion marketing", "Fashion photography", "Fashion journalism",
      "Sustainable fashion", "Fashion buying", "Collection development", "Fashion history",
      "Color coordination", "Fashion retail", "Fashion technology", "Fashion production",
      "Fashion management", "Accessories design", "Fashion branding", "Quality control",
      "Fashion consulting", "Fashion entrepreneurship"
    ],
    "Finance": [
      "Financial analysis", "Investment management", "Risk management", "Banking",
      "Accounting", "Financial planning", "Trading", "Portfolio management",
      "Financial modeling", "Corporate finance", "Financial reporting", "Budgeting",
      "Tax planning", "Insurance", "Real estate finance", "Credit analysis",
      "Financial compliance", "Asset management", "Wealth management", "Financial strategy",
      "Treasury management", "Financial controls", "Auditing", "Cost management",
      "Financial forecasting", "Financial technology"
    ],
    "Food": [
      "Culinary arts", "Food safety", "Menu planning", "Food science", "Recipe development",
      "Kitchen management", "Food presentation", "Nutrition", "Baking", "Food cost control",
      "Restaurant management", "Food service", "Wine knowledge", "Beverage management",
      "Food photography", "Food styling", "Food writing", "Sustainable cooking",
      "Special diets", "Quality control", "Inventory management", "Food procurement",
      "Food preservation", "Food innovation", "Food marketing", "Health regulations"
    ],
    "Healthcare": [
      "Patient care", "Medical procedures", "Clinical practice", "Healthcare management",
      "Public health", "Mental health", "Nursing", "Pharmacy", "Medical records",
      "Healthcare technology", "Diagnostic skills", "Treatment planning", "Rehabilitation",
      "Emergency care", "Preventive care", "Health education", "Medical research",
      "Healthcare policy", "Medical ethics", "Patient advocacy", "Healthcare compliance",
      "Medical coding", "Healthcare administration", "Telemedicine", "Health informatics",
      "Patient safety"
    ],
    "Marketing": [
      "Digital marketing", "Content marketing", "Social media marketing", "SEO",
      "Brand management", "Market research", "Marketing strategy", "Email marketing",
      "Marketing analytics", "Campaign management", "Marketing automation", "Lead generation",
      "Product marketing", "Marketing communications", "Advertising", "Public relations",
      "Marketing planning", "Customer acquisition", "Growth marketing", "Influencer marketing",
      "Conversion optimization", "Marketing operations", "Marketing technology",
      "Performance marketing", "Event marketing", "Channel marketing"
    ],
    "Media & Entertainment": [
      "Film production", "Video production", "Audio production", "Broadcasting",
      "Content creation", "Media planning", "Entertainment management", "Game development",
      "Animation", "Music production", "Scriptwriting", "Media distribution",
      "Live events", "Digital media", "Media strategy", "Talent management",
      "Post-production", "Sound design", "Media technology", "Media analytics",
      "Media rights", "Media operations", "Interactive media", "Streaming media",
      "Virtual reality", "Augmented reality"
    ],
    "Law": [
      "Legal research", "Legal writing", "Contract law", "Corporate law", "Criminal law",
      "Civil law", "Intellectual property", "International law", "Employment law",
      "Environmental law", "Tax law", "Constitutional law", "Family law", "Real estate law",
      "Litigation", "Legal compliance", "Legal ethics", "Negotiation", "Mediation",
      "Legal technology", "Legal advocacy", "Legal consulting", "Legal documentation",
      "Legal analysis", "Regulatory affairs", "Legal administration"
    ],
    "Science": [
      "Research methodology", "Data analysis", "Laboratory skills", "Scientific writing",
      "Experimental design", "Statistical analysis", "Scientific computing",
      "Microscopy", "Spectroscopy", "Chromatography", "Molecular biology",
      "Biochemistry", "Physics", "Chemistry", "Biology", "Environmental science",
      "Materials science", "Neuroscience", "Genetics", "Microbiology", "Biotechnology",
      "Scientific instrumentation", "Quality control", "Scientific documentation",
      "Laboratory management", "Research ethics"
    ],
    "Services": [
      "Customer service", "Service design", "Quality assurance", "Service management",
      "Technical support", "Client relations", "Service operations", "Consulting",
      "Professional services", "Service marketing", "Service development",
      "Service delivery", "Support management", "Service strategy", "Process improvement",
      "Service innovation", "Service analytics", "Customer experience", "Service automation",
      "Service integration", "Service compliance", "Service documentation",
      "Service planning", "Service coordination", "Service optimization", "Service training"
    ],
    "Sports": [
      "Athletic training", "Sports coaching", "Sports management", "Physical fitness",
      "Sports medicine", "Sports psychology", "Performance analysis", "Sports nutrition",
      "Strength conditioning", "Injury prevention", "Sports technology", "Team management",
      "Sports marketing", "Event management", "Competition planning", "Sports education",
      "Sports development", "Sports science", "Athletic assessment", "Sports rehabilitation",
      "Sports facilities", "Sports administration", "Sports safety", "Sports programming",
      "Sports leadership", "Sports operations"
    ],
    "Politics & Society": [
      "Political analysis", "Public policy", "International relations", "Social research",
      "Policy analysis", "Governance", "Diplomatic relations", "Social advocacy",
      "Political communication", "Community development", "Social policy", "Public affairs",
      "Political strategy", "Civil society", "Social innovation", "Policy development",
      "Political consulting", "Social impact", "Government relations", "Political research",
      "Social planning", "Political organizing", "Policy implementation", "Social analysis",
      "Political management", "Social development"
    ],
    "Wellbeing": [
      "Mental health", "Physical health", "Emotional intelligence", "Stress management",
      "Work-life balance", "Meditation", "Wellness coaching", "Personal development",
      "Health education", "Mindfulness", "Nutrition", "Exercise science", "Life coaching",
      "Counseling", "Alternative health", "Wellness planning", "Health promotion",
      "Behavioral health", "Holistic health", "Wellness technology", "Mental fitness",
      "Wellness assessment", "Health coaching", "Lifestyle management", "Preventive health",
      "Wellness programming"
    ],
  };

  // List of all skill categories for the dropdown.
  final List<String> _skillCategories = [
    "Art & Design", "Business", "Communication", "Computer Science", "Education",
    "Engineering", "Environment", "Fashion", "Finance", "Food", "Healthcare",
    "Marketing", "Media & Entertainment", "Law", "Science", "Services",
    "Sports", "Politics & Society", "Wellbeing"
  ];

  // List to store all sub-skills for fallback when no category is selected.
  final List<String> _allSubSkills = [];

  @override
  void initState() {
    super.initState();
    // Populate the list of all sub-skills from the sub-skills map.
    _initializeAllSubSkills();
    // Initialize the animation controller for a fade-in effect.
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // Set up the fade animation from 0 (invisible) to 1 (fully visible).
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_animationController)
      ..addListener(() => setState(() {}));
    // Start the animation when the screen loads.
    _animationController.forward();
    // Listen to authentication state changes.
    _auth.authStateChanges().listen((User? user) {
      setState(() {
        _isAuthenticated = user != null;
        print('Auth state changed: User ID = ${user?.uid}');
      });
      if (user == null) {
        _signInAnonymously();
      }
    });
  }

  // Method to sign in the user anonymously with retry logic.
  Future<void> _signInAnonymously() async {
    int retryCount = 0;
    const maxRetries = 3;
    while (retryCount < maxRetries && _auth.currentUser == null) {
      try {
        await _auth.signInAnonymously();
        print('User signed in anonymously: ${_auth.currentUser?.uid}');
        return;
      } catch (e) {
        retryCount++;
        print('Error signing in anonymously (attempt $retryCount/$maxRetries): $e');
        if (retryCount == maxRetries) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to authenticate after $maxRetries attempts: $e')),
          );
        }
        await Future.delayed(const Duration(seconds: 1)); // Delay between retries
      }
    }
  }

  // Method to populate the _allSubSkills list with all sub-skills from the map.
  void _initializeAllSubSkills() {
    _allSubSkills.clear();
    for (var category in _skillCategories) {
      if (_subSkillsMap.containsKey(category)) {
        _allSubSkills.addAll(_subSkillsMap[category]!);
      }
    }
  }

  // Method to pick an image from the gallery and compress it before setting it.
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      // Convert the XFile to a File using its path.
      final originalFile = File(pickedFile.path);
      final compressedFile = await _compressImage(originalFile);
      setState(() {
        _imageFile = compressedFile;
      });
    }
  }

  // Method to compress the picked image using flutter_image_compress package.
  Future<File> _compressImage(File file) async {
    try {
      // Define the path for the compressed image (ensure it's unique).
      final String targetPath = '${file.path}_compressed.jpg';
      // Compress the image with specified quality and dimensions.
      final compressedFilePath = await FlutterImageCompress.compressAndGetFile(
        file.path, // Pass the String path of the original file
        targetPath,
        quality: 70, // Reduced quality for faster upload
        minHeight: 600, // Smaller dimensions to reduce file size
        minWidth: 600,
      );
      // Check if compression succeeded and return the compressed file.
      if (compressedFilePath != null) {
        final compressedFile = File(compressedFilePath.path);
        print('Image compressed: Original size = ${await file.length() / 1024}KB, Compressed size = ${await compressedFile.length() / 1024}KB');
        return compressedFile;
      }
      print('Compression failed, returning original file: Size = ${await file.length() / 1024}KB');
      return file;
    } catch (e) {
      print('Error compressing image: $e');
      return file;
    }
  }

  // Method to show a date picker and set the selected date in the given controller.
  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00FFCC),
              onPrimary: Color(0xFF1A1A1A),
              surface: Color(0xFF2A2A2A),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF2A2A2A),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.text = DateFormat('dd-MM-yyyy').format(picked);
    }
  }

  // Method to save the challenge data to Firestore after uploading the compressed image.
  Future<void> _saveChallenge() async {
    // Ensure the user is authenticated before proceeding.
    print('Current User: ${_auth.currentUser?.uid}');
    if (_auth.currentUser == null) {
      print('No authenticated user found, attempting to sign in anonymously...');
      await _signInAnonymously();
      if (_auth.currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed. Please try again.')),
        );
        return;
      }
    }

    // Validate the form and ensure an image is selected.
    if (_formKey.currentState!.validate() && _imageFile != null) {
      setState(() => _isSaving = true);
      try {
        // Create a new document reference in the 'challenges' collection.
        final ref = _firestore.collection('challenges').doc();
        // Define the storage path for the image.
        final storageRef = _storage.ref().child('challenge_images/${ref.id}.jpg');
        print('Uploading to path: ${storageRef.fullPath}');

        // Upload the compressed image to Firebase Storage with progress logging.
        final uploadTask = storageRef.putFile(_imageFile!);
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = (snapshot.bytesTransferred / snapshot.totalBytes * 100).toStringAsFixed(2);
          print('Upload progress: $progress% (${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes)');
        });

        // Wait for the upload to complete and get the download URL.
        final snapshot = await uploadTask;
        final imageUrl = await snapshot.ref.getDownloadURL();
        print('Image uploaded successfully. Download URL: $imageUrl');

        // Save the challenge data to Firestore.
        await ref.set({
          'challengeId': ref.id,
          'challengeName': _challengeNameController.text.trim(),
          'skillCategory': _skillCategory ?? '',
          'skill': _subSkill ?? '',
          'postType': _postTypeController.text.trim(),
          'reward': _rewardController.text.trim(),
          'participants': _participantsController.text.trim(),
          'startDate': _startDateController.text.trim(),
          'endDate': _endDateController.text.trim(),
          'link': _linkController.text.trim(),
          'description': _descriptionController.text.trim(),
          'winDescription': _winDescriptionController.text.trim(),
          'imageUrl': imageUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': _auth.currentUser!.uid,
        });

        // Show success message and clear the form.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge saved successfully')),
        );
        _clearFields();
      } catch (e) {
        // Log the error and show a user-friendly message.
        print('Error saving challenge: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save challenge: $e')),
        );
      } finally {
        // Hide loading indicator.
        setState(() => _isSaving = false);
      }
    } else {
      // Show error if form validation fails or no image is selected.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select an image')),
      );
    }
  }

  // Method to clear all form fields and reset state after saving.
  void _clearFields() {
    _challengeNameController.clear();
    _postTypeController.clear();
    _rewardController.clear();
    _participantsController.clear();
    _startDateController.clear();
    _endDateController.clear();
    _linkController.clear();
    _descriptionController.clear();
    _winDescriptionController.clear();
    _skillCategory = null;
    _subSkill = null;
    _imageFile = null;
    setState(() {});
  }

  // Dispose of controllers and animation to free up resources when the widget is removed.
  @override
  void dispose() {
    _challengeNameController.dispose();
    _postTypeController.dispose();
    _rewardController.dispose();
    _participantsController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _linkController.dispose();
    _descriptionController.dispose();
    _winDescriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Build the UI for the challenge creation screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A), // Dark background for the screen.
      body: Stack(
        children: [
          Column(
            children: [
              // App bar with a back button and title.
              Container(
                color: const Color(0xFF2A2A2A),
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context), // Go back to the previous screen.
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Create Challenges',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable form area for input fields.
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Opacity(
                      opacity: _fadeAnimation.value, // Apply fade-in animation to the form.
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Image picker section with a preview.
                          GestureDetector(
                            onTap: _pickImage,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 200,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: _imageFile == null
                                  ? const Center(
                                child: Icon(Icons.add_a_photo, color: Colors.grey, size: 50),
                              )
                                  : ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.file(_imageFile!, fit: BoxFit.cover),
                              ),
                            ),
                          ),
                          const SizedBox(height: 25),
                          // Challenge name input field.
                          TextFormField(
                            controller: _challengeNameController,
                            style: GoogleFonts.poppins(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Challenge Name',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFF00FFCC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF2A2A2A),
                            ),
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 20),
                          // Skill category dropdown.
                          DropdownButtonFormField<String>(
                            value: _skillCategory,
                            hint: Text('Skill Category', style: GoogleFonts.poppins(color: Colors.grey)),
                            items: _skillCategories.map((category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category, style: GoogleFonts.poppins(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _skillCategory = value;
                                _subSkill = null; // Reset sub-skill when category changes.
                              });
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFF00FFCC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF2A2A2A),
                            ),
                            dropdownColor: const Color(0xFF2A2A2A),
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          // Sub-skill dropdown, filtered based on selected category.
                          DropdownButtonFormField<String>(
                            value: _subSkill,
                            hint: Text('Sub-Skill', style: GoogleFonts.poppins(color: Colors.grey)),
                            items: (_skillCategory != null && _subSkillsMap.containsKey(_skillCategory))
                                ? _subSkillsMap[_skillCategory]!.map((subSkill) {
                              return DropdownMenuItem(
                                value: subSkill,
                                child: Text(subSkill, style: GoogleFonts.poppins(color: Colors.white)),
                              );
                            }).toList()
                                : _allSubSkills.map((subSkill) {
                              return DropdownMenuItem(
                                value: subSkill,
                                child: Text(subSkill, style: GoogleFonts.poppins(color: Colors.white)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _subSkill = value;
                              });
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFF00FFCC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF2A2A2A),
                            ),
                            dropdownColor: const Color(0xFF2A2A2A),
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          // Post type input field.
                          TextFormField(
                            controller: _postTypeController,
                            style: GoogleFonts.poppins(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Post Type',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFF00FFCC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF2A2A2A),
                            ),
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 20),
                          // Reward input field (numeric).
                          TextFormField(
                            controller: _rewardController,
                            style: GoogleFonts.poppins(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Challenge Reward',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFF00FFCC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF2A2A2A),
                            ),
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 20),
                          // Participants input field.
                          TextFormField(
                            controller: _participantsController,
                            style: GoogleFonts.poppins(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Who can win?',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFF00FFCC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF2A2A2A),
                            ),
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 20),
                          // Start date input field with date picker.
                          TextFormField(
                            controller: _startDateController,
                            style: GoogleFonts.poppins(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Start Date',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFF00FFCC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF2A2A2A),
                            ),
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            onTap: () => _selectDate(_startDateController),
                            readOnly: true,
                          ),
                          const SizedBox(height: 20),
                          // End date input field with date picker.
                          TextFormField(
                            controller: _endDateController,
                            style: GoogleFonts.poppins(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'End Date',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFF00FFCC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF2A2A2A),
                            ),
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                            onTap: () => _selectDate(_endDateController),
                            readOnly: true,
                          ),
                          const SizedBox(height: 20),
                          // Challenge link input field (optional).
                          TextFormField(
                            controller: _linkController,
                            style: GoogleFonts.poppins(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Challenge Link',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFF00FFCC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF2A2A2A),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Challenge description input field (multi-line).
                          TextFormField(
                            controller: _descriptionController,
                            style: GoogleFonts.poppins(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Challenge Description',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFF00FFCC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF2A2A2A),
                            ),
                            maxLines: 5,
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 20),
                          // Winner description input field (multi-line).
                          TextFormField(
                            controller: _winDescriptionController,
                            style: GoogleFonts.poppins(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Challenge Winner Description',
                              labelStyle: GoogleFonts.poppins(color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Color(0xFF00FFCC)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: const BorderSide(color: Colors.grey),
                              ),
                              filled: true,
                              fillColor: const Color(0xFF2A2A2A),
                            ),
                            maxLines: 5,
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Submit button to save the challenge.
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving || !_isAuthenticated ? null : _saveChallenge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFCC),
                      foregroundColor: const Color(0xFF1A1A1A),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 8,
                      shadowColor: Colors.black.withOpacity(0.4),
                    ),
                    child: Text(
                      _isAuthenticated ? 'Submit' : 'Authenticating...',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Show a loading overlay when saving is in progress.
          if (_isSaving)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF00FFCC)),
              ),
            ),
        ],
      ),
    );
  }
}