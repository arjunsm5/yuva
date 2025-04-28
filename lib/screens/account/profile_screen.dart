import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  // Add the onProfileUpdated callback
  final VoidCallback? onProfileUpdated;

  const ProfileScreen({
    super.key,
    this.onProfileUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      print('ProfileScreen: Fetching user data...');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('ProfileScreen: No authenticated user found. Redirecting to login...');
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to view your profile')),
        );
        return;
      }

      print('ProfileScreen: Authenticated user UID: ${user.uid}');

      // First try to get user document by document ID (which should be the user's UID)
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (docSnapshot.exists) {
        print('ProfileScreen: User data retrieved by document ID: ${docSnapshot.data()}');
        setState(() {
          userData = docSnapshot.data() as Map<String, dynamic>;
          isLoading = false;
        });
      } else {
        // Fallback: try to find by uid field
        print('ProfileScreen: No document found with ID ${user.uid}. Querying by uid field...');
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          final doc = querySnapshot.docs.first;
          print('ProfileScreen: User data retrieved by query: ${doc.data()}');
          setState(() {
            userData = doc.data() as Map<String, dynamic>;
            isLoading = false;
          });
        } else {
          print('ProfileScreen: No document found where uid matches: ${user.uid}. Creating a default user document...');
          final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
          final defaultUserData = {
            'name': user.displayName ?? 'New User',
            'uniqueName': 'User_${user.uid.substring(0, 8)}',
            'tagline': 'Hey, I\'m on Yuva – Let\'s Grow Together!',
            'location': 'Not specified',
            'phone': 'Not specified',
            'collegeName': 'Not specified',
            'dob': 'Not specified',
            'createdAt': FieldValue.serverTimestamp(),
            'aboutMe': '',
            'email': user.email ?? 'Not specified',
            'linkedin': '',
            'twitter': '',
            'instagram': '',
            'uid': user.uid,
            'collegeIdUrl': '',
            'profileImageUrl': '', // Initialize profileImageUrl
          };

          await docRef.set(defaultUserData);
          print('ProfileScreen: Default user document created with ID: ${user.uid}, data: $defaultUserData');

          final newDoc = await docRef.get();
          setState(() {
            userData = newDoc.data() as Map<String, dynamic>;
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Welcome! Your profile has been created.')),
          );
        }
      }
    } catch (e) {
      print('ProfileScreen: Error fetching or creating user data: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching or creating profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      print('ProfileScreen: Showing loading indicator...');
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (userData == null) {
      print('ProfileScreen: No user data available to display.');
      return const Scaffold(
        body: Center(child: Text('No user data found')),
      );
    }

    print('ProfileScreen: Displaying user data: $userData');

    final dob = userData!['dob'] ?? 'Not specified';
    final location = userData!['location'] ?? 'Dharwad, India';
    final name = userData!['name'] ?? 'Yuva app';
    final uniqueName = userData!['uniqueName'] ?? 'DinnerLight25';
    final phone = userData!['phone'] ?? 'Not specified';
    final collegeName = userData!['collegeName'] ?? 'Not specified';
    final profileImageUrl = userData!['profileImageUrl'] as String?;
    final createdAt = (userData!['createdAt'] as Timestamp?)?.toDate();
    final tagline = userData!['tagline'] ?? 'Hey, I\'m on Yuva – Let\'s Grow Together!';
    final aboutMe = userData!['aboutMe'] ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Profile on Yuva'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue[600],
                    backgroundImage: profileImageUrl != null &&
                        profileImageUrl.isNotEmpty &&
                        Uri.tryParse(profileImageUrl)?.isAbsolute == true
                        ? NetworkImage(profileImageUrl)
                        : null,
                    child: (profileImageUrl == null ||
                        profileImageUrl.isEmpty ||
                        Uri.tryParse(profileImageUrl)?.isAbsolute != true)
                        ? Text(
                      _getInitials(name),
                      style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                    )
                        : null,
                  ),
                  GestureDetector(
                    onTap: () => _navigateToEditProfile(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Name and College
              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                collegeName,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tagline,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),

              // User Details
              _buildDetailCard(context, [
                _buildDetailItem(Icons.location_on, 'Location', location),
                _buildDetailItem(Icons.phone, 'Phone', phone),
                _buildDetailItem(Icons.cake, 'Date of Birth', dob),
                _buildDetailItem(Icons.person, 'Unique Name', uniqueName),
                if (createdAt != null)
                  _buildDetailItem(
                    Icons.calendar_today,
                    'Member Since',
                    '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                  ),
              ]),
              const SizedBox(height: 30),

              // Social Media Icons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialIcon(context, FontAwesomeIcons.xTwitter, Colors.black),
                  const SizedBox(width: 15),
                  _buildSocialIcon(context, FontAwesomeIcons.instagram, Colors.pink),
                  const SizedBox(width: 15),
                  _buildSocialIcon(context, FontAwesomeIcons.envelope, Colors.red),
                  const SizedBox(width: 15),
                  _buildSocialIcon(context, FontAwesomeIcons.linkedin, Colors.blue[800]!),
                ],
              ),
              const SizedBox(height: 30),

              // Profile Sections
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildProfileTab(context, 'About'),
                  _buildProfileTab(context, 'Posts'),
                  _buildProfileTab(context, 'Portfolio'),
                  _buildProfileTab(context, 'Certifications'),
                ],
              ),
              const SizedBox(height: 20),

              // About Me Content
              if (aboutMe.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About Me',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        aboutMe,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'Profile content appears here',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty || name.trim().isEmpty) {
      return '??';  // Default if name is empty
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

  Widget _buildDetailCard(BuildContext context, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEditProfile(BuildContext context) {
    print('ProfileScreen: Navigating to EditProfileScreen...');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          userData: userData!,
          onProfileUpdated: () {
            _fetchUserData();
            // Call the parent's callback if provided
            if (widget.onProfileUpdated != null) {
              widget.onProfileUpdated!();
            }
          },
        ),
      ),
    );
  }

  Widget _buildSocialIcon(BuildContext context, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        print('ProfileScreen: Tapped on social icon: $icon');
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.1),
        ),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildProfileTab(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}