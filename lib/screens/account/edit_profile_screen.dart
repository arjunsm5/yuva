import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Edit Profile', style: TextStyle(color: Colors.white)),
            IconButton(
              icon: Icon(Icons.check_circle, color: Colors.green, size: 28),
              onPressed: () {},
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
            padding: EdgeInsets.all(16.0),
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
                        child: Text(
                          'UV',
                          style: TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.edit, size: 18, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Name Field
                _buildLabeledTextField("Name", initialValue: "Yuva app"),
                SizedBox(height: 10),

                // Unique Name Field
                _buildLabeledTextField("Unique Name", initialValue: "DinnerLight25"),
                Text(
                  'Unique name is for posting anonymously',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                SizedBox(height: 16),

                // Tagline Field
                _buildLabeledTextField("Tagline"),
                SizedBox(height: 10),

                // Location Field
                _buildLabeledTextField(
                  "Location",
                  initialValue: "Dharwad, India",
                  suffixIcon: Icon(Icons.my_location, color: Colors.grey),
                ),
                SizedBox(height: 20),

                // Social Links Section
                Text('Social links',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 16),

                // LinkedIn Field
                _buildSocialField(FontAwesomeIcons.linkedin, "LinkedIn", Colors.blue),
                SizedBox(height: 10),

                // Email Field
                _buildSocialField(FontAwesomeIcons.google, "yuva@gmail.com", Colors.red),
                SizedBox(height: 10),

                // Twitter Field
                _buildSocialField(FontAwesomeIcons.xTwitter, "Twitter(X)", Colors.grey),
                SizedBox(height: 10),

                // Instagram Field
                _buildSocialField(FontAwesomeIcons.instagram, "Instagram", Colors.purple),
                SizedBox(height: 20),

                // About Me Text Section
                Text('About Me',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tell us about yourself',
                      hintStyle: TextStyle(color: Colors.grey),
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(color: Colors.white),
                    maxLines: 5,
                  ),
                ),
              ],
            ),
          ),

          // Experience Tab
          SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
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
                SizedBox(height: 16),

                // Added Skills List
                _buildSkillItem("Education", () {}),
                SizedBox(height: 8),
                _buildSkillItem("Community development", () {}),
                SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledTextField(String label, {String? initialValue, Widget? suffixIcon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white, fontSize: 16)),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: initialValue != null ? TextEditingController(text: initialValue) : null,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
              suffixIcon: suffixIcon,
            ),
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSocialField(IconData icon, String value, Color iconColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FaIcon(icon, color: Colors.white, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: value),
              decoration: InputDecoration(
                border: InputBorder.none,
              ),
              style: TextStyle(color: Colors.white, fontSize: 16),
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
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.purple[300],
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            onPressed: () {},
            padding: EdgeInsets.all(0),
            constraints: BoxConstraints(
              minWidth: 30,
              minHeight: 30,
            ),
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
                  ? Icon(Icons.school, color: Colors.white)
                  : Icon(Icons.people, color: Colors.white),
            ),
            SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red[300],
            shape: BoxShape.circle,
          ),
          child: InkWell(
            onTap: onDelete,
            child: Icon(Icons.delete, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }
}