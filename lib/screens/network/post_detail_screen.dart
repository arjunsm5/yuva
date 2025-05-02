import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// PostDetailScreen displays the details of a post, including user header, comments, and a fixed comment input at the bottom.
class PostDetailScreen extends StatefulWidget {
  final String postId; // Unique ID of the post
  final Map<String, dynamic> postData; // Data of the post (content, user info, etc.)

  const PostDetailScreen({
    Key? key,
    required this.postId,
    required this.postData,
  }) : super(key: key);

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController(); // Controller for the comment input field
  bool _isSubmitting = false; // Tracks if a comment is being submitted
  late String currentUserId; // Stores the ID of the currently logged-in user
  late bool isAnonymousComment; // Determines if the comment should be anonymous
  Map<String, dynamic>? userData; // Stores data of the current user
  Map<String, dynamic>? hubData; // Stores data of the hub the post belongs to
  late int score; // Post score (upvotes - downvotes)
  late bool hasUpvoted; // Tracks if the user has upvoted the post
  late bool hasDownvoted; // Tracks if the user has downvoted the post
  late bool isBookmarked; // Tracks if the user has bookmarked the post
  bool isLoading = false; // General loading state for async operations
  String? userVote; // Tracks the user's vote in a poll
  late double screenWidth; // Screen width for responsive design
  late double screenHeight; // Screen height for responsive design
  late double padding; // Padding for consistent spacing
  String? replyingToCommentId; // ID of the comment being replied to

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    isAnonymousComment = false;
    score = ((widget.postData['upvotes'] ?? 0) - (widget.postData['downvotes'] ?? 0));
    hasUpvoted = false;
    hasDownvoted = false;
    isBookmarked = false;
    userData = null;
    hubData = null;
    replyingToCommentId = null;

    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          currentUserId = user?.uid ?? '';
        });
        if (currentUserId.isNotEmpty) {
          _fetchInitialData();
          _checkUserInteractions();
          _checkPollVote();
        }
      }
    });

    if (currentUserId.isNotEmpty) {
      _fetchInitialData();
      _checkUserInteractions();
      _checkPollVote();
    }
  }

  // Fetches initial data for the user and hub
  Future<void> _fetchInitialData() async {
    if (currentUserId.isNotEmpty) {
      userData = await _fetchUserData();
    } else {
      userData = {'name': 'Anonymous', 'profileImageUrl': ''};
    }
    if (widget.postData['hubId'] != null) {
      hubData = await _fetchHubData(widget.postData['hubId']);
    } else {
      hubData = {};
    }
    if (mounted) setState(() {});
  }

  // Fetches user data from the 'users' collection
  Future<Map<String, dynamic>> _fetchUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      if (userDoc.exists) {
        return userDoc.data()! as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
    return {'name': 'Anonymous', 'profileImageUrl': ''};
  }

  // Fetches hub data from the 'hubs' collection
  Future<Map<String, dynamic>> _fetchHubData(String? hubId) async {
    if (hubId == null || hubId.isEmpty) return {};
    try {
      final hubDoc = await FirebaseFirestore.instance.collection('hubs').doc(hubId).get();
      if (hubDoc.exists) {
        return hubDoc.data()! as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching hub data: $e');
    }
    return {};
  }

  // Checks user interactions (upvotes, downvotes, bookmarks) with the post
  Future<void> _checkUserInteractions() async {
    if (currentUserId.isEmpty) return;
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();
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

  // Checks if the user has voted in the poll
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
        final data = pollVoteDoc.data() as Map<String, dynamic>?;
        if (mounted) {
          setState(() {
            userVote = data?['option'];
          });
        }
      }
    } catch (e) {
      print('Error checking poll vote: $e');
    }
  }

  // Casts a vote in the poll
  Future<void> castPollVote(String option) async {
    if (currentUserId.isEmpty || isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to vote')));
      return;
    }
    if (userVote != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have already voted in this poll')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cast vote: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Updates the vote (upvote or downvote) for a post, comment, or reply
  Future<void> updateVote(String voteType, {String? commentId, String? replyId, required Function(int, bool, bool) onUpdate}) async {
    if (currentUserId.isEmpty || isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to vote')));
      return;
    }
    setState(() => isLoading = true);
    try {
      DocumentReference targetRef;
      String votePath;

      if (commentId != null) {
        if (replyId != null) {
          targetRef = FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.postId)
              .collection('comments')
              .doc(commentId)
              .collection('replies')
              .doc(replyId);
          votePath = 'users/$currentUserId/votes/$commentId-$replyId';
        } else {
          targetRef = FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.postId)
              .collection('comments')
              .doc(commentId);
          votePath = 'users/$currentUserId/votes/$commentId';
        }
      } else {
        targetRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
        votePath = 'users/$currentUserId/votes/${widget.postId}';
      }

      final userVoteRef = FirebaseFirestore.instance.doc(votePath);
      final doc = await targetRef.get();
      final data = doc.data() as Map<String, dynamic>?;
      final currentUpvotedBy = (data?['upvotedBy'] as List<dynamic>?) ?? [];
      final currentDownvotedBy = (data?['downvotedBy'] as List<dynamic>?) ?? [];
      bool currentHasUpvoted = currentUpvotedBy.contains(currentUserId);
      bool currentHasDownvoted = currentDownvotedBy.contains(currentUserId);
      int currentScore = ((data?['upvotes'] ?? 0) - (data?['downvotes'] ?? 0));

      final batch = FirebaseFirestore.instance.batch();

      if (voteType == 'upvote') {
        if (currentHasUpvoted) {
          batch.update(targetRef, {
            'upvotes': FieldValue.increment(-1),
            'upvotedBy': FieldValue.arrayRemove([currentUserId]),
          });
          batch.delete(userVoteRef);
          onUpdate(currentScore - 1, false, currentHasDownvoted);
        } else {
          if (currentHasDownvoted) {
            batch.update(targetRef, {
              'downvotes': FieldValue.increment(-1),
              'downvotedBy': FieldValue.arrayRemove([currentUserId]),
              'upvotes': FieldValue.increment(1),
              'upvotedBy': FieldValue.arrayUnion([currentUserId]),
            });
            onUpdate(currentScore + 2, true, false);
          } else {
            batch.update(targetRef, {
              'upvotes': FieldValue.increment(1),
              'upvotedBy': FieldValue.arrayUnion([currentUserId]),
            });
            onUpdate(currentScore + 1, true, false);
          }
          batch.set(userVoteRef, {
            'type': 'upvote',
            'userId': currentUserId,
            'targetId': commentId ?? widget.postId,
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } else if (voteType == 'downvote') {
        if (currentHasDownvoted) {
          batch.update(targetRef, {
            'downvotes': FieldValue.increment(-1),
            'downvotedBy': FieldValue.arrayRemove([currentUserId]),
          });
          batch.delete(userVoteRef);
          onUpdate(currentScore + 1, currentHasUpvoted, false);
        } else {
          if (currentHasUpvoted) {
            batch.update(targetRef, {
              'upvotes': FieldValue.increment(-1),
              'upvotedBy': FieldValue.arrayRemove([currentUserId]),
              'downvotes': FieldValue.increment(1),
              'downvotedBy': FieldValue.arrayUnion([currentUserId]),
            });
            onUpdate(currentScore - 2, false, true);
          } else {
            batch.update(targetRef, {
              'downvotes': FieldValue.increment(1),
              'downvotedBy': FieldValue.arrayUnion([currentUserId]),
            });
            onUpdate(currentScore - 1, false, true);
          }
          batch.set(userVoteRef, {
            'type': 'downvote',
            'userId': currentUserId,
            'targetId': commentId ?? widget.postId,
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
      await batch.commit();
    } catch (e) {
      print('Error updating vote: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update vote: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Toggles the bookmark status for the post
  Future<void> toggleBookmark() async {
    if (currentUserId.isEmpty || isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to bookmark posts')));
      return;
    }
    setState(() => isLoading = true);
    try {
      final bookmarkRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('bookmarks')
          .doc(widget.postId);
      final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);

      if (isBookmarked) {
        await bookmarkRef.delete();
        await postRef.update({
          'bookmarkedBy': FieldValue.arrayRemove([currentUserId]),
        });
        if (mounted) {
          setState(() => isBookmarked = false);
        }
      } else {
        await bookmarkRef.set({
          'postId': widget.postId,
          'userId': currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
          'postData': widget.postData,
        });
        await postRef.update({
          'bookmarkedBy': FieldValue.arrayUnion([currentUserId]),
        });
        if (mounted) {
          setState(() => isBookmarked = true);
        }
      }
    } catch (e) {
      print('Error toggling bookmark: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update bookmark: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Shares the post content
  void shareContent(String content) {
    Share.share('$content\nShared from MyApp');
  }

  // Displays the options menu for a post, comment, or reply
  Future<void> showOptionsMenu(BuildContext context, {String? commentId, String? replyId}) async {
    bool isCurrentUserContent;
    String contentText;

    if (commentId != null) {
      // For comments or replies
      if (replyId != null) {
        // Reply
        final replyDoc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(commentId)
            .collection('replies')
            .doc(replyId)
            .get();
        isCurrentUserContent = replyDoc.exists && (replyDoc.data()?['userId'] == currentUserId);
        contentText = replyDoc.data()?['text'] ?? '';
      } else {
        // Comment
        final commentDoc = await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(commentId)
            .get();
        isCurrentUserContent = commentDoc.exists && (commentDoc.data()?['userId'] == currentUserId);
        contentText = commentDoc.data()?['text'] ?? '';
      }
    } else {
      // Post
      isCurrentUserContent = widget.postData['userId'] == currentUserId;
      contentText = widget.postData['content'] ?? '';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentUserContent)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    if (commentId != null) {
                      if (replyId != null) {
                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(widget.postId)
                            .collection('comments')
                            .doc(commentId)
                            .collection('replies')
                            .doc(replyId)
                            .delete();
                      } else {
                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(widget.postId)
                            .collection('comments')
                            .doc(commentId)
                            .delete();
                      }
                    } else {
                      await FirebaseFirestore.instance.collection('posts').doc(widget.postId).delete();
                      Navigator.pop(context);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully')));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Share', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                shareContent(contentText);
              },
            ),
            if (!isCurrentUserContent)
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.orange),
                title: const Text('Report', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _reportContent(commentId: commentId, replyId: replyId);
                },
              ),
          ],
        ),
      ),
    );
  }

  // Displays the report dialog for content
  void _reportContent({String? commentId, String? replyId}) {
    final TextEditingController reportController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text('Report Content', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please tell us why you are reporting this content:', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              TextField(
                controller: reportController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter reason for report...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey[700]!)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final reason = reportController.text.trim();
                if (reason.isNotEmpty) {
                  _submitReport(reason, commentId: commentId, replyId: replyId);
                  Navigator.pop(context);
                }
              },
              child: const Text('Submit Report'),
            ),
          ],
        );
      },
    );
  }

  // Submits a report to the 'reports' collection
  Future<void> _submitReport(String reason, {String? commentId, String? replyId}) async {
    if (currentUserId.isEmpty) return;
    try {
      String contentType = 'post';
      String contentId = widget.postId;
      String? contentOwner = widget.postData['userId'];
      String? contentText = widget.postData['content'];

      if (commentId != null) {
        contentType = replyId != null ? 'reply' : 'comment';
        contentId = replyId ?? commentId;
        final docRef = replyId != null
            ? FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(commentId)
            .collection('replies')
            .doc(replyId)
            : FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(commentId);
        final doc = await docRef.get();
        final data = doc.data() as Map<String, dynamic>?;
        contentOwner = data?['userId'];
        contentText = data?['text'];
      }

      await FirebaseFirestore.instance.collection('reports').add({
        'contentType': contentType,
        'contentId': contentId,
        'contentText': contentText,
        'reportedBy': currentUserId,
        'contentOwner': contentOwner,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted. Thank you for your feedback.')));
    } catch (e) {
      print('Error submitting report: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit report. Please try again later.')));
    }
  }

  // Submits a comment or reply to the database
  Future<void> _submitComment() async {
    final String? commentText = _commentController.text.trim();
    if (commentText == null || commentText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment cannot be empty')));
      return;
    }

    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to comment')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userDataSafe = userData ?? {'name': 'Anonymous', 'profileImageUrl': ''};
      String userName = userDataSafe['name'] ?? 'Anonymous';
      // Do not save userProfileImageUrl to the database

      if (isAnonymousComment) {
        userName = 'Anonymous_${DateTime.now().millisecondsSinceEpoch}';
      }

      if (replyingToCommentId != null) {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(replyingToCommentId)
            .collection('replies')
            .add({
          'text': commentText,
          'userId': currentUserId,
          'userName': userName,
          'createdAt': FieldValue.serverTimestamp(),
          'isAnonymous': isAnonymousComment,
          'upvotes': 0,
          'downvotes': 0,
          'upvotedBy': [],
          'downvotedBy': [],
        });
      } else {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .add({
          'text': commentText,
          'userId': currentUserId,
          'userName': userName,
          'createdAt': FieldValue.serverTimestamp(),
          'isAnonymous': isAnonymousComment,
          'upvotes': 0,
          'downvotes': 0,
          'upvotedBy': [],
          'downvotedBy': [],
        });
      }

      _commentController.clear();
      setState(() => replyingToCommentId = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment submitted successfully')));
    } catch (e) {
      print('Error submitting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit comment: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // Launches a URL in an external application
  Future<void> _launchURL(String url) async {
    String secureUrl = url.trim();
    if (!secureUrl.startsWith('http://') && !secureUrl.startsWith('https://')) {
      secureUrl = 'https://$secureUrl';
    }
    secureUrl = secureUrl.startsWith('http:') ? secureUrl.replaceFirst('http:', 'https:') : secureUrl;

    final Uri? uri = Uri.tryParse(secureUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid URL format')));
      return;
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot launch URL: $secureUrl')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error launching URL: $e')));
    }
  }

  // Navigates to the reply screen
  void _navigateToReplyScreen(String commentId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReplyScreen(
          postId: widget.postId,
          commentId: commentId,
          currentUserId: currentUserId,
          userData: userData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('PostDetailScreen build called for postId: ${widget.postId}');
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
    padding = screenWidth * 0.05;

    String timeAgo = widget.postData['createdAt'] != null
        ? timeago.format((widget.postData['createdAt'] as Timestamp).toDate())
        : '';
    bool isAnonymous = widget.postData['isAnonymous'] ?? false;
    String displayName = isAnonymous
        ? widget.postData['uniqueName'] ?? 'Anonymous'
        : (widget.postData['userName'] ?? 'Unknown User');
    String userProfileImage = isAnonymous ? '' : (widget.postData['userProfileImageUrl'] ?? '');
    final poll = widget.postData['poll'] as Map<String, dynamic>?;
    final link = widget.postData['link'] as String?;
    final images = widget.postData['images'] as List<dynamic>?;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Post on Medial', style: TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
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
                            SizedBox(width: padding * 0.3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        timeAgo,
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            _buildHubImage(padding),
                          ],
                        ),
                        SizedBox(height: padding),
                        Text(
                          widget.postData['content'] ?? 'No content',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                        if (images != null && images.isNotEmpty) ...[
                          SizedBox(height: padding),
                          SizedBox(
                            height: 150,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: images.length,
                              itemBuilder: (context, index) {
                                final imageUrl = images[index] as String;
                                return Padding(
                                  padding: EdgeInsets.only(right: padding * 0.5),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: imageUrl,
                                      width: 200,
                                      height: 150,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 200,
                                        height: 150,
                                        color: Colors.grey[800],
                                        child: const Center(child: CircularProgressIndicator()),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        width: 200,
                                        height: 150,
                                        color: Colors.grey[800],
                                        child: const Icon(Icons.broken_image, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        SizedBox(height: padding),
                        if (poll != null) ...[
                          SizedBox(height: padding),
                          _buildPoll(poll, padding, screenWidth),
                          SizedBox(height: padding * 0.5),
                          _buildPollVoteCount(poll),
                        ],
                        if (link != null) ...[SizedBox(height: padding), _buildLink(link, padding)],
                        SizedBox(height: padding),
                        Text(
                          '${(widget.postData['createdAt'] as Timestamp).toDate().hour % 12}:${(widget.postData['createdAt'] as Timestamp).toDate().minute.toString().padLeft(2, '0')} ${(widget.postData['createdAt'] as Timestamp).toDate().hour >= 12 ? 'pm' : 'am'} • ${(widget.postData['createdAt'] as Timestamp).toDate().day} ${(widget.postData['createdAt'] as Timestamp).toDate().month == 4 ? 'Apr' : ''} ${(widget.postData['createdAt'] as Timestamp).toDate().year.toString().substring(2)}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        SizedBox(height: padding),
                        _buildInteractionBar(),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.grey, height: 1),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.postId)
                        .collection('comments')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      print('StreamBuilder for comments rebuilding - ConnectionState: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, Docs: ${snapshot.data?.docs.length}');
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading comments: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('No comments yet. Be the first to comment!', style: TextStyle(color: Colors.white70)),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          String timeAgo = data['createdAt'] != null
                              ? timeago.format((data['createdAt'] as Timestamp).toDate())
                              : '';
                          return CommentItem(
                            key: ValueKey(doc.id), // Unique key to prevent unnecessary rebuilds
                            commentData: data,
                            commentId: doc.id,
                            postId: widget.postId,
                            timeAgo: timeAgo,
                            onReply: _navigateToReplyScreen,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Fixed comment input section at the bottom
          Container(
            padding: EdgeInsets.all(padding),
            color: Colors.black,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (currentUserId.isNotEmpty) {
                      setState(() => isAnonymousComment = !isAnonymousComment);
                    }
                  },
                  child: isAnonymousComment || userData == null || (userData!['profileImageUrl'] as String?)!.isEmpty
                      ? Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: Colors.grey[800], shape: BoxShape.circle),
                    child: const Icon(Icons.person, color: Colors.white),
                  )
                      : ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: userData!['profileImageUrl'] as String,
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
                  ),
                ),
                SizedBox(width: padding * 0.3),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: replyingToCommentId != null
                          ? 'Replying to comment...'
                          : (isAnonymousComment ? 'Enter anonymous reply...' : 'Enter your reply...'),
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: padding * 0.4, vertical: padding * 0.3),
                    ),
                    maxLines: 1,
                  ),
                ),
                SizedBox(width: padding * 0.3),
                InkWell(
                  onTap: _isSubmitting ? null : _submitComment,
                  child: Icon(Icons.send, color: _isSubmitting ? Colors.grey[600] : Colors.grey, size: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds the hub image widget
  Widget _buildHubImage(double padding) {
    final hubDataSafe = hubData ?? {};
    if (hubDataSafe.isEmpty || (hubDataSafe['hubImage'] as String?)!.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: const Icon(Icons.group, color: Colors.white, size: 20),
      );
    }
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Navigating to ${hubDataSafe['hubName']} hub')));
      },
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: hubDataSafe['hubImage'] as String,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 40,
            height: 40,
            color: Colors.grey[800],
            child: const Icon(Icons.group, color: Colors.white, size: 20),
          ),
          errorWidget: (context, url, error) => Container(
            width: 40,
            height: 40,
            color: Colors.grey[800],
            child: const Icon(Icons.group, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  // Builds the poll widget
  Widget _buildPoll(Map<String, dynamic> poll, double padding, double screenWidth) {
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
          padding: EdgeInsets.symmetric(vertical: padding * 0.2),
          child: GestureDetector(
            onTap: isSelected || userVote != null || isLoading ? null : () => castPollVote(option),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: padding * 0.25, horizontal: padding * 0.3),
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
                          style: TextStyle(color: isSelected ? Colors.purpleAccent : Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: padding * 0.1),
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
                              duration: const Duration(milliseconds: 300),
                              height: 8,
                              width: screenWidth * (percentage / 100) * 0.6,
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.purpleAccent : Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: padding * 0.1),
                        Text(
                          '$voteCount votes (${percentage}%)',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
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

  // Builds the poll vote count display
  Widget _buildPollVoteCount(Map<String, dynamic> poll) {
    final votesMap = poll['votes'] as Map<String, dynamic>;
    final votes = List<int>.generate(poll['options'].length, (index) => votesMap[index.toString()] as int? ?? 0);
    final totalVotes = votes.fold(0, (sum, vote) => sum + vote);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (userVote != null)
          Text('You have voted for $userVote', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
        Text('Votes: $totalVotes', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // Builds the link widget
  Widget _buildLink(String link, double padding) {
    return InkWell(
      onTap: () => _launchURL(link),
      child: Container(
        padding: EdgeInsets.all(padding * 0.3),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            const Icon(Icons.link, color: Colors.white, size: 20),
            SizedBox(width: padding * 0.2),
            Expanded(
              child: Text(
                link,
                style: const TextStyle(color: Colors.lightBlue, fontSize: 16, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the interaction bar with vote and bookmark options
  Widget _buildInteractionBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: isLoading ? null : () => updateVote('upvote', onUpdate: (newScore, newHasUpvoted, newHasDownvoted) {
                setState(() {
                  score = newScore;
                  hasUpvoted = newHasUpvoted;
                  hasDownvoted = newHasDownvoted;
                });
              }),
              icon: Icon(Icons.arrow_upward, color: hasUpvoted ? Colors.green : Colors.grey, size: 24),
            ),
            Text('$score', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            IconButton(
              onPressed: isLoading ? null : () => updateVote('downvote', onUpdate: (newScore, newHasUpvoted, newHasDownvoted) {
                setState(() {
                  score = newScore;
                  hasUpvoted = newHasUpvoted;
                  hasDownvoted = newHasDownvoted;
                });
              }),
              icon: Icon(Icons.arrow_downward, color: hasDownvoted ? Colors.red : Colors.grey, size: 24),
            ),
          ],
        ),
        Row(
          children: [
            InkWell(
              onTap: isLoading ? null : toggleBookmark,
              child: Row(
                children: [
                  Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: isBookmarked ? Colors.blue : Colors.grey, size: 24),
                  SizedBox(width: padding * 0.1),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text('0', style: TextStyle(color: Colors.grey, fontSize: 14));
                      }
                      final data = snapshot.data?.data() as Map<String, dynamic>?;
                      final bookmarkCount = (data != null && data.containsKey('bookmarkedBy') && data['bookmarkedBy'] != null)
                          ? (data['bookmarkedBy'] as List<dynamic>).length
                          : 0;
                      return Text('$bookmarkCount', style: const TextStyle(color: Colors.grey, fontSize: 14));
                    },
                  ),
                ],
              ),
            ),
            SizedBox(width: padding * 0.4),
            GestureDetector(
              onTap: () => shareContent(widget.postData['content'] ?? 'Check out this post!'),
              child: Row(
                children: [
                  const Icon(Icons.share, color: Colors.grey, size: 24),
                  SizedBox(width: padding * 0.1),
                  const Text('0', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
            SizedBox(width: padding * 0.4),
            IconButton(
              onPressed: () => showOptionsMenu(context),
              icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 24),
            ),
          ],
        ),
      ],
    );
  }
}

// Widget for displaying a single comment or reply
class CommentItem extends StatefulWidget {
  final Map<String, dynamic> commentData; // Data of the comment or reply
  final String commentId; // Unique ID of the comment
  final String postId; // ID of the post the comment belongs to
  final String timeAgo; // Formatted timestamp
  final Function(String) onReply; // Callback for replying to the comment
  final int level; // Nesting level for replies (for indentation)

  const CommentItem({
    Key? key,
    required this.commentData,
    required this.commentId,
    required this.postId,
    required this.timeAgo,
    required this.onReply,
    this.level = 0,
  }) : super(key: key);

  @override
  _CommentItemState createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  bool _showReplies = false; // Controls visibility of replies
  late int score; // Score of the comment or reply (upvotes - downvotes)
  late bool hasUpvoted; // Tracks if the user has upvoted
  late bool hasDownvoted; // Tracks if the user has downvoted
  bool isLoading = false; // Loading state for async operations

  @override
  void initState() {
    super.initState();
    final data = widget.commentData as Map<String, dynamic>;
    score = ((data['upvotes'] ?? 0) - (data['downvotes'] ?? 0));
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    hasUpvoted = (data['upvotedBy'] as List<dynamic>?)?.contains(currentUserId) ?? false;
    hasDownvoted = (data['downvotedBy'] as List<dynamic>?)?.contains(currentUserId) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    print('CommentItem build called for commentId: ${widget.commentId}');
    final padding = MediaQuery.of(context).size.width * 0.05;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchCommentUserData(widget.commentData['userId']),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); // Return an empty widget while loading
        }
        if (userSnapshot.hasError || !userSnapshot.hasData) {
          return const SizedBox.shrink(); // Return an empty widget on error
        }

        final userData = userSnapshot.data!;
        String displayName = widget.commentData['isAnonymous'] == true
            ? widget.commentData['userName'] ?? 'Anonymous'
            : userData['name'] ?? 'Unknown User';
        String userProfileImage = widget.commentData['isAnonymous'] == true
            ? ''
            : userData['profileImageUrl'] ?? '';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: widget.level * 20.0, top: 8.0, bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              widget.timeAgo,
                              style: const TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.commentData['text'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Reply count and toggle
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('posts')
                                  .doc(widget.postId)
                                  .collection('comments')
                                  .doc(widget.commentId)
                                  .collection('replies')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const SizedBox.shrink();
                                final replyCount = snapshot.data!.docs.length;
                                if (replyCount == 0) {
                                  return GestureDetector(
                                    onTap: () => widget.onReply(widget.commentId),
                                    child: const Padding(
                                      padding: EdgeInsets.only(right: 16.0),
                                      child: Text(
                                        'Reply',
                                        style: TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    ),
                                  );
                                }
                                return GestureDetector(
                                  onTap: () {
                                    print('Toggling replies for commentId: ${widget.commentId}, showReplies: $_showReplies -> ${!_showReplies}');
                                    setState(() => _showReplies = !_showReplies);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16.0),
                                    child: Text(
                                      '$replyCount repl${replyCount == 1 ? 'y' : 'ies'}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Upvote button and count
                            IconButton(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                print('Upvote pressed for commentId: ${widget.commentId}');
                                final state = context.findAncestorStateOfType<_PostDetailScreenState>();
                                if (state != null) {
                                  state.updateVote(
                                    'upvote',
                                    commentId: widget.commentId,
                                    onUpdate: (newScore, newHasUpvoted, newHasDownvoted) {
                                      if (mounted) {
                                        setState(() {
                                          score = newScore;
                                          hasUpvoted = newHasUpvoted;
                                          hasDownvoted = newHasDownvoted;
                                        });
                                      }
                                    },
                                  );
                                }
                              },
                              icon: Icon(
                                Icons.arrow_upward,
                                color: hasUpvoted ? Colors.green : Colors.grey,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text(
                                '$score',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                            // Downvote button
                            IconButton(
                              onPressed: isLoading
                                  ? null
                                  : () {
                                print('Downvote pressed for commentId: ${widget.commentId}');
                                final state = context.findAncestorStateOfType<_PostDetailScreenState>();
                                if (state != null) {
                                  state.updateVote(
                                    'downvote',
                                    commentId: widget.commentId,
                                    onUpdate: (newScore, newHasUpvoted, newHasDownvoted) {
                                      if (mounted) {
                                        setState(() {
                                          score = newScore;
                                          hasUpvoted = newHasUpvoted;
                                          hasDownvoted = newHasDownvoted;
                                        });
                                      }
                                    },
                                  );
                                }
                              },
                              icon: Icon(
                                Icons.arrow_downward,
                                color: hasDownvoted ? Colors.red : Colors.grey,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            // Options button
                            IconButton(
                              onPressed: () {
                                final state = context.findAncestorStateOfType<_PostDetailScreenState>();
                                if (state != null) {
                                  state.showOptionsMenu(context, commentId: widget.commentId);
                                }
                              },
                              icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_showReplies)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .collection('comments')
                    .doc(widget.commentId)
                    .collection('replies')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  print('StreamBuilder for replies rebuilding for commentId: ${widget.commentId} - ConnectionState: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, Docs: ${snapshot.data?.docs.length}');
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(left: 20.0),
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: Text('Error loading replies: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      String timeAgo = data['createdAt'] != null
                          ? timeago.format((data['createdAt'] as Timestamp).toDate())
                          : '';
                      return ReplyItem(
                        key: ValueKey(doc.id), // Unique key to prevent unnecessary rebuilds
                        replyData: data,
                        replyId: doc.id,
                        commentId: widget.commentId,
                        postId: widget.postId,
                        timeAgo: timeAgo,
                        onReply: widget.onReply,
                      );
                    },
                  );
                },
              ),
            const Divider(color: Colors.grey, height: 1, thickness: 0.5), // Thin line below the comment
          ],
        );
      },
    );
  }

  // Fetches user data for a comment from the 'users' collection
  Future<Map<String, dynamic>> _fetchCommentUserData(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return {'name': 'Anonymous', 'profileImageUrl': ''};
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        return userDoc.data()! as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching comment user data: $e');
    }
    return {'name': 'Anonymous', 'profileImageUrl': ''};
  }
}

// Widget for displaying a single reply
class ReplyItem extends StatefulWidget {
  final Map<String, dynamic> replyData; // Data of the reply
  final String replyId; // Unique ID of the reply
  final String commentId; // ID of the parent comment
  final String postId; // ID of the post
  final String timeAgo; // Formatted timestamp
  final Function(String) onReply; // Callback for replying to the reply

  const ReplyItem({
    Key? key,
    required this.replyData,
    required this.replyId,
    required this.commentId,
    required this.postId,
    required this.timeAgo,
    required this.onReply,
  }) : super(key: key);

  @override
  _ReplyItemState createState() => _ReplyItemState();
}

class _ReplyItemState extends State<ReplyItem> {
  late int score; // Score of the reply (upvotes - downvotes)
  late bool hasUpvoted; // Tracks if the user has upvoted
  late bool hasDownvoted; // Tracks if the user has downvoted
  bool isLoading = false; // Loading state for async operations

  @override
  void initState() {
    super.initState();
    final data = widget.replyData as Map<String, dynamic>;
    score = ((data['upvotes'] ?? 0) - (data['downvotes'] ?? 0));
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    hasUpvoted = (data['upvotedBy'] as List<dynamic>?)?.contains(currentUserId) ?? false;
    hasDownvoted = (data['downvotedBy'] as List<dynamic>?)?.contains(currentUserId) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    print('ReplyItem build called for replyId: ${widget.replyId}');
    final padding = MediaQuery.of(context).size.width * 0.05;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchReplyUserData(widget.replyData['userId']),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink(); // Return an empty widget while loading
        }
        if (userSnapshot.hasError || !userSnapshot.hasData) {
          return const SizedBox.shrink(); // Return an empty widget on error
        }

        final userData = userSnapshot.data!;
        String displayName = widget.replyData['isAnonymous'] == true
            ? widget.replyData['userName'] ?? 'Anonymous'
            : userData['name'] ?? 'Unknown User';
        String userProfileImage = widget.replyData['isAnonymous'] == true
            ? ''
            : userData['profileImageUrl'] ?? '';

        return Padding(
          padding: const EdgeInsets.only(left: 20.0, top: 8.0, bottom: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.timeAgo,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.replyData['text'] ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => widget.onReply(widget.commentId),
                          child: const Padding(
                            padding: EdgeInsets.only(right: 16.0),
                            child: Text(
                              'Reply',
                              style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: isLoading
                              ? null
                              : () {
                            print('Upvote pressed for replyId: ${widget.replyId}');
                            final state = context.findAncestorStateOfType<_PostDetailScreenState>();
                            if (state != null) {
                              state.updateVote(
                                'upvote',
                                commentId: widget.commentId,
                                replyId: widget.replyId,
                                onUpdate: (newScore, newHasUpvoted, newHasDownvoted) {
                                  if (mounted) {
                                    setState(() {
                                      score = newScore;
                                      hasUpvoted = newHasUpvoted;
                                      hasDownvoted = newHasDownvoted;
                                    });
                                  }
                                },
                              );
                            }
                          },
                          icon: Icon(
                            Icons.arrow_upward,
                            color: hasUpvoted ? Colors.green : Colors.grey,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(
                            '$score',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                        IconButton(
                          onPressed: isLoading
                              ? null
                              : () {
                            print('Downvote pressed for replyId: ${widget.replyId}');
                            final state = context.findAncestorStateOfType<_PostDetailScreenState>();
                            if (state != null) {
                              state.updateVote(
                                'downvote',
                                commentId: widget.commentId,
                                replyId: widget.replyId,
                                onUpdate: (newScore, newHasUpvoted, newHasDownvoted) {
                                  if (mounted) {
                                    setState(() {
                                      score = newScore;
                                      hasUpvoted = newHasUpvoted;
                                      hasDownvoted = newHasDownvoted;
                                    });
                                  }
                                },
                              );
                            }
                          },
                          icon: Icon(
                            Icons.arrow_downward,
                            color: hasDownvoted ? Colors.red : Colors.grey,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          onPressed: () {
                            final state = context.findAncestorStateOfType<_PostDetailScreenState>();
                            if (state != null) {
                              state.showOptionsMenu(
                                context,
                                commentId: widget.commentId,
                                replyId: widget.replyId,
                              );
                            }
                          },
                          icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Fetches user data for a reply from the 'users' collection
  Future<Map<String, dynamic>> _fetchReplyUserData(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return {'name': 'Anonymous', 'profileImageUrl': ''};
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        return userDoc.data()! as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching reply user data: $e');
    }
    return {'name': 'Anonymous', 'profileImageUrl': ''};
  }
}

// ReplyScreen for composing replies
class ReplyScreen extends StatefulWidget {
  final String postId;
  final String commentId;
  final String currentUserId;
  final Map<String, dynamic>? userData;

  const ReplyScreen({
    Key? key,
    required this.postId,
    required this.commentId,
    required this.currentUserId,
    required this.userData,
  }) : super(key: key);

  @override
  _ReplyScreenState createState() => _ReplyScreenState();
}

class _ReplyScreenState extends State<ReplyScreen> {
  final TextEditingController _replyController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).size.width * 0.05;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Reply', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter your reply...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[900],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: padding * 0.4, vertical: padding * 0.3),
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
              ),
            ),
            SizedBox(height: padding),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('Submit Reply', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReply() async {
    final String? replyText = _replyController.text.trim();
    if (replyText == null || replyText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply cannot be empty')));
      return;
    }

    if (widget.currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to reply')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final userDataSafe = widget.userData ?? {'name': 'Anonymous', 'profileImageUrl': ''};
      String userName = userDataSafe['name'] ?? 'Anonymous';

      if (widget.userData == null || widget.userData!['profileImageUrl'].isEmpty) {
        userName = 'Anonymous_${DateTime.now().millisecondsSinceEpoch}';
      }

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(widget.commentId)
          .collection('replies')
          .add({
        'text': replyText,
        'userId': widget.currentUserId,
        'userName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'isAnonymous': widget.userData == null || widget.userData!['profileImageUrl'].isEmpty,
        'upvotes': 0,
        'downvotes': 0,
        'upvotedBy': [],
        'downvotedBy': [],
      });

      _replyController.clear();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply submitted successfully')));
    } catch (e) {
      print('Error submitting reply: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit reply: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}