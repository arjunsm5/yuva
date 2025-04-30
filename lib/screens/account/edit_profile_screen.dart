import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:yuva/screens/profile/skills_screen.dart';
import 'package:yuva/screens/profile/work_experience_screen.dart';

import '../profile/education_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onProfileUpdated;

  const EditProfileScreen({
    super.key,
    required this.userData,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _isLoading = false;

  // Text controllers
  late TextEditingController _nameController;
  late TextEditingController _uniqueNameController;
  late TextEditingController _taglineController;
  late TextEditingController _locationController;
  late TextEditingController _linkedinController;
  late TextEditingController _emailController;
  late TextEditingController _twitterController;
  late TextEditingController _instagramController;
  late TextEditingController _aboutMeController;

  // Profile image handling
  File? _selectedImage;
  String? _profileImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    print('EditProfileScreen: initState called');
    print('EditProfileScreen: Initial userData: ${widget.userData}');

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
        print('EditProfileScreen: Tab switched to index $_currentTabIndex');
      });
    });

    // Initialize controllers with user data
    _nameController = TextEditingController(text: widget.userData['name'] ?? 'New User');
    _uniqueNameController = TextEditingController(text: widget.userData['uniqueName'] ?? 'DinnerLight25');
    _taglineController = TextEditingController(text: widget.userData['tagline'] ?? 'Hey, I\'m on Yuva – Let\'s Grow Together!');
    _locationController = TextEditingController(text: widget.userData['location'] ?? 'Dharwad, India');
    _linkedinController = TextEditingController(text: widget.userData['linkedin'] ?? 'LinkedIn');
    _emailController = TextEditingController(text: widget.userData['email'] ?? 'yuva@gmail.com');
    _twitterController = TextEditingController(text: widget.userData['twitter'] ?? 'Twitter(X)');
    _instagramController = TextEditingController(text: widget.userData['instagram'] ?? 'Instagram');
    _aboutMeController = TextEditingController(text: widget.userData['aboutMe'] ?? '');
    _profileImageUrl = widget.userData['profileImageUrl'] as String?;
    print('EditProfileScreen: profileImageUrl initialized: $_profileImageUrl');
  }

  @override
  void dispose() {
    print('EditProfileScreen: dispose called');
    _tabController.dispose();
    _nameController.dispose();
    _uniqueNameController.dispose();
    _taglineController.dispose();
    _locationController.dispose();
    _linkedinController.dispose();
    _emailController.dispose();
    _twitterController.dispose();
    _instagramController.dispose();
    _aboutMeController.dispose();
    super.dispose();
  }

  // Function to pick an image from gallery
  Future<void> _pickImage() async {
    try {
      print('EditProfileScreen: Picking image from gallery...');
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        print('EditProfileScreen: Image picked: ${pickedFile.path}');
      } else {
        print('EditProfileScreen: No image selected.');
      }
    } catch (e) {
      print('EditProfileScreen: Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // Function to compress and upload image to Firebase Storage
  Future<String?> _uploadCompressedImage(File image, String userId) async {
    try {
      print('EditProfileScreen: Compressing and uploading image for userId: $userId');
      // Read the image file
      final originalImage = img.decodeImage(await image.readAsBytes());
      if (originalImage == null) {
        print('EditProfileScreen: Failed to decode image.');
        return null;
      }

      // Resize to a maximum of 800x800 pixels
      final resizedImage = img.copyResize(originalImage, width: 800, height: 800);
      final compressedImage = img.encodeJpg(resizedImage, quality: 85);
      print('EditProfileScreen: Image compressed successfully.');

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child(userId); // Simplified path to match new rule
      print('EditProfileScreen: Uploading image to path: profile_images/$userId');
      final uploadTask = storageRef.putData(compressedImage);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('EditProfileScreen: Image uploaded successfully. Download URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('EditProfileScreen: Error uploading image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
      return null;
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });
    print('EditProfileScreen: Saving profile...');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('EditProfileScreen: No authenticated user found.');
        throw Exception('No authenticated user found.');
      }

      // Refresh the user's authentication token to ensure it's valid
      print('EditProfileScreen: Refreshing user authentication token...');
      await user.getIdToken(true); // Forces token refresh
      print('EditProfileScreen: Authentication token refreshed. UID: ${user.uid}');

      // Upload new image if selected and compress it
      if (_selectedImage != null) {
        print('EditProfileScreen: Uploading new profile image for UID: ${user.uid}...');
        _profileImageUrl = await _uploadCompressedImage(_selectedImage!, user.uid);
        print('EditProfileScreen: New profileImageUrl: $_profileImageUrl');
      }

      // Create updated user data
      final updatedData = {
        'name': _nameController.text,
        'uniqueName': _uniqueNameController.text,
        'tagline': _taglineController.text,
        'location': _locationController.text,
        'linkedin': _linkedinController.text,
        'email': _emailController.text,
        'twitter': _twitterController.text,
        'instagram': _instagramController.text,
        'aboutMe': _aboutMeController.text,
        'profileImageUrl': _profileImageUrl ?? widget.userData['profileImageUrl'] ?? '',
        'collegeIdUrl': widget.userData['collegeIdUrl'] ?? '', // Keep collegeIdUrl unchanged
        'updatedAt': FieldValue.serverTimestamp(),
      };
      print('EditProfileScreen: Updated user data: $updatedData');

      // Update Firestore
      print('EditProfileScreen: Updating Firestore document for UID: ${user.uid}');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updatedData);
      print('EditProfileScreen: Firestore document updated successfully.');

      // Notify parent to refresh data
      print('EditProfileScreen: Calling onProfileUpdated callback...');
      widget.onProfileUpdated();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );

      // Navigate back
      print('EditProfileScreen: Navigating back to ProfileScreen...');
      Navigator.pop(context);
    } catch (e) {
      print('EditProfileScreen: Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
      print('EditProfileScreen: Save operation completed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('EditProfileScreen: Building UI...');
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Edit Profile', style: TextStyle(color: Colors.white)),
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.check_circle, color: Colors.green, size: 28),
              onPressed: _isLoading ? null : _saveProfile,
            ),
          ],
        ),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Text(
                'About Me',
                style: TextStyle(
                  color: _currentTabIndex == 0 ? Colors.purple[300] : Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
            Tab(
              child: Text(
                'Experience',
                style: TextStyle(
                  color: _currentTabIndex == 1 ? Colors.purple[300] : Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
          ],
          indicatorColor: Colors.purple[300],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // About Me Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture Section
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.blue[600],
                        backgroundImage: _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty && Uri.parse(_profileImageUrl!).isAbsolute
                            ? NetworkImage(_profileImageUrl!)
                            : const AssetImage('assets/default_profile.png') as ImageProvider),
                        child: (_selectedImage == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty || !Uri.parse(_profileImageUrl!).isAbsolute))
                            ? Text(
                          _getInitials(_nameController.text),
                          style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                        )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: const Icon(Icons.edit, size: 18, color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Name Field
                _buildLabeledTextField("Name", controller: _nameController),
                const SizedBox(height: 10),

                // Unique Name Field
                _buildLabeledTextField("Unique Name", controller: _uniqueNameController),
                const Text(
                  'Unique name is for posting anonymously',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Tagline Field
                _buildLabeledTextField("Tagline", controller: _taglineController),
                const SizedBox(height: 10),

                // Location Field
                _buildLabeledTextField(
                  "Location",
                  controller: _locationController,
                  suffixIcon: const Icon(Icons.my_location, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // Social Links Section
                const Text('Social links',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 16),

                // LinkedIn Field
                _buildSocialField(FontAwesomeIcons.linkedin, _linkedinController, Colors.blue),
                const SizedBox(height: 10),

                // Email Field
                _buildSocialField(FontAwesomeIcons.google, _emailController, Colors.red),
                const SizedBox(height: 10),

                // Twitter Field
                _buildSocialField(FontAwesomeIcons.xTwitter, _twitterController, Colors.grey),
                const SizedBox(height: 10),

                // Instagram Field
                _buildSocialField(FontAwesomeIcons.instagram, _instagramController, Colors.purple),
                const SizedBox(height: 20),

                // About Me Text Section
                const Text('About Me',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: TextField(
                    controller: _aboutMeController,
                    decoration: const InputDecoration(
                      hintText: 'Tell us about yourself',
                      hintStyle: TextStyle(color: Colors.grey),
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(color: Colors.white),
                    maxLines: 5,
                  ),
                ),
              ],
            ),
          ),

          // Experience Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Work Experience Section
                _buildExperienceSection("Work experience"),
                Divider(color: Colors.grey[800]),

                // Education Section
                _buildExperienceSection("Education"),
                Divider(color: Colors.grey[800]),

                // Skills Section
                _buildExperienceSection("Skills"),
                Divider(color: Colors.grey[800]),
                const SizedBox(height: 16),

                // Added Skills List
                _buildSkillItem("Education", () {}),
                const SizedBox(height: 8),
                _buildSkillItem("Community development", () {}),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty || name.trim().isEmpty) {
      return '??'; // Default initials if name is empty
    }
    final nameParts = name.trim().split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (name.length > 1) {
      return name.substring(0, 2).toUpperCase();
    } else {
      return name.toUpperCase();
    }
  }

  Widget _buildLabeledTextField(String label, {required TextEditingController controller, Widget? suffixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
              suffixIcon: suffixIcon,
            ),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSocialField(IconData icon, TextEditingController controller, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FaIcon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceSection(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        GestureDetector(
          onTap: () {
            if (title == "Work experience") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WorkExperienceScreen()),
              );
            } else if (title == "Education") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EducationScreen()),
              );
            } else if (title == "Skills") {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SkillsScreen()),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.purple[300],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
  Widget _buildSkillItem(String title, VoidCallback onDelete) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: title.contains("Education") ? Colors.blue : Colors.amber,
              child: title.contains("Education")
                  ? const Icon(Icons.school, color: Colors.white)
                  : const Icon(Icons.people, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red[300],
            shape: BoxShape.circle,
          ),
          child: InkWell(
            onTap: onDelete,
            child: const Icon(Icons.delete, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }
}