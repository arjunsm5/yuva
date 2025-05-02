import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;


import 'my_feed_post_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const PostDetailScreen({
    Key? key,
    required this.postId,
    required this.postData,
  }) : super(key: key);

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  late String currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Submit a new comment
  Future<void> _submitComment() async {
    final String commentText = _commentController.text.trim();
    if (commentText.isEmpty) return;

    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to comment')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get current user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      final userName = userDoc.data()?['name'] ?? 'Anonymous';
      final userProfileUrl = userDoc.data()?['profileImageUrl'] ?? '';

      // Add comment to Firestore
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'text': commentText,
        'userId': currentUserId,
        'userName': userName,
        'userProfileImageUrl': userProfileUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
      });

      // Clear the input field
      _commentController.clear();

    } catch (e) {
      print('Error submitting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit comment: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Post Details'),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Display the original post
          PostItem(postData: widget.postData, postId: widget.postId),

          const Divider(color: Colors.grey, height: 1),

          // Comments section
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading comments: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                // Build list of comments
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    // Format timestamp
                    String timeAgo = '';
                    if (data['createdAt'] != null) {
                      final Timestamp timestamp = data['createdAt'];
                      final DateTime dateTime = timestamp.toDate();
                      timeAgo = timeago.format(dateTime);
                    }

                    return CommentItem(
                      commentData: data,
                      commentId: doc.id,
                      postId: widget.postId,
                      timeAgo: timeAgo,
                    );
                  },
                );
              },
            ),
          ),

          // Comment input field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _isSubmitting ? null : _submitComment,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.send,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget for displaying a single comment
class CommentItem extends StatefulWidget {
  final Map<String, dynamic> commentData;
  final String commentId;
  final String postId;
  final String timeAgo;

  const CommentItem({
    Key? key,
    required this.commentData,
    required this.commentId,
    required this.postId,
    required this.timeAgo,
  }) : super(key: key);

  @override
  _CommentItemState createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  bool isLiked = false;
  int likeCount = 0;
  late String currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    likeCount = widget.commentData['likes'] ?? 0;
    _checkIfLiked();
  }

  // Check if the current user has liked this comment
  Future<void> _checkIfLiked() async {
    if (currentUserId.isEmpty) return;

    try {
      final likeDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(widget.commentId)
          .collection('likes')
          .doc(currentUserId)
          .get();

      if (mounted) {
        setState(() {
          isLiked = likeDoc.exists;
        });
      }
    } catch (e) {
      print('Error checking if comment is liked: $e');
    }
  }

  // Toggle like status
  Future<void> _toggleLike() async {
    if (currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like comments')),
      );
      return;
    }

    final commentRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .doc(widget.commentId);

    final likeRef = commentRef.collection('likes').doc(currentUserId);

    try {
      if (isLiked) {
        // Remove like
        await likeRef.delete();
        await commentRef.update({'likes': FieldValue.increment(-1)});

        if (mounted) {
          setState(() {
            isLiked = false;
            likeCount--;
          });
        }
      } else {
        // Add like
        await likeRef.set({
          'timestamp': FieldValue.serverTimestamp(),
        });
        await commentRef.update({'likes': FieldValue.increment(1)});

        if (mounted) {
          setState(() {
            isLiked = true;
            likeCount++;
          });
        }
      }
    } catch (e) {
      print('Error toggling comment like: $e');
    }
  }

  // Show options menu for comment (delete/report)
  void _showCommentOptions() {
    final bool isCurrentUserComment = widget.commentData['userId'] == currentUserId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCurrentUserComment)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete comment',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteComment();
                  },
                ),
              if (!isCurrentUserComment)
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.orange),
                  title: const Text(
                    'Report comment',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _reportComment();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.content_copy, color: Colors.white),
                title: const Text(
                  'Copy text',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final commentText = widget.commentData['text'] ?? '';
                  if (commentText.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Comment copied to clipboard')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Delete comment
  Future<void> _deleteComment() async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(widget.commentId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment deleted')),
      );
    } catch (e) {
      print('Error deleting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete comment: $e')),
      );
    }
  }

  // Report comment
  void _reportComment() {
    final TextEditingController reportController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Report Comment',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please tell us why you are reporting this comment:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reportController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter reason for report...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final reason = reportController.text.trim();
                if (reason.isNotEmpty) {
                  _submitCommentReport(reason);
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

  // Submit comment report
  Future<void> _submitCommentReport(String reason) async {
    if (currentUserId.isEmpty) return;

    try {
      await FirebaseFirestore.instance.collection('commentReports').add({
        'postId': widget.postId,
        'commentId': widget.commentId,
        'commentText': widget.commentData['text'],
        'reportedBy': currentUserId,
        'commentOwner': widget.commentData['userId'],
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you for your feedback.')),
      );
    } catch (e) {
      print('Error submitting comment report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to submit report. Please try again later.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.commentData['userProfileImageUrl'] != null &&
              widget.commentData['userProfileImageUrl'].isNotEmpty
              ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: widget.commentData['userProfileImageUrl'],
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 36,
                height: 36,
                color: Colors.grey[800],
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
              errorWidget: (context, url, error) => Container(
                width: 36,
                height: 36,
                color: Colors.grey[800],
                child: const Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ),
          )
              : Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
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
                      widget.commentData['userName'] ?? 'Anonymous',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.timeAgo,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.commentData['text'] ?? '',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleLike,
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.grey,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$likeCount',
                            style: TextStyle(color: Colors.grey[400], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reply functionality coming soon')),
                        );
                      },
                      child: Text(
                        'Reply',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.more_horiz,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                      onPressed: _showCommentOptions,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
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
}