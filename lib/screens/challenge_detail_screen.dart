import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:photo_view/photo_view.dart';
import 'add_media_screen.dart';
import 'full_screen_video_player.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final String challengeId;

  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  late Future<Map<String, dynamic>> _challengeFuture;
  bool _isChallengeActive = true;
  Stream<QuerySnapshot>? _mediaSubmissionsStream;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    print('Initializing ChallengeDetailScreen for challengeId: ${widget.challengeId}');
    _challengeFuture = _fetchChallengeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('Setting up media submissions stream for challengeId: ${widget.challengeId}');
    _mediaSubmissionsStream = FirebaseFirestore.instance
        .collection('challenge_media')
        .where('challengeId', isEqualTo: widget.challengeId)
        .orderBy('createdAt', descending: true)
        .limit(9)
        .snapshots();
  }

  Future<Map<String, dynamic>> _fetchChallengeData() async {
    print('Fetching challenge data for ID: ${widget.challengeId}');
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId)
          .get();
      if (!docSnapshot.exists) {
        print('Challenge document does not exist for ID: ${widget.challengeId}');
        throw Exception('Challenge not found');
      }
      final data = docSnapshot.data() as Map<String, dynamic>;
      data['id'] = docSnapshot.id;
      final endDate = DateFormat('dd-MM-yyyy').parse(data['endDate'] ?? '25-06-2025');
      _isChallengeActive = DateTime.now().isBefore(endDate);
      print('Successfully fetched challenge data: $data');
      print('Is challenge active: $_isChallengeActive');
      return data;
    } catch (error) {
      print('Error fetching challenge data: $error');
      throw error;
    }
  }

  Map<String, dynamic> _calculateDaysAndProgress(String startDateStr, String endDateStr) {
    try {
      final startDate = DateFormat('dd-MM-yyyy').parse(startDateStr);
      final endDate = DateFormat('dd-MM-yyyy').parse(endDateStr);
      final totalDuration = endDate.difference(startDate).inDays;
      final now = DateTime.now();
      final remainingDuration = endDate.difference(now).inDays;
      final daysLeft = remainingDuration < 0 ? 0 : remainingDuration;
      final elapsed = now.difference(startDate).inDays;
      final progress = (elapsed / totalDuration).clamp(0.0, 1.0);
      print('Calculated days left: $daysLeft, progress: $progress');
      return {
        'daysLeft': daysLeft,
        'progress': progress,
        'isActive': now.isBefore(endDate),
      };
    } catch (e) {
      print('Error calculating days and progress: $e');
      return {
        'daysLeft': 0,
        'progress': 0.0,
        'isActive': false,
      };
    }
  }

  String _formatDateForDisplay(String dateStr) {
    try {
      final date = DateFormat('dd-MM-yyyy').parse(dateStr);
      final formatted = DateFormat('d MMM').format(date);
      print('Formatted date $dateStr to $formatted');
      return formatted;
    } catch (e) {
      print('Error formatting date for display: $e');
      return dateStr;
    }
  }

  String _formatEndDateForDisplay(String dateStr) {
    try {
      final date = DateFormat('dd-MM-yyyy').parse(dateStr);
      final formatted = DateFormat('d MMM, yyyy').format(date);
      print('Formatted end date $dateStr to $formatted');
      return formatted;
    } catch (e) {
      print('Error formatting end date for display: $e');
      return dateStr;
    }
  }

  void _showToast(String message) {
    print('Showing toast: $message');
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 2,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  void _handleTakePartTap(bool isActive, String challengeId) {
    print('Take part button tapped, isActive: $isActive, challengeId: $challengeId');
    if (isActive) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddMediaScreen(challengeId: challengeId),
        ),
      );
    } else {
      _showToast("This challenge has ended and is no longer accepting submissions");
    }
  }

  void _navigateToSubmissionDetail(String submissionId) {
    print('Navigating to submission detail: $submissionId');
    // TODO: Implement navigation to submission detail screen
  }

  void _showFullScreenMedia(String submissionId, String mediaType, {String? thumbnailUrl}) {
    print('Showing full-screen media: type=$mediaType, submissionId=$submissionId');
    if (mediaType == 'image') {
      FirebaseFirestore.instance
          .collection('challenge_media')
          .doc(submissionId)
          .collection('media')
          .orderBy('order')
          .limit(1)
          .get()
          .then((mediaSnapshot) {
        if (mediaSnapshot.docs.isNotEmpty) {
          final mediaItem = mediaSnapshot.docs.first.data();
          final mediaUrl = mediaItem['mediaUrl'] as String? ?? '';
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                backgroundColor: Colors.black,
                body: Center(
                  child: PhotoView(
                    imageProvider: NetworkImage(mediaUrl),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 2,
                  ),
                ),
              ),
            ),
          );
        }
      }).catchError((error) {
        print('Error fetching media URL for image: $error');
        _showToast('Failed to load image');
      });
    } else if (mediaType == 'video') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenVideoPlayer(
            challengeId: widget.challengeId,
            submissionId: submissionId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building ChallengeDetailScreen');
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _challengeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('Challenge data loading...');
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            print('Challenge data error: ${snapshot.error}');
            return Center(
              child: Text(
                'Error loading challenge: ${snapshot.error}',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
            );
          } else if (!snapshot.hasData) {
            print('No challenge data found');
            return Center(
              child: Text(
                'Challenge not found',
                style: GoogleFonts.poppins(fontSize: 16),
              ),
            );
          }

          final challenge = snapshot.data!;
          final challengeId = challenge['id'] ?? '';
          final challengeName = challenge['challengeName'] ?? 'Green Challenge';
          final skill = challenge['skill'] ?? 'Special education';
          final startDate = challenge['startDate'] ?? '25-04-2025';
          final endDate = challenge['endDate'] ?? '25-06-2025';
          final calculation = _calculateDaysAndProgress(startDate, endDate);
          final daysLeft = calculation['daysLeft'];
          final progress = calculation['progress'];
          final isActive = calculation['isActive'];
          final imageUrl = challenge['imageUrl'] ??
              'https://firebasestorage.googleapis.com/v0/b/yuvaapp.appspot.com/o/challenge_images%2FFnFfYV8VI70iE6b201gL.jpg?alt=media&token=e4b0e415-7804-4410-94a5-da0c21ac6ab8';
          final reward = challenge['reward'] ?? '400';
          final description = challenge['description'] ?? 'test';
          final postTypeRaw = challenge['postType'] ?? 'video';
          final postType = postTypeRaw[0].toUpperCase() + postTypeRaw.substring(1).toLowerCase();
          final participants = challenge['participants'] ?? 'open to all';
          final skillCategory = challenge['skillCategory'] ?? 'Education';
          final createdAt = challenge['createdAt'] as Timestamp?;
          final link = challenge['link'] ?? '';
          final winDescription = challenge['winDescription'] ?? 'test';

          final displayStartDate = _formatDateForDisplay(startDate);
          final displayEndDate = _formatEndDateForDisplay(endDate);
          final participantsDisplay = participants[0].toUpperCase() + participants.substring(1).toLowerCase();

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    backgroundColor: Colors.green.shade800,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading challenge image: $error, URL: $imageUrl');
                              return Container(
                                color: Colors.green.shade300,
                                child: const Center(
                                  child: Icon(Icons.image_not_supported, size: 50, color: Colors.white),
                                ),
                              );
                            },
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.green.shade900.withOpacity(0.7)],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 20,
                            bottom: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Turn Your Green",
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  "Idea into Action!",
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  challengeName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.black,
                                ),
                                padding: const EdgeInsets.all(8),
                                child: const Icon(
                                  Icons.share,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  description,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  winDescription,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoCardNew("Post", postType),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildInfoCardNew("Skill", skill),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoCardNew("Reward", "₹$reward"),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildInfoCardNew("Who can win?", participantsDisplay),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "Leaderboard",
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward, color: Colors.grey.shade400),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Inspire others, rise to the top!",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildCircleAvatar("https://randomuser.me/api/portraits/men/32.jpg"),
                                    _buildCircleAvatar("https://randomuser.me/api/portraits/women/44.jpg"),
                                    _buildCircleAvatar("https://randomuser.me/api/portraits/men/85.jpg"),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildTimelineSection(displayStartDate, displayEndDate, daysLeft, progress),
                          const SizedBox(height: 20),
                          _buildChallengeMediaGrid(),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: isActive
                          ? () => _handleTakePartTap(true, challengeId)
                          : () => _handleTakePartTap(false, challengeId),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.5,
                        height: 45,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green.shade400 : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            isActive ? "Take Part" : "Challenge Ended",
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.blueAccent,
                            Colors.purpleAccent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChallengeMediaGrid() {
    print('Building challenge media grid');
    return StreamBuilder<QuerySnapshot>(
      stream: _mediaSubmissionsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('Media submissions stream loading...');
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          print('Media submissions stream error: ${snapshot.error}');
          return SizedBox(
            height: 200,
            child: Center(
              child: Text(
                'Error loading submissions: ${snapshot.error}',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
            ),
          );
        }

        final submissions = snapshot.data?.docs ?? [];
        print('Submissions found: ${submissions.length}');

        if (submissions.isEmpty) {
          print('No submissions found for challengeId: ${widget.challengeId}');
          return SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 40, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No submissions yet',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Be the first to participate!',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchMediaForSubmissions(submissions),
          builder: (context, mediaSnapshot) {
            if (mediaSnapshot.connectionState == ConnectionState.waiting) {
              print('Fetching media for submissions...');
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (mediaSnapshot.hasError) {
              print('Media fetch error: ${mediaSnapshot.error}');
              return SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'Error loading media: ${mediaSnapshot.error}',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
                  ),
                ),
              );
            }

            final mediaData = mediaSnapshot.data ?? [];
            print('Media items fetched: ${mediaData.length}');

            if (mediaData.isEmpty) {
              print('No media items found for submissions');
              return SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'No media available',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey),
                  ),
                ),
              );
            }

            return GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: mediaData.length,
              itemBuilder: (context, index) {
                final data = mediaData[index];
                final mediaUrl = data['mediaUrl'] as String? ?? '';
                final mediaType = data['mediaType'] as String? ?? 'image';
                final thumbnailUrl = data['thumbnailUrl'] as String? ?? '';
                final submissionId = data['submissionId'] as String;

                print('Rendering media item $index: type=$mediaType, url=$mediaUrl, thumbnail=$thumbnailUrl');
                return GestureDetector(
                  onTap: () => _showFullScreenMedia(submissionId, mediaType, thumbnailUrl: thumbnailUrl),
                  child: _buildMediaGridItem(
                    mediaUrl,
                    mediaType,
                    submissionId,
                    thumbnailUrl: thumbnailUrl.isNotEmpty ? thumbnailUrl : null,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchMediaForSubmissions(List<QueryDocumentSnapshot> submissions) async {
    print('Fetching media for ${submissions.length} submissions');
    final mediaData = <Map<String, dynamic>>[];
    for (var submission in submissions) {
      final submissionId = submission.id;
      print('Querying media for submission: $submissionId');
      try {
        final mediaQuery = await FirebaseFirestore.instance
            .collection('challenge_media')
            .doc(submissionId)
            .collection('media')
            .orderBy('order')
            .limit(1)
            .get();

        if (mediaQuery.docs.isNotEmpty) {
          final mediaItem = mediaQuery.docs.first.data();
          print('Media found for submission $submissionId: ${mediaItem['mediaUrl']}');
          mediaData.add({
            'submissionId': submissionId,
            'mediaUrl': mediaItem['mediaUrl'] as String? ?? '',
            'mediaType': mediaItem['mediaType'] as String? ?? 'image',
            'thumbnailUrl': mediaItem['thumbnailUrl'] as String? ?? '',
          });
        } else {
          print('No media found for submission: $submissionId');
        }
      } catch (e) {
        print('Error fetching media for submission $submissionId: $e');
      }
    }
    print('Total media items fetched: ${mediaData.length}');
    return mediaData;
  }

  Widget _buildMediaGridItem(String mediaUrl, String mediaType, String submissionId, {String? thumbnailUrl}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (mediaUrl.isEmpty || (mediaType == 'video' && thumbnailUrl == null))
            _buildMediaPlaceholder()
          else if (mediaType == 'video' && thumbnailUrl != null)
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                print('Loading thumbnail for submission $submissionId: $thumbnailUrl');
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('Thumbnail load error for submission $submissionId: $error, URL: $thumbnailUrl');
                return _buildMediaPlaceholder();
              },
            )
          else
            Image.network(
              mediaUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                print('Loading media for submission $submissionId: $mediaUrl');
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                print('Image load error for submission $submissionId: $error, URL: $mediaUrl');
                return _buildMediaPlaceholder();
              },
            ),
          if (mediaType == 'video' && thumbnailUrl != null)
            const Positioned(
              bottom: 8,
              right: 8,
              child: Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaPlaceholder() {
    print('Rendering media placeholder');
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Icon(
          Icons.image,
          color: Colors.grey,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildInfoCardNew(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleAvatar(String imageUrl) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(imageUrl),
      ),
    );
  }

  Widget _buildTimelineSection(String startDate, String endDate, int daysLeft, double progress) {
    print('Building timeline: $startDate - $endDate, $daysLeft days left');
    return Container(
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$startDate - $endDate",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                daysLeft > 0 ? "$daysLeft Days left" : "Challenge ended",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: daysLeft > 0 ? Colors.green.shade700 : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade300,
              color: daysLeft > 0 ? Colors.green.shade400 : Colors.red,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}