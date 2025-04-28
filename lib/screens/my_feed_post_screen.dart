import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_core/firebase_core.dart';
import 'package:cached_network_image/cached_network_image.dart';

// Screen displaying the feed of posts
class MyFeedPostScreen extends StatelessWidget {
  const MyFeedPostScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        // StreamBuilder to listen to real-time updates from Firestore
        child: StreamBuilder<QuerySnapshot>(
          // Stream posts ordered by creation time (newest first)
          stream: FirebaseFirestore.instance
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            // Show loading indicator while waiting for data
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            // Handle errors
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error loading posts: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            // Handle empty data
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'No posts available',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            // Build list of posts
            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                var data = doc.data() as Map<String, dynamic>;
                return PostItem(postData: data);
              },
            );
          },
        ),
      ),
    );
  }
}

// Widget representing a single post item
class PostItem extends StatelessWidget {
  final Map<String, dynamic> postData; // Post data from Firestore

  const PostItem({Key? key, required this.postData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Format timestamp to show relative time (e.g., "5 minutes ago")
    String timeAgo = '';
    if (postData['createdAt'] != null) {
      final Timestamp timestamp = postData['createdAt'];
      final DateTime dateTime = timestamp.toDate();
      timeAgo = timeago.format(dateTime);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // Fetch user and hub data asynchronously
          FutureBuilder<Map<String, String>>(
            future: _fetchUserAndHubData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator(color: Colors.white);
              }
              // Default to empty strings if data is not available
              final userData = snapshot.data ?? {'profileImage': '', 'hubImage': ''};
              return _buildUserHeader(
                userName: postData['userName'] ?? 'Unknown User',
                userProfileImage: userData['profileImage'] ?? '',
                timeAgo: timeAgo,
                hubImage: userData['hubImage'] ?? '',
              );
            },
          ),
          const SizedBox(height: 16),
          _buildPostTitle(postData['content'] ?? 'No content'),
          const SizedBox(height: 16),
          _buildPostImage(),
          const SizedBox(height: 16),
          _buildInteractionBar(),
          const Divider(color: Colors.grey, height: 32),
        ],
      ),
    );
  }

  // Fetch user profile image and hub image from Firestore
  Future<Map<String, String>> _fetchUserAndHubData() async {
    String profileImage = '';
    String hubImage = '';

    try {
      // Fetch user profile image from users collection
      if (postData['userId'] != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(postData['userId'])
            .get();
        if (userDoc.exists) {
          profileImage = userDoc.data()?['profileImage'] ?? '';
        }
      }

      // Fetch hub image from hubs collection
      if (postData['hubId'] != null) {
        final hubDoc = await FirebaseFirestore.instance
            .collection('hubs')
            .doc(postData['hubId'])
            .get();
        if (hubDoc.exists) {
          hubImage = hubDoc.data()?['hubImage'] ?? '';
        }
      }
    } catch (e) {
      print('Error fetching user/hub data: $e');
    }

    return {
      'profileImage': profileImage,
      'hubImage': hubImage,
    };
  }

  // Build user header with profile image, username, timestamp, and hub image
  Widget _buildUserHeader({
    required String userName,
    required String userProfileImage,
    required String timeAgo,
    required String hubImage,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // Display user profile image
            userProfileImage.isNotEmpty
                ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: userProfileImage,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 40,
                  height: 40,
                  color: Colors.grey[800],
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 40,
                  height: 40,
                  color: Colors.grey[800],
                  child: const Icon(Icons.person, color: Colors.white),
                ),
              ),
            )
                : Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  timeAgo,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
        // Display hub image
        hubImage.isNotEmpty
            ? ClipOval(
          child: CachedNetworkImage(
            imageUrl: hubImage,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 40,
              height: 40,
              color: const Color(0xFF1D3D4D),
              child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
            ),
            errorWidget: (context, url, error) => Container(
              width: 40,
              height: 40,
              color: const Color(0xFF1D3D4D),
              child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
            ),
          ),
        )
            : Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFF1D3D4D),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
        ),
      ],
    );
  }

  // Build post title/content
  Widget _buildPostTitle(String content) {
    return Text(
      content,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // Build post image or placeholder
  Widget _buildPostImage() {
    final postImage = postData['postImage'] ?? '';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: postImage.isNotEmpty
          ? CachedNetworkImage(
        imageUrl: postImage,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (context, url) => Container(
          height: 200,
          color: Colors.grey[800],
          child: const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        errorWidget: (context, url, error) => Container(
          height: 200,
          color: Colors.grey[800],
          child: const Icon(Icons.image_not_supported, color: Colors.white, size: 50),
        ),
      )
          : Container(
        height: 200,
        color: Colors.grey[800],
        child: const Icon(Icons.image_not_supported, color: Colors.white, size: 50),
      ),
    );
  }

  // Build interaction bar with voting, comments, bookmark, and share buttons
  Widget _buildInteractionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // Upvote button
            Column(
              children: const [
                Icon(Icons.arrow_upward, color: Colors.green, size: 28),
                SizedBox(height: 2),
                Text(
                  '6',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Downvote button
            Column(
              children: const [
                Icon(Icons.arrow_downward, color: Colors.red, size: 28),
                SizedBox(height: 2),
                Text(
                  ' ',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            // Comments button
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade800),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.chat_bubble_outline, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    '1',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Bookmark button
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade800),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bookmark_border, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text(
                    '1',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Share button
            const Icon(Icons.share, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            // More options button
            const Icon(Icons.more_vert, color: Colors.white, size: 28),
          ],
        ),
      ],
    );
  }
}