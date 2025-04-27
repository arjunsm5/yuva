import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yuva/utils/app_theme.dart'; // Import AppTheme for colors
import 'package:yuva/utils/theme_provider.dart'; // Import ThemeProvider for theme state

// 📄 AppThemeScreen to allow users to select the app's theme
class AppThemeScreen extends StatelessWidget {
  const AppThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 📡 Access the ThemeProvider to manage theme state
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.getBackground(context), // Dynamic background
      appBar: AppBar(
        backgroundColor: AppTheme.getBackground(context), // Match background
        elevation: 0, // No shadow for a flat look
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: AppTheme.getTextPrimary(context), // Dynamic icon color
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'App Theme',
          style: TextStyle(
            color: AppTheme.getTextPrimary(context), // Dynamic text color
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📻 Theme selection radio buttons
            _buildThemeOption(
              context,
              title: 'Light',
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                // Update the theme when the user selects Light
                themeProvider.setThemeMode(value!);
              },
            ),
            _buildThemeOption(
              context,
              title: 'Dark',
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                // Update the theme when the user selects Dark
                themeProvider.setThemeMode(value!);
              },
            ),
            _buildThemeOption(
              context,
              title: 'System',
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                // Update the theme when the user selects System
                themeProvider.setThemeMode(value!);
              },
            ),
            const SizedBox(height: 20),
            // 🚫 Placeholder for Material You Dynamic Theme (not implemented)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Material You Dynamic Theme',
                  style: TextStyle(
                    color: AppTheme.getTextPrimary(context), // Dynamic text color
                    fontSize: 16,
                    fontFamily: 'Poppins',
                  ),
                ),
                Switch(
                  value: false, // Disabled as per the screenshot
                  onChanged: (value) {}, // Placeholder: Not implemented
                  activeColor: AppTheme.getPrimary(context), // Dynamic color
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🛠️ Helper method to build each theme option radio button
  Widget _buildThemeOption(
      BuildContext context, {
        required String title,
        required ThemeMode value,
        required ThemeMode groupValue,
        required ValueChanged<ThemeMode?> onChanged,
      }) {
    return RadioListTile<ThemeMode>(
      title: Text(
        title,
        style: TextStyle(
          color: AppTheme.getTextPrimary(context), // Dynamic text color
          fontSize: 16,
          fontFamily: 'Poppins',
        ),
      ),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: AppTheme.getPrimary(context), // Dynamic radio button color
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
    );
  }
}