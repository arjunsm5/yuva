import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';

class AddMediaScreen extends StatefulWidget {
  final String challengeId;

  const AddMediaScreen({
    super.key,
    required this.challengeId,
  });

  @override
  State<AddMediaScreen> createState() => _AddMediaScreenState();
}

class _AddMediaScreenState extends State<AddMediaScreen> {
  // Controllers
  final TextEditingController _captionController = TextEditingController();

  // Media files
  List<MediaItem> _mediaItems = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  int _currentFileIndex = 0;
  int _totalFiles = 0;

  // Challenge info
  String _challengeTitle = "Loading...";
  bool _isLoading = true;

  // Current user
  String? _currentUserId;

  // Image picker
  final ImagePicker _picker = ImagePicker();

  // Video constraints
  final int _maxVideoDurationSeconds = 120; // 2 minutes
  final int _maxVideoSizeMB = 250; // 250MB

  @override
  void initState() {
    super.initState();
    _fetchChallengeTitle();
    _getCurrentUserId();
  }

  // Get current user ID
  void _getCurrentUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    print('Authenticated user: ${user?.uid}'); // Debug print
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to upload media'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    }
  }

  // Fetch challenge title from Firestore
  Future<void> _fetchChallengeTitle() async {
    try {
      final challengeDoc = await FirebaseFirestore.instance
          .collection('challenges')
          .doc(widget.challengeId)
          .get();

      if (challengeDoc.exists && challengeDoc.data() != null) {
        setState(() {
          _challengeTitle = challengeDoc.data()!['challengeName'] ?? 'Unknown Challenge';
          _isLoading = false;
        });
      } else {
        setState(() {
          _challengeTitle = 'Unknown Challenge';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching challenge title: $e');
      setState(() {
        _challengeTitle = 'Unknown Challenge';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  // Pick media from gallery - unified approach
  Future<void> _pickMedia() async {
    try {
      final mediaType = await _showMediaPickerDialog();
      if (mediaType == null) return;

      if (mediaType == 'image') {
        await _pickImages();
      } else {
        await _pickVideo();
      }
    } catch (e) {
      print('Error picking media: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting media: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show media type picker dialog
  Future<String?> _showMediaPickerDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select Media Type',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.image, color: Colors.blue, size: 30),
                        const SizedBox(width: 10),
                        Text(
                          'Images',
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop('image');
                  },
                ),
                const Divider(),
                GestureDetector(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.videocam, color: Colors.red, size: 30),
                        const SizedBox(width: 10),
                        Text(
                          'Video',
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop('video');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Pick images
  Future<void> _pickImages() async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null && images.isNotEmpty) {
      for (var image in images) {
        File compressedImage = await _compressImage(File(image.path));
        setState(() {
          _mediaItems.add(MediaItem(
            file: compressedImage,
            mediaType: 'image',
          ));
        });
      }
    }
  }

  // Pick video
  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
    );

    if (video != null) {
      final File videoFile = File(video.path);
      final fileSizeInBytes = await videoFile.length();
      final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      if (fileSizeInMB > _maxVideoSizeMB) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video must be under 250MB'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        final videoInfo = await VideoCompress.getMediaInfo(video.path);
        final videoDuration = videoInfo.duration ?? 0;
        final videoDurationInSeconds = videoDuration / 1000;

        if (videoDurationInSeconds > _maxVideoDurationSeconds) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video must be under 2 minutes (current: ${(videoDurationInSeconds / 60).toStringAsFixed(1)} minutes)'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _isUploading = true;
          _uploadProgress = 0.0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing video...'),
            duration: Duration(seconds: 2),
          ),
        );

        File processedVideo;
        if (fileSizeInMB > 50) {
          final MediaInfo? compressedVideo = await _compressVideo(video.path);
          if (compressedVideo == null || compressedVideo.file == null) {
            throw Exception("Failed to compress video");
          }
          processedVideo = compressedVideo.file!;
        } else {
          processedVideo = File(video.path);
        }

        setState(() {
          _isUploading = false;
          _mediaItems.add(MediaItem(
            file: processedVideo,
            mediaType: 'video',
          ));
        });
      } catch (e) {
        setState(() {
          _isUploading = false;
        });
        print('Error processing video: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Compress image
  Future<File> _compressImage(File file) async {
    final filePath = file.path;
    final lastIndex = filePath.lastIndexOf('.');
    final outPath = filePath.substring(0, lastIndex) + '_compressed.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      filePath,
      outPath,
      quality: 70,
      format: CompressFormat.jpeg,
    );

    return File(result!.path);
  }

  // Compress video
  Future<MediaInfo?> _compressVideo(String videoPath) async {
    try {
      VideoCompress.compressProgress$.subscribe((progress) {
        setState(() {
          _uploadProgress = progress / 100;
        });
      });

      final info = await VideoCompress.compressVideo(
        videoPath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      return info;
    } catch (e) {
      print('Error compressing video: $e');
      return null;
    }
  }

  // Upload media to Firebase Storage
  Future<List<Map<String, String>>> _uploadMediaToStorage() async {
    if (_mediaItems.isEmpty) return [];

    if (_currentUserId == null || FirebaseAuth.instance.currentUser == null) {
      throw Exception('User not authenticated');
    }

    List<Map<String, String>> uploadedMedia = [];

    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _currentFileIndex = 0;
        _totalFiles = _mediaItems.length;
      });

      for (int i = 0; i < _mediaItems.length; i++) {
        setState(() {
          _currentFileIndex = i + 1;
        });

        final mediaItem = _mediaItems[i];
        final file = mediaItem.file;
        final fileName = path.basename(file.path);
        final String mediaId = DateTime.now().millisecondsSinceEpoch.toString() + '_$i';

        final destination = 'challenge_media/${widget.challengeId}/$_currentUserId/$mediaId/$fileName';

        final ref = FirebaseStorage.instance.ref(destination);

        final metadata = SettableMetadata(
          contentType: mediaItem.mediaType == 'image' ? 'image/jpeg' : 'video/mp4',
        );

        final uploadTask = ref.putFile(file, metadata);

        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          setState(() {
            _uploadProgress = progress;
          });
        });

        await uploadTask.whenComplete(() {});

        final downloadUrl = await ref.getDownloadURL();
        uploadedMedia.add({
          'mediaId': mediaId,
          'mediaUrl': downloadUrl,
          'mediaType': mediaItem.mediaType,
        });
      }

      return uploadedMedia;
    } catch (e) {
      print('Error uploading media: $e');
      throw e;
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  // Save submission to Firestore under challenge_media
  Future<void> _saveSubmission(List<Map<String, String>> mediaData) async {
    try {
      if (_currentUserId == null) {
        throw Exception('User is not authenticated');
      }

      final batch = FirebaseFirestore.instance.batch();

      // Create the main submission document under challenge_media
      final submissionRef = FirebaseFirestore.instance.collection('challenge_media').doc();
      batch.set(submissionRef, {
        'challengeId': widget.challengeId,
        'challengeTitle': _challengeTitle,
        'caption': _captionController.text,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': _currentUserId,
        'mediaCount': mediaData.length,
      });

      // Create individual media items as sub-documents under the same challenge_media document
      for (int i = 0; i < mediaData.length; i++) {
        final mediaRef = FirebaseFirestore.instance
            .collection('challenge_media')
            .doc(submissionRef.id)
            .collection('media')
            .doc(mediaData[i]['mediaId']);

        batch.set(mediaRef, {
          'mediaId': mediaData[i]['mediaId'],
          'mediaUrl': mediaData[i]['mediaUrl'],
          'mediaType': mediaData[i]['mediaType'],
          'order': i,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Update challenges document to increment submissions count
      final challengeRef = FirebaseFirestore.instance.collection('challenges').doc(widget.challengeId);
      batch.update(challengeRef, {
        'submissionsCount': FieldValue.increment(1)
      });

      await batch.commit();
    } catch (e) {
      print('Error saving submission: $e');
      throw e;
    }
  }

  // Handle submission process
  Future<void> _handleSubmit() async {
    if (_mediaItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one image or video'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_captionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a caption for your submission'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      print('Starting media upload...');
      final mediaData = await _uploadMediaToStorage();
      if (mediaData.isEmpty) throw Exception('Failed to upload media');

      print('Starting Firestore save...');
      await _saveSubmission(mediaData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entry submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print('Error in submission process: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit entry: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Remove a media file
  void _removeMediaFile(int index) {
    setState(() {
      _mediaItems.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLoading ? 'Add Media' : _challengeTitle,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload Media',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select images or videos to upload (videos limited to 2 min / 250MB)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickMedia,
                child: Container(
                  height: 70,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 28,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.videocam,
                            size: 28,
                            color: Colors.red.shade700,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to select images or videos',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_mediaItems.isNotEmpty) ...[
                Text(
                  'Selected Media (${_mediaItems.length})',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _mediaItems.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _mediaItems[index].mediaType == 'image'
                                ? Image.file(
                              _mediaItems[index].file,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                                : Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  color: Colors.grey.shade800,
                                  width: double.infinity,
                                  height: double.infinity,
                                  child: const Icon(
                                    Icons.movie,
                                    color: Colors.white54,
                                    size: 32,
                                  ),
                                ),
                                const Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _mediaItems[index].mediaType == 'image'
                                  ? Colors.blue.withOpacity(0.8)
                                  : Colors.red.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              _mediaItems[index].mediaType == 'image'
                                  ? Icons.image
                                  : Icons.videocam,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeMediaFile(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'Caption',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _captionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Write something about your entry...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_isUploading)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentFileIndex > 0
                          ? 'Uploading file $_currentFileIndex of $_totalFiles: ${(_uploadProgress * 100).toStringAsFixed(0)}%'
                          : 'Processing: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: Colors.grey.shade300,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade400,
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    _isUploading ? 'Processing...' : 'Submit',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// Media item class to store both file and type
class MediaItem {
  final File file;
  final String mediaType; // 'image' or 'video'

  MediaItem({
    required this.file,
    required this.mediaType,
  });
}