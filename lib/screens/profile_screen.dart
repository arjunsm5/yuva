import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  const CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(
                        'https://randomuser.me/api/portraits/men/1.jpg'),
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

              // Name and Tagline
              const Text(
                'Yuva App',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hey, I\'m on Yuva – Let\'s Grow Together!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),

              // Location and Joined Date
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildInfoItem(context, Icons.location_on, 'Dharwad, India', false),
                  const SizedBox(width: 20),
                  _buildInfoItem(context, Icons.calendar_today, 'Joined: 27/02/2025', true),
                ],
              ),
              const SizedBox(height: 30),

              // Social Media Icons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialIcon(context, FontAwesomeIcons.twitter, Colors.black),
                  const SizedBox(width: 15),
                  _buildSocialIcon(context, FontAwesomeIcons.instagram, Colors.pink),
                  const SizedBox(width: 15),
                  _buildSocialIcon(context, FontAwesomeIcons.envelope, Colors.red),
                  const SizedBox(width: 15),
                  _buildSocialIcon(context, FontAwesomeIcons.linkedin, Colors.blue[800]!),
                ],
              ),
              const SizedBox(height: 30),

              // About Section
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

              // Content would go here based on selected tab
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

  void _navigateToEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditProfileScreen()),
    );
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String text, bool isChecked) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isChecked ? Colors.blue : Colors.grey,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: isChecked ? Colors.blue : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(BuildContext context, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        // Add functionality for each social media icon
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

