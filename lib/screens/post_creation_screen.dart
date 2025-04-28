import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class PostCreationScreen extends StatefulWidget {
  const PostCreationScreen({super.key});

  @override
  State<PostCreationScreen> createState() => _PostCreationScreenState();
}

class _PostCreationScreenState extends State<PostCreationScreen> {
  bool isAnonymous = false;
  String selectedHub = '';
  Map<String, dynamic>? currentUser;
  List<Map<String, dynamic>> hubs = [];
  bool isLoading = true;
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  // Poll related variables
  bool showPollCreator = false;
  List<TextEditingController> pollOptions = [
    TextEditingController(),
    TextEditingController(),
  ];

  // Images related variables
  List<File> selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  bool uploadingImages = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchHubs();
  }

  Future<void> _fetchUserData() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      print('Current user UID: ${user?.uid}'); // Debug print
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          // Create a user document if it doesn't exist
          String generatedUniqueName = 'User${user.uid.substring(0, 8)}';
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'name': user.displayName ?? 'User',
            'uniqueName': generatedUniqueName,
            'profileImageUrl': user.photoURL ?? '',
          }, SetOptions(merge: true));

          setState(() {
            currentUser = {
              'name': user.displayName ?? 'User',
              'uniqueName': generatedUniqueName,
              'profileImageUrl': user.photoURL ?? '',
            };
            isLoading = false;
          });
        } else {
          Map<String, dynamic> userData = userDoc.data()!;
          // Ensure uniqueName exists
          if (userData['uniqueName'] == null) {
            String generatedUniqueName = 'User${user.uid.substring(0, 8)}';
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({'uniqueName': generatedUniqueName});
            userData['uniqueName'] = generatedUniqueName;
          }

          setState(() {
            currentUser = userData;
            print('Fetched user data: $currentUser'); // Debug print
            isLoading = false;
          });
        }
      } else {
        print('No user signed in');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchHubs() async {
    try {
      final hubsSnapshot =
      await FirebaseFirestore.instance.collection('hubs').get();

      setState(() {
        hubs = hubsSnapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
      });
    } catch (e) {
      print('Error fetching hubs: $e');
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];
    final User? user = FirebaseAuth.instance.currentUser;
    print('Attempting upload - User: ${user?.uid}'); // Debug print
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not signed in')),
      );
      return imageUrls;
    }

    if (selectedImages.isEmpty) return imageUrls;

    setState(() {
      uploadingImages = true;
    });

    try {
      for (var imageFile in selectedImages) {
        final fileExt = path.extension(imageFile.path);
        final targetPath = '${imageFile.path}_compressed$fileExt';

        File? compressedFile;
        if (fileExt.toLowerCase() == '.jpg' || fileExt.toLowerCase() == '.jpeg') {
          final result = await FlutterImageCompress.compressAndGetFile(
            imageFile.path,
            targetPath,
            quality: 70,
            minWidth: 1080,
            minHeight: 1080,
          );
          if (result != null) {
            compressedFile = File(result.path);
          }
        } else {
          compressedFile = imageFile;
        }

        if (compressedFile == null) continue;

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('post_images')
            .child(user.uid)
            .child('${DateTime.now().millisecondsSinceEpoch}$fileExt');

        print(
            'Uploading to path: post_images/${user.uid}/${DateTime.now().millisecondsSinceEpoch}$fileExt');
        final uploadTask = await storageRef.putFile(compressedFile);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        imageUrls.add(downloadUrl);

        if (compressedFile.path != imageFile.path) {
          await compressedFile.delete();
        }
      }
    } catch (e) {
      print('Error uploading images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading images: $e')),
      );
    } finally {
      setState(() {
        uploadingImages = false;
      });
    }

    return imageUrls;
  }

  Future<void> _savePost() async {
    if (_postController.text.trim().isEmpty || selectedHub.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    try {
      List<String> imageUrls = await _uploadImages();
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Ensure currentUser is not null and has uniqueName
        if (currentUser == null) {
          await _fetchUserData(); // Re-fetch if currentUser is null
        }
        String uniqueName = currentUser?['uniqueName'] ?? 'User${user.uid.substring(0, 8)}';

        // Find the selected hub's data to get hubImage
        final selectedHubData = hubs.firstWhere(
              (hub) => hub['id'] == selectedHub,
          orElse: () => {'hubImage': null},
        );
        String? hubImageUrl = selectedHubData['hubImage'];

        Map<String, dynamic> postData = {
          'content': _postController.text,
          'hubId': selectedHub,
          'userId': user.uid,
          'userName': isAnonymous ? uniqueName : (currentUser?['name'] ?? 'User'),
         // 'userProfileImage': isAnonymous ? null : currentUser?['profileImageUrl'],
          'isAnonymous': isAnonymous,
          'uniqueName': uniqueName,
          'createdAt': FieldValue.serverTimestamp(),
         // 'hubImage': hubImageUrl, // Add hubImage to post data
        };

        if (_linkController.text.isNotEmpty) {
          postData['link'] = _linkController.text;
        }

        if (showPollCreator) {
          List<String> validOptions = pollOptions
              .map((controller) => controller.text.trim())
              .where((option) => option.isNotEmpty)
              .toList();

          if (validOptions.length >= 2) {
            Map<String, int> votesMap = {};
            for (int i = 0; i < validOptions.length; i++) {
              votesMap[i.toString()] = 0;
            }

            postData['poll'] = {
              'options': validOptions,
              'votes': votesMap,
            };
          }
        }

        if (imageUrls.isNotEmpty) {
          postData['images'] = imageUrls;
        }

        // Add the post to Firestore and get the DocumentReference
        DocumentReference postRef = await FirebaseFirestore.instance.collection('posts').add(postData);

        // Update the post with its own postId
        await postRef.update({
          'postId': postRef.id, // Save the postId to the document
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to create a post')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating post: $e')),
      );
    }
  }
  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          selectedImages.addAll(
              pickedFiles.map((xFile) => File(xFile.path)).toList());
        });
      }
    } catch (e) {
      print('Error picking images: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      selectedImages.removeAt(index);
    });
  }

  void _showAddLinkDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Link'),
        content: TextField(
          controller: _linkController,
          decoration: InputDecoration(
            hintText: 'Enter URL',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Dismiss', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Confirm'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        backgroundColor: Colors.white,
      ),
    );
  }

  void _togglePollCreator() {
    setState(() {
      showPollCreator = !showPollCreator;
    });
  }

  void _addPollOption() {
    if (pollOptions.length < 5) {
      setState(() {
        pollOptions.add(TextEditingController());
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 options allowed')),
      );
    }
  }

  void _removePollOption(int index) {
    if (pollOptions.length > 2) {
      setState(() {
        pollOptions.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poll requires at least 2 options')),
      );
    }
  }

  @override
  void dispose() {
    _postController.dispose();
    _linkController.dispose();
    for (var controller in pollOptions) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getUserName() {
    String uniqueName = currentUser?['uniqueName'] ?? 'Anonymous';
    if (isAnonymous) {
      return uniqueName;
    }
    return currentUser?['name'] ?? 'User';
  }

  String _getUniqueName() {
    return currentUser?['uniqueName'] ?? 'Anonymous';
  }

  Widget _getProfileImage() {
    if (isAnonymous) {
      return const CircleAvatar(
        backgroundColor: Colors.grey,
        child: Icon(Icons.person_outline, color: Colors.white),
      );
    }

    final String? profileImageUrl = currentUser?['profileImageUrl'];

    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(profileImageUrl),
        backgroundColor: Colors.grey[300],
      );
    } else {
      final String name = currentUser?['name'] ?? 'User';
      final String initials = name.isNotEmpty
          ? name
          .split(' ')
          .map((e) => e.isNotEmpty ? e[0] : '')
          .join('')
          .substring(0, name.split(' ').length > 1 ? 2 : 1)
          : 'U';

      return CircleAvatar(
        backgroundColor: Colors.blue,
        child: Text(
          initials.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Post',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isAnonymous = !isAnonymous;
                            });
                          },
                          child: Stack(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isAnonymous
                                        ? Colors.grey[300]!
                                        : Colors.blue,
                                    width: 2,
                                  ),
                                ),
                                child: _getProfileImage(),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(
                                      Icons.refresh,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _getUserName(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isAnonymous)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Anonymous',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (!isAnonymous &&
                                  currentUser?['uniqueName'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '@${_getUniqueName()}',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Toggle between user and anonymous posting',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: Padding(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                Icon(Icons.grid_view, color: Colors.grey[700]),
                                const SizedBox(width: 12),
                                const Text('Select a pod'),
                              ],
                            ),
                          ),
                          value: selectedHub.isEmpty ? null : selectedHub,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          borderRadius: BorderRadius.circular(16),
                          items: hubs.map((hub) {
                            return DropdownMenuItem<String>(
                              value: hub['id'],
                              child: Row(
                                children: [
                                  if (hub['hubImage'] != null)
                                    Container(
                                      width: 32,
                                      height: 32,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        image: DecorationImage(
                                          image: NetworkImage(hub['hubImage']),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 32,
                                      height: 32,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.blue,
                                            Colors.blue.shade300
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          hub['name']?.substring(0, 1) ?? 'H',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Text(
                                    hub['name'] ?? 'Unnamed Hub',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                selectedHub = value;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.purple.shade100,
                          width: 1,
                        ),
                      ),
                      width: double.infinity,
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.purple[700],
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Read Community Guidelines before posting!',
                              style: TextStyle(
                                color: Colors.purple[700],
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _postController,
                        maxLines: null,
                        minLines: 5,
                        maxLength: 1000,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter your post here',
                          hintStyle: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[500],
                          ),
                          counterText: '',
                        ),
                        onChanged: (text) {
                          setState(() {});
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${_postController.text.length}/1000',
                          style: TextStyle(
                            color: _postController.text.length > 1000
                                ? Colors.red
                                : Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    if (_linkController.text.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.link, color: Colors.blue[700]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _linkController.text,
                                style: TextStyle(color: Colors.blue[700]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close,
                                  color: Colors.grey[600], size: 16),
                              onPressed: () {
                                setState(() {
                                  _linkController.clear();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    if (showPollCreator)
                      Container(
                        margin: const EdgeInsets.only(top: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Poll',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: _togglePollCreator,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...List.generate(pollOptions.length, (index) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                  Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: pollOptions[index],
                                        decoration: InputDecoration(
                                          hintText: 'Option ${index + 1}',
                                          contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.red[300],
                                      ),
                                      onPressed: () =>
                                          _removePollOption(index),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            TextButton.icon(
                              onPressed: _addPollOption,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Option'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (selectedImages.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 20),
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Images',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: selectedImages.length,
                                itemBuilder: (context, index) {
                                  return Stack(
                                    children: [
                                      Container(
                                        margin:
                                        const EdgeInsets.only(right: 12),
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                          image: DecorationImage(
                                            image: FileImage(
                                                selectedImages[index]),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 16,
                                        child: GestureDetector(
                                          onTap: () => _removeImage(index),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Colors.black54,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.alternate_email),
                    onPressed: () {},
                    color: Colors.grey[700],
                  ),
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: _pickImages,
                    color: Colors.grey[700],
                  ),
                  IconButton(
                    icon: const Icon(Icons.bar_chart),
                    onPressed: _togglePollCreator,
                    color: showPollCreator ? Colors.blue : Colors.grey[700],
                  ),
                  IconButton(
                    icon: const Icon(Icons.link),
                    onPressed: _showAddLinkDialog,
                    color: _linkController.text.isNotEmpty
                        ? Colors.blue
                        : Colors.grey[700],
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: (_postController.text.trim().isEmpty ||
                        selectedHub.isEmpty ||
                        uploadingImages)
                        ? null
                        : _savePost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[500],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: uploadingImages
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2.0,
                      ),
                    )
                        : const Text(
                      'Post',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}