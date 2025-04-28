import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FullScreenVideoPlayer extends StatefulWidget {
  final String challengeId;
  final String? submissionId;

  const FullScreenVideoPlayer({
    Key? key,
    required this.challengeId,
    this.submissionId,
  }) : super(key: key);

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  List<Submission> _submissions = [];
  bool _isLoading = true;
  String? _errorMessage;
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _fetchSubmissions();

    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
  }

  Future<void> _fetchSubmissions() async {
    try {
      print('Fetching submissions for challengeId: ${widget.challengeId}');
      final submissionsSnapshot = await FirebaseFirestore.instance
          .collection('challenge_media')
          .where('challengeId', isEqualTo: widget.challengeId)
          .orderBy('createdAt', descending: true)
          .get();

      print('Found ${submissionsSnapshot.docs.length} submissions');
      if (submissionsSnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No submissions found for this challenge';
        });
        return;
      }

      List<Submission> submissions = [];
      for (var doc in submissionsSnapshot.docs) {
        final submissionId = doc.id;
        final mediaSnapshot = await doc.reference.collection('media').orderBy('order').get();

        if (mediaSnapshot.docs.isNotEmpty) {
          List<MediaItem> mediaItems = mediaSnapshot.docs.map((mediaDoc) {
            final mediaData = mediaDoc.data();
            return MediaItem(
              mediaType: mediaData['mediaType'] ?? 'image',
              mediaUrl: mediaData['mediaUrl'],
              thumbnailUrl: mediaData['thumbnailUrl'],
            );
          }).toList();

          final userId = doc['userId'] as String? ?? 'unknown';
          String username = 'Unknown User';
          String profileImageUrl = 'https://via.placeholder.com/50';
          try {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
            if (userDoc.exists) {
              username = userDoc['username'] ?? 'Unknown User';
              profileImageUrl = userDoc['profileImageUrl'] ?? 'https://via.placeholder.com/50';
            }
          } catch (e) {
            print('Error fetching user data for userId $userId: $e');
          }

          submissions.add(Submission(
            id: submissionId,
            userId: userId,
            username: username,
            profileImageUrl: profileImageUrl,
            caption: doc['caption'] ?? 'No caption',
            challengeTitle: doc['challengeTitle'] ?? 'Unknown Challenge',
            mediaItems: mediaItems,
            createdAt: (doc['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            likes: 0,
            comments: 0,
            shares: 0,
            isLiked: false,
          ));
        }
      }

      if (submissions.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No media submissions found for this challenge';
        });
        return;
      }

      setState(() {
        _submissions = submissions;
        _isLoading = false;
      });

      if (widget.submissionId != null) {
        final initialIndex = submissions.indexWhere((s) => s.id == widget.submissionId);
        if (initialIndex != -1) {
          _pageController.jumpToPage(initialIndex);
        }
      }
    } catch (e) {
      print('Error fetching submissions: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching submissions: $e';
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : _submissions.isEmpty
              ? Center(
            child: Text(
              _errorMessage ?? 'No submissions yet!',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
            ),
          )
              : PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _submissions.length,
            itemBuilder: (context, index) {
              return _buildSubmission(_submissions[index], index);
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmission(Submission submission, int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Media content
        PageView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: submission.mediaItems.length,
          itemBuilder: (context, mediaIndex) {
            final mediaItem = submission.mediaItems[mediaIndex];
            if (mediaItem.mediaType == 'image') {
              return CachedNetworkImage(
                imageUrl: mediaItem.mediaUrl ?? '',
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
                errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.white)),
              );
            } else if (mediaItem.mediaType == 'video') {
              return VideoPlayerWidget(
                videoUrl: mediaItem.mediaUrl ?? '',
                thumbnailUrl: mediaItem.thumbnailUrl,
                isVisible: _currentPage == index,
              );
            }
            return const Center(child: Text('Unsupported media type', style: TextStyle(color: Colors.white)));
          },
        ),
        // Challenge Title
        Positioned(
          top: 80,
          left: 16,
          child: Text(
            submission.challengeTitle,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        // Username, Caption, and Hashtag
        Positioned(
          bottom: 80,
          left: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                submission.username,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                submission.caption,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '#${submission.challengeTitle.replaceAll(' ', '')}',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        // Like, Comment, Share Buttons
        Positioned(
          right: 16,
          bottom: 80,
          child: Column(
            children: [
              IconButton(
                icon: Icon(
                  Icons.favorite,
                  color: submission.isLiked ? Colors.red : Colors.white,
                  size: 40,
                ),
                onPressed: () {
                  setState(() {
                    submission.isLiked = !submission.isLiked;
                    if (submission.isLiked) {
                      submission.likes++;
                    } else {
                      submission.likes--;
                    }
                  });
                },
              ),
              Text(
                submission.likes.toString(),
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 16),
              IconButton(
                icon: const Icon(Icons.comment, color: Colors.white, size: 40),
                onPressed: () => print('Comment tapped'),
              ),
              Text(
                submission.comments.toString(),
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 16),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white, size: 40),
                onPressed: () => print('Share tapped'),
              ),
              Text(
                submission.shares.toString(),
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
        // Profile Image
        Positioned(
          right: 16,
          top: 120,
          child: CircleAvatar(
            backgroundImage: NetworkImage(submission.profileImageUrl),
            radius: 25,
          ),
        ),
      ],
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool isVisible;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.isVisible,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isError = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        if (widget.isVisible) {
          _controller.play();
        }
      }).catchError((error) {
        setState(() {
          _isError = true;
        });
        print('Error initializing video: $error');
      });
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isInitialized) {
      if (widget.isVisible) {
        _controller.play();
      } else {
        _controller.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return const Center(child: Text('Failed to load video', style: TextStyle(color: Colors.white)));
    }
    if (!_isInitialized) {
      return widget.thumbnailUrl != null
          ? CachedNetworkImage(imageUrl: widget.thumbnailUrl!, fit: BoxFit.cover)
          : const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}

class Submission {
  final String id;
  final String userId;
  String username;
  String profileImageUrl;
  final String caption;
  final String challengeTitle;
  final List<MediaItem> mediaItems;
  final DateTime createdAt;
  int likes;
  int comments;
  int shares;
  bool isLiked;

  Submission({
    required this.id,
    required this.userId,
    required this.username,
    required this.profileImageUrl,
    required this.caption,
    required this.challengeTitle,
    required this.mediaItems,
    required this.createdAt,
    required this.likes,
    required this.comments,
    required this.shares,
    this.isLiked = false,
  });
}

class MediaItem {
  final String mediaType;
  final String? mediaUrl;
  final String? thumbnailUrl;

  MediaItem({
    required this.mediaType,
    this.mediaUrl,
    this.thumbnailUrl,
  });
}