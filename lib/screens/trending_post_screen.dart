import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TrendingPostScreen extends StatefulWidget {
  const TrendingPostScreen({super.key});

  @override
  State<TrendingPostScreen> createState() => _TrendingPostScreenState();
}

class _TrendingPostScreenState extends State<TrendingPostScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> posts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .get();
      final postList = await Future.wait(snapshot.docs.map((doc) async {
        final postData = doc.data() as Map<String, dynamic>;
        final userId = postData['userId'];
        final userDoc =
        await _firestore.collection('users').doc(userId).get();
        final userData = userDoc.data() ?? {};
        final hubId = postData['hubId'];
        final hubDoc = hubId != null
            ? await _firestore.collection('hubs').doc(hubId).get()
            : null;
        final hubData = hubDoc?.data() ?? {};

        // Extract hashtags from content if not already provided
        List<String> hashtags = [];
        if (postData['hashtags'] != null) {
          hashtags = List<String>.from(postData['hashtags']);
        } else if (postData['content'] != null) {
          final String content = postData['content'];
          final RegExp hashtagRegExp = RegExp(r'#\w+');
          hashtags = hashtagRegExp.allMatches(content)
              .map((match) => content.substring(match.start, match.end))
              .toList();
        }

        return {
          'id': doc.id,
          ...postData,
          'userName': userData['name'] ?? 'Anonymous',
          'userTag': userData['userTag'] ?? '',
          'userTitle': userData['title'] ?? '',
          'userProfileImage': userData['profileImageUrl'] ?? '',
          'hubName': hubData['name'] ?? '',
          'hubImage': hubData['imageUrl'] ?? '',
          'upvotes': postData['upvotes'] ?? 0,
          'downvotes': postData['downvotes'] ?? 0,
          'comments': postData['comments'] ?? 0,
          'bookmarks': postData['bookmarks'] ?? 0,
          'hashtags': hashtags,
        };
      }));
      setState(() {
        posts = postList;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching posts: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final Duration difference = DateTime.now().difference(dateTime);
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
          ? const Center(
        child: Text(
          'No posts available',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: posts.length,
        itemBuilder: (context, index) {
          final post = posts[index];
          final userName = post['userName'] ?? 'Anonymous';
          final userTitle = post['userTitle'] ?? '';
          final profileImageUrl = post['userProfileImage'];
          final createdAt = post['createdAt'] as Timestamp;
          final content = post['content'] ?? '';
          final images = post['images'] as List<dynamic>? ?? [];
          final hashtags = List<String>.from(post['hashtags'] ?? []);
          final upvotes = post['upvotes'] ?? 0;
          final downvotes = post['downvotes'] ?? 0;
          final comments = post['comments'] ?? 0;
          final bookmarks = post['bookmarks'] ?? 0;
          final hubImage = post['hubImage'];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User profile header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: profileImageUrl != null && profileImageUrl.isNotEmpty
                          ? Image.network(
                        profileImageUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 40,
                            height: 40,
                            color: Colors.grey,
                            child: const Icon(Icons.person, color: Colors.white),
                          );
                        },
                      )
                          : Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // User info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.article_outlined,
                                size: 20,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                          Text(
                            '$userTitle ${_formatTimestamp(createdAt)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Hub image (replacing notification icon)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: hubImage != null && hubImage.isNotEmpty
                          ? Image.network(
                        hubImage,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 36,
                            height: 36,
                            color: Colors.amber,
                            child: const Icon(Icons.campaign_outlined, color: Colors.white, size: 20),
                          );
                        },
                      )
                          : Container(
                        width: 36,
                        height: 36,
                        color: Colors.amber,
                        child: const Icon(Icons.campaign_outlined, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // Post content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  content,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                    height: 1.3,
                  ),
                ),
              ),

              // Hashtags
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    ...hashtags.take(5).map((tag) => Text(
                      tag,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    )),
                    if (hashtags.length > 5)
                      Text(
                        "...show more",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.purple[300],
                        ),
                      ),
                  ],
                ),
              ),

              // Post image
              if (images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16/9,
                      child: Image.network(
                        images[0],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback to MEDIAL logo if image fails to load
                          return Container(
                            color: Colors.black,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 80,
                                      color: Colors.deepPurple[400],
                                      child: const Center(
                                        child: Text(
                                          "m.",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 60,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "MEDIAL",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const Text(
                                      "All Things Startup.",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                )
              else
              // Show MEDIAL logo as default
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.black,
                      width: double.infinity,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 80,
                                color: Colors.deepPurple[400],
                                child: const Center(
                                  child: Text(
                                    "m.",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 60,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "MEDIAL",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const Text(
                                "All Things Startup.",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Comment icon with count
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, size: 22),
                          onPressed: () {},
                          color: Colors.grey[600],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$comments',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),

                    // Upvote icon with count
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 22),
                          onPressed: () {},
                          color: Colors.grey[600],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$upvotes',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),

                    // Downvote icon with count
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 22),
                          onPressed: () {},
                          color: Colors.grey[600],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$downvotes',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),

                    // Bookmark icon with count
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.bookmark_border, size: 22),
                          onPressed: () {},
                          color: Colors.grey[600],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$bookmarks',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),

                    // Send icon
                    IconButton(
                      icon: const Icon(Icons.send, size: 22),
                      onPressed: () {},
                      color: Colors.grey[600],
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),

                    // More options icon
                    IconButton(
                      icon: const Icon(Icons.more_horiz, size: 22),
                      onPressed: () {},
                      color: Colors.grey[600],
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Bottom gray line
              const Divider(
                height: 16,
                thickness: 1,
                color: Colors.black12,
              ),
            ],
          );
        },
      ),
    );
  }
}