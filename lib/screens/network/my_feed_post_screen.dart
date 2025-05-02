import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_core/firebase_core.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yuva/screens/network/post_detail_screen.dart';
import '../profile/profile_details_screen.dart';

// Screen displaying the feed of posts
class MyFeedPostScreen extends StatelessWidget {
  const MyFeedPostScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      host: 'firestore.googleapis.com',
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }
            if (snapshot.hasError) {
              print('StreamBuilder error: ${snapshot.error}');
              return Center(
                child: Text(
                  'Error loading posts: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              print('No posts found in Firestore');
              return const Center(
                child: Text(
                  'No posts available',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }
            print('Posts fetched: ${snapshot.data!.docs.length}');
            for (var doc in snapshot.data!.docs) {
              print('Post ID: ${doc.id}, Data: ${doc.data()}');
            }
            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                var data = doc.data() as Map<String, dynamic>;
                return PostItem(postData: data, postId: doc.id);
              },
            );
          },
        ),
      ),
    );
  }
}

// Stateful widget for individual post items
class PostItem extends StatefulWidget {
  final Map<String, dynamic> postData;
  final String postId;

  const PostItem({Key? key, required this.postData, required this.postId})
      : super(key: key);

  @override
  _PostItemState createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  late int score;
  late bool hasUpvoted;
  late bool hasDownvoted;
  late bool isBookmarked;
  late String currentUserId;
  bool isLoading = false;
  Map<String, dynamic>? userData;
  Map<String, dynamic>? hubData;
  String? userVote;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    score = ((widget.postData['upvotes'] ?? 0) - (widget.postData['downvotes'] ?? 0));
    hasUpvoted = false; // Reset initial state
    hasDownvoted = false; // Reset initial state
    isBookmarked = false; // Reset initial state
    print('PostItem init - Post ID: ${widget.postId}, User ID: $currentUserId, Data: ${widget.postData}');

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          currentUserId = user?.uid ?? '';
          print('Auth state changed, currentUserId: $currentUserId');
        });
        if (currentUserId.isNotEmpty) {
          _checkUserInteractions();
          _checkPollVote();
        }
      }
    });

    _fetchInitialData();
    _checkUserInteractions();
    _checkPollVote();
  }

  Future<void> _fetchInitialData() async {
    if (!(widget.postData['isAnonymous'] ?? false)) {
      userData = await _fetchUserData();
    }
    hubData = await _fetchHubData(widget.postData['hubId']);
    if (mounted) setState(() {});
  }

  Future<void> _checkUserInteractions() async {
    if (currentUserId.isEmpty) return;
    try {
      final postDoc = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
      final data = postDoc.data() as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          hasUpvoted = (data?['upvotedBy'] as List<dynamic>?)?.contains(currentUserId) ?? false;
          hasDownvoted = (data?['downvotedBy'] as List<dynamic>?)?.contains(currentUserId) ?? false;
          isBookmarked = (data?['bookmarkedBy'] as List<dynamic>?)?.contains(currentUserId) ?? false;
        });
      }
    } catch (e) {
      print('Error checking user interactions: $e');
    }
  }

  Future<void> _checkPollVote() async {
    if (currentUserId.isEmpty) return;
    try {
      final pollVoteDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('poll_votes')
          .doc(currentUserId)
          .get();
      if (pollVoteDoc.exists) {
        if (mounted) {
          setState(() {
            userVote = pollVoteDoc.data()?['option'];
          });
        }
      }
    } catch (e) {
      print('Error checking poll vote: $e');
    }
  }

  Future<void> castPollVote(String option) async {
    if (currentUserId.isEmpty || isLoading) {
      print('Cannot cast vote: User not authenticated or loading');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to vote')),
      );
      return;
    }
    if (userVote != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already voted in this poll')),
      );
      return;
    }
    setState(() => isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      final voteRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('poll_votes')
          .doc(currentUserId);

      int optionIndex = widget.postData['poll']['options'].indexOf(option);
      batch.update(postRef, {
        'poll.votes.$optionIndex': FieldValue.increment(1),
        'poll.voters.$optionIndex': FieldValue.arrayUnion([currentUserId]),
      });
      batch.set(voteRef, {
        'option': option,
        'userId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
      if (mounted) {
        setState(() {
          userVote = option;
        });
      }
    } catch (e) {
      print('Error casting poll vote: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cast vote: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> updateVote(String voteType) async {
    if (currentUserId.isEmpty || isLoading) {
      print('Cannot vote: User not authenticated or loading');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to vote')),
      );
      return;
    }
    setState(() => isLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      final userVoteRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('votes')
          .doc(widget.postId);

      final postDoc = await postRef.get();
      final currentUpvotedBy = (postDoc.data()?['upvotedBy'] as List<dynamic>?) ?? [];
      final currentDownvotedBy = (postDoc.data()?['downvotedBy'] as List<dynamic>?) ?? [];

      if (voteType == 'upvote') {
        if (hasUpvoted) {
          setState(() {
            hasUpvoted = false;
            score--;
          });
          batch.update(postRef, {
            'upvotes': FieldValue.increment(-1),
            'upvotedBy': FieldValue.arrayRemove([currentUserId])
          });
          batch.delete(userVoteRef);
        } else {
          if (hasDownvoted) {
            setState(() {
              hasDownvoted = false;
              hasUpvoted = true;
              score += 2;
            });
            batch.update(postRef, {
              'downvotes': FieldValue.increment(-1),
              'downvotedBy': FieldValue.arrayRemove([currentUserId]),
              'upvotes': FieldValue.increment(1),
              'upvotedBy': FieldValue.arrayUnion([currentUserId])
            });
          } else {
            setState(() {
              hasUpvoted = true;
              score++;
            });
            batch.update(postRef, {
              'upvotes': FieldValue.increment(1),
              'upvotedBy': FieldValue.arrayUnion([currentUserId])
            });
          }
          batch.set(userVoteRef, {
            'type': 'upvote',
            'userId': currentUserId,
            'postId': widget.postId,
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else if (voteType == 'downvote') {
        if (hasDownvoted) {
          setState(() {
            hasDownvoted = false;
            score++;
          });
          batch.update(postRef, {
            'downvotes': FieldValue.increment(-1),
            'downvotedBy': FieldValue.arrayRemove([currentUserId])
          });
          batch.delete(userVoteRef);
        } else {
          if (hasUpvoted) {
            setState(() {
              hasUpvoted = false;
              hasDownvoted = true;
              score -= 2;
            });
            batch.update(postRef, {
              'upvotes': FieldValue.increment(-1),
              'upvotedBy': FieldValue.arrayRemove([currentUserId]),
              'downvotes': FieldValue.increment(1),
              'downvotedBy': FieldValue.arrayUnion([currentUserId])
            });
          } else {
            setState(() {
              hasDownvoted = true;
              score--;
            });
            batch.update(postRef, {
              'downvotes': FieldValue.increment(1),
              'downvotedBy': FieldValue.arrayUnion([currentUserId])
            });
          }
          batch.set(userVoteRef, {
            'type': 'downvote',
            'userId': currentUserId,
            'postId': widget.postId,
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
      await batch.commit();
    } catch (e) {
      print('Error updating vote: $e');
      _checkUserInteractions();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update vote: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> toggleBookmark() async {
    if (currentUserId.isEmpty || isLoading) {
      print('Cannot toggle bookmark: User not authenticated or loading');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to bookmark posts')),
      );
      return;
    }
    setState(() => isLoading = true);
    try {
      print('Attempting to toggle bookmark for user: $currentUserId, post: ${widget.postId}');
      final bookmarkRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('bookmarks')
          .doc(widget.postId);
      final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);

      if (isBookmarked) {
        print('Deleting bookmark for post ${widget.postId}');
        await bookmarkRef.delete();
        await postRef.update({
          'bookmarkedBy': FieldValue.arrayRemove([currentUserId])
        });
        if (mounted) {
          setState(() => isBookmarked = false);
        }
      } else {
        print('Adding bookmark for post ${widget.postId}');
        await bookmarkRef.set({
          'postId': widget.postId,
          'userId': currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
          'postData': widget.postData,
        });
        await postRef.update({
          'bookmarkedBy': FieldValue.arrayUnion([currentUserId])
        });
        if (mounted) {
          setState(() => isBookmarked = true);
        }
      }
    } catch (e) {
      print('Error toggling bookmark: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update bookmark: $e')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void sharePost() {
    final String postContent = widget.postData['content'] ?? 'Check out this post!';
    Share.share('$postContent\nShared from MyApp');
  }

  void showOptionsMenu(BuildContext context) {
    final bool isCurrentUserPost = widget.postData['userId'] == currentUserId;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentUserPost)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete post', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
            if (!isCurrentUserPost)
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.orange),
                title: const Text('Report post', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileDetailScreen(userId: widget.postData['userId']),
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    String secureUrl = url.trim();
    if (!secureUrl.startsWith('http://') && !secureUrl.startsWith('https://')) {
      secureUrl = 'https://$secureUrl';
    }
    secureUrl = secureUrl.startsWith('http:') ? secureUrl.replaceFirst('http:', 'https:') : secureUrl;

    final Uri? uri = Uri.tryParse(secureUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      print('Invalid URL: $secureUrl');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid URL format')),
      );
      return;
    }

    print('Attempting to launch URL: $secureUrl');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('Cannot launch URL: $secureUrl');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot launch URL: $secureUrl')),
        );
      }
    } catch (e) {
      print('Error launching URL: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error launching URL: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String timeAgo = widget.postData['createdAt'] != null
        ? timeago.format((widget.postData['createdAt'] as Timestamp).toDate())
        : '';
    bool isAnonymous = widget.postData['isAnonymous'] ?? false;
    String displayName = isAnonymous
        ? widget.postData['uniqueName'] ?? 'Anonymous'
        : (widget.postData['userName'] ?? 'Unknown User');
    final poll = widget.postData['poll'] as Map<String, dynamic>?;
    final link = widget.postData['link'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          (hubData != null)
              ? _buildUserHeader(
            userName: displayName,
            userProfileImage: userData != null ? userData!['userProfileImage'] ?? '' : '',
            timeAgo: timeAgo,
            hubImage: hubData!['hubImage'] ?? '',
            hubName: hubData!['hubName'] ?? '',
            isAnonymous: isAnonymous,
          )
              : const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailScreen(
                    postId: widget.postId,
                    postData: widget.postData,
                  ),
                ),
              );
            },
            child: _buildPostTitle(widget.postData['content'] ?? 'No content'),
          ),
          if (poll != null) ...[
            const SizedBox(height: 16),
            _buildPoll(poll),
            const SizedBox(height: 8),
            _buildPollVoteCount(poll),
          ],
          if (link != null) ...[
            const SizedBox(height: 16),
            _buildLink(link),
          ],
          const SizedBox(height: 16),
          _buildPostImages(),
          const SizedBox(height: 16),
          _buildInteractionBar(),
          const Divider(color: Colors.grey, height: 32),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchHubData(String? hubId) async {
    if (hubId == null || hubId.isEmpty) return {};
    try {
      final hubDoc = await FirebaseFirestore.instance.collection('hubs').doc(hubId).get();
      if (hubDoc.exists) {
        final hubData = hubDoc.data() ?? {};
        return {
          'hubImage': hubData['hubImage'] ?? '',
          'hubName': hubData['name'] ?? '',
        };
      }
    } catch (e) {
      print('Error fetching hub data: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> _fetchUserData() async {
    String userProfileImage = '';
    try {
      if (widget.postData['userId'] != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.postData['userId'])
            .get();
        if (userDoc.exists) {
          userProfileImage = userDoc.data()?['profileImageUrl'] ?? '';
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
    return {'userProfileImage': userProfileImage};
  }

  Widget _buildUserHeader({
    required String userName,
    required String userProfileImage,
    required String timeAgo,
    required String hubImage,
    required String hubName,
    required bool isAnonymous,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: isAnonymous ? null : () => _navigateToProfile(context),
              child: isAnonymous
                  ? Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.visibility_off, color: Colors.white),
              )
                  : (userProfileImage.isNotEmpty
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
              )),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: isAnonymous ? null : () => _navigateToProfile(context),
              child: Column(
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
            ),
          ],
        ),
        InkWell(
          onTap: widget.postData['hubId'] != null
              ? () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Navigating to $hubName hub')),
            );
          }
              : null,
          child: Tooltip(
            message: hubName.isNotEmpty ? hubName : 'Hub',
            child: hubImage.isNotEmpty
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
                  child: const Icon(Icons.local_fire_department,
                      color: Colors.orange, size: 24),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 40,
                  height: 40,
                  color: const Color(0xFF1D3D4D),
                  child: const Icon(Icons.local_fire_department,
                      color: Colors.orange, size: 24),
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
              child: const Icon(Icons.local_fire_department,
                  color: Colors.orange, size: 24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostTitle(String content) {
    return Text(
      content.length > 100 ? '${content.substring(0, 100)}... [Show more]' : content,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildPoll(Map<String, dynamic> poll) {
    final options = poll['options'] as List<dynamic>;
    final votesMap = poll['votes'] as Map<String, dynamic>;
    final votes = List<int>.generate(options.length, (index) => votesMap[index.toString()] as int? ?? 0);
    final totalVotes = votes.fold(0, (sum, vote) => sum + vote);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(options.length, (index) {
        final option = options[index] as String;
        final voteCount = votes[index];
        final percentage = totalVotes > 0 ? (voteCount / totalVotes * 100).round() : 0;
        final isSelected = userVote == option;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: GestureDetector(
            onTap: isSelected || userVote != null || isLoading
                ? null
                : () => castPollVote(option),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.transparent),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option,
                          style: TextStyle(
                            color: isSelected ? Colors.purpleAccent : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                              width: (MediaQuery.of(context).size.width - 80) * (totalVotes > 0 ? voteCount / totalVotes : 0),
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isSelected
                                      ? [Colors.purpleAccent, Colors.pinkAccent]
                                      : [Colors.blueAccent, Colors.cyanAccent],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: isSelected ? Colors.purpleAccent : Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPollVoteCount(Map<String, dynamic> poll) {
    final votesMap = poll['votes'] as Map<String, dynamic>;
    final votes = List<int>.generate(poll['options'].length, (index) => votesMap[index.toString()] as int? ?? 0);
    final totalVotes = votes.fold(0, (sum, vote) => sum + vote);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (userVote != null)
          Text(
            'You have voted for $userVote',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        Text(
          'Votes: $totalVotes',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLink(String link) {
    return InkWell(
      onTap: () => _launchURL(link),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.link, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                link,
                style: const TextStyle(
                  color: Colors.lightBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostImages() {
    final dynamic images = widget.postData['images'];
    if (images is List && images.isNotEmpty) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: images.length,
        itemBuilder: (context, index) {
          final imageUrl = images[index] as String;
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _FullScreenImageViewer(imageUrl: imageUrl),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 200,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: Colors.grey[800],
                  child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: Colors.grey[800],
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildInteractionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: isLoading ? null : () => updateVote('upvote'),
              icon: Icon(
                Icons.arrow_upward,
                color: hasUpvoted ? Colors.green : Colors.white,
                size: 28,
              ),
            ),
            Text(
              '$score',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            IconButton(
              onPressed: isLoading ? null : () => updateVote('downvote'),
              icon: Icon(
                Icons.arrow_downward,
                color: hasDownvoted ? Colors.red : Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
        Row(
          children: [
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailScreen(
                    postId: widget.postId,
                    postData: widget.postData,
                  ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade800),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(widget.postId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text(
                            '0',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          );
                        }
                        final data = snapshot.data?.data() as Map<String, dynamic>?;
                        final commentCount = (data != null && data.containsKey('comments') && data['comments'] != null)
                            ? (data['comments'] as List<dynamic>).length
                            : 0;
                        return Text(
                          '$commentCount',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            InkWell(
              onTap: isLoading ? null : toggleBookmark,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade800),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: isBookmarked ? Colors.blue : Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .doc(widget.postId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text(
                            '0',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          );
                        }
                        final data = snapshot.data?.data() as Map<String, dynamic>?;
                        final bookmarkCount = (data != null && data.containsKey('bookmarkedBy') && data['bookmarkedBy'] != null)
                            ? (data['bookmarkedBy'] as List<dynamic>).length
                            : 0;
                        return Text(
                          '$bookmarkCount',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: sharePost,
              icon: const Icon(Icons.share, color: Colors.white, size: 28),
            ),
            IconButton(
              onPressed: () => showOptionsMenu(context),
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
            ),
          ],
        ),
      ],
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageViewer({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Icon(
              Icons.error,
              color: Colors.white,
              size: 50,
            ),
          ),
        ),
      ),
    );
  }
}