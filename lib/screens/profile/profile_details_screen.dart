import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileDetailScreen extends StatefulWidget {
  final String userId;

  const ProfileDetailScreen({super.key, required this.userId});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<DocumentSnapshot> _userData;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _userData = _firestore.collection('users').doc(widget.userId).get();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.index = 0; // Default to About tab
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
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile on Medial',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: _userData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading profile', style: TextStyle(color: Colors.white)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('User not found', style: TextStyle(color: Colors.white)));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final name = userData['name'] ?? 'andeep Munna';
          final education = userData['education'] ?? 'Attended National Institute of Technology, Kurukshetra, Haryana';
          final location = userData['location'] ?? 'East Godavari, And...';
          final followers = userData['followers'] ?? 8;
          final joinedDate = userData['joinedDate'] ?? 'Apr 2025';
          final summary = userData['summary'] ?? 'I am a student in NIT, kurukshetra studying in Computer Engineering Department. I am learning new skills to keep myself';
          final tags = List<String>.from(userData['tags'] ?? ['saas', 'startup', 'education', 'edtech', 'learning']);
          final education_degree = userData['education_degree'] ?? 'B.tech';
          final education_period = userData['education_period'] ?? 'Nov 2022 - Present';

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile header
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Profile image
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: userData['profileImageUrl'] != null && userData['profileImageUrl'].isNotEmpty
                              ? Image.network(
                            userData['profileImageUrl'],
                            fit: BoxFit.cover,
                          )
                              : Center(
                            child: Text(
                              name.substring(0, 1).toUpperCase(),
                              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Name
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Education
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          education,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Stats section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, color: Colors.grey[400], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '$followers Followers',
                            style: TextStyle(color: Colors.grey[400], fontSize: 16),
                          ),
                          const SizedBox(width: 30),
                          Icon(Icons.location_on, color: Colors.grey[400], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            location,
                            style: TextStyle(color: Colors.grey[400], fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.grey[400], size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Joined $joinedDate',
                            style: TextStyle(color: Colors.grey[400], fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Social links
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _socialButton(
                        backgroundColor: Color(0xFF0077B5),
                        child: Text('in', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      const SizedBox(width: 15),
                      _socialButton(
                        backgroundColor: Color(0xFF1DA1F2),
                        child: Icon(Icons.wb_twighlight, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 15),
                      _socialButton(
                        backgroundColor: Colors.grey[700]!,
                        child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 15),
                      _socialButton(
                        backgroundColor: Color(0xFF4267B2),
                        child: Text('f', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.person_add, color: Colors.black),
                          label: Text('Follow', style: TextStyle(color: Colors.black)),
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFBF9AEF),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.message, color: Colors.white),
                          label: Text('Message', style: TextStyle(color: Colors.white)),
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey[700]!),
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tab Bar
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[800]!, width: 1),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    tabs: const [
                      Tab(text: 'About'),
                      Tab(text: 'Portfolio'),
                      Tab(text: 'Posts'),
                      Tab(text: 'Replies'),
                    ],
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                  ),
                ),

                // Content based on the selected tab
                SizedBox(
                  height: 500, // Give it enough height for the content
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // About Tab
                      _buildAboutTab(summary, tags, education_degree, education_period),
                      // Portfolio Tab
                      Center(child: Text('Portfolio Content', style: TextStyle(color: Colors.white))),
                      // Posts Tab
                      Center(child: Text('Posts Content', style: TextStyle(color: Colors.white))),
                      // Replies Tab
                      Center(child: Text('Replies Content', style: TextStyle(color: Colors.white))),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _socialButton({required Color backgroundColor, required Widget child}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Center(child: child),
    );
  }

  Widget _buildAboutTab(String summary, List<String> tags, String degree, String period) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$summary ',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
                TextSpan(
                  text: 'show more',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tags
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...tags.map((tag) => _buildTag(tag)).toList(),
              _buildTag('+ ${tags.length > 5 ? tags.length - 5 : 7}'),
            ],
          ),
          const SizedBox(height: 30),

          // Education timeline
          Container(
            padding: EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.grey[700]!, width: 2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.lightBlue,
                    shape: BoxShape.circle,
                  ),
                  margin: EdgeInsets.only(right: 15, top: 5),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      degree,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      period,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
    );
  }
}