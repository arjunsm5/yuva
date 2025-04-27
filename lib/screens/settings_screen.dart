import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // For authentication
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore
import 'package:yuva/screens/admin_panel_screen.dart'; // Import AdminPanelScreen
import 'package:yuva/screens/app_theme_screen.dart'; // Import AppThemeScreen
import 'package:yuva/screens/login_screen.dart'; // Import LoginScreen for navigation
import 'package:yuva/utils/app_theme.dart'; // Import AppTheme for colors

// 📄 SettingsScreen with modern UI and specified options
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.getBackground(context), // Dynamic background
      appBar: AppBar(
        backgroundColor: AppTheme.getBackground(context), // Match background
        elevation: 0, // No shadow for a flat look
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.getTextPrimary(context), // Dynamic icon color
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context), // Dynamic text color
            fontSize: 24,
            fontWeight: FontWeight.w700,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: FutureBuilder<String?>(
          future: _getCurrentPhoneNumber(),
          builder: (context, snapshot) {
            final currentPhone = snapshot.data ?? '';
            bool isAdmin = currentPhone == '+919876543210';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // 📋 Settings options as a list of tiles
                  _buildSettingsTile(
                    context,
                    icon: Icons.info_rounded,
                    title: 'About Yuva',
                    onTap: () {
                      // Placeholder: Navigate to About Yuva screen
                    },
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.brightness_6_rounded,
                    title: 'App Theme',
                    onTap: () {
                      // Navigate to App Theme screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AppThemeScreen()),
                      );
                    },
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.support_agent_rounded,
                    title: 'Feedback & Support',
                    onTap: () {
                      // Placeholder: Navigate to Feedback & Support screen
                    },
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.privacy_tip_rounded,
                    title: 'Privacy Policy',
                    onTap: () {
                      // Placeholder: Navigate to Privacy Policy screen
                    },
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.description_rounded,
                    title: 'Terms of Service',
                    onTap: () {
                      // Placeholder: Navigate to Terms of Service screen
                    },
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.share_rounded,
                    title: 'Share App',
                    onTap: () {
                      // Placeholder: Implement share functionality
                    },
                  ),
                  _buildSettingsTile(
                    context,
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    onTap: () {
                      // Show confirmation dialog before logging out
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirm Logout'),
                          content: const Text('Are you sure you want to log out?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context); // Close dialog
                                try {
                                  await FirebaseAuth.instance.signOut();
                                  // Clear the navigation stack and navigate to LoginScreen
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                        (Route<dynamic> route) => false, // Removes all previous routes
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error logging out: $e')),
                                  );
                                }
                              },
                              child: const Text(
                                'Logout',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (isAdmin)
                    _buildSettingsTile(
                      context,
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Admin Panel',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                  // 📜 Footer with app version
                  Center(
                    child: Text(
                      'Version 2.2.2',
                      style: TextStyle(
                        color: AppTheme.getTextSecondary(context), // Dynamic color
                        fontSize: 12,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // 🛠️ Helper method to build each settings tile with modern styling
  Widget _buildSettingsTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            leading: Icon(
              icon,
              color: AppTheme.getTextSecondary(context), // Dynamic icon color
              size: 28,
            ),
            title: Text(
              title,
              style: TextStyle(
                color: AppTheme.getTextPrimary(context), // Dynamic text color
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.getTextSecondary(context),
              size: 16,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }

  // Fetch the current user's phone number
  Future<String?> _getCurrentPhoneNumber() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.phoneNumber != null) {
        return user.phoneNumber; // Returns in format +919876543210
      }
      return null;
    } catch (e) {
      print('Error fetching phone number: $e');
      return null;
    }
  }
}