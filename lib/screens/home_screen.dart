import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:yuva/screens/settings_screen.dart';
import 'package:yuva/screens/buy_sell_screen.dart';
import 'package:yuva/screens/challenge_screen.dart';
import 'package:yuva/screens/clips_screen.dart';
import 'package:yuva/screens/messages_screen.dart';
import 'package:yuva/screens/networking_screen.dart'; // Renamed ConnectScreen

// Drawer screen imports
import 'package:yuva/screens/profile_screen.dart';
import 'package:yuva/screens/hubs_screen.dart';
import 'package:yuva/screens/wallet_screen.dart';
import 'package:yuva/screens/bookmarks_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;

  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _displayName;
  String? _profileImageUrl;

  // Bottom navigation tab screens
  final List<Widget> _screens = [
    const ChallengesScreen(),
    const NetworkingScreen(),
    const BuySellScreen(),
    const ClipsScreen(),
    const MessagesScreen(),
  ];

  @override
  void initState() {
    super.initState();
    print('HomeScreen: initState called');
    _fetchUserData();
  }

  // Fetching user profile from Firestore
  Future<void> _fetchUserData() async {
    print('HomeScreen: Fetching user data...');
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      print('HomeScreen: Authenticated user UID: ${user.uid}');
      try {
        print('HomeScreen: Fetching document from Firestore...');
        DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          print('HomeScreen: User data retrieved successfully: ${userDoc.data()}');
          setState(() {
            _displayName = userDoc['name'] ?? widget.userName;
            _profileImageUrl = userDoc['profileImageUrl'];
          });
        } else {
          print('HomeScreen: No user document found for UID: ${user.uid}');
          setState(() {
            _displayName = widget.userName;
          });
        }
      } catch (e) {
        print('HomeScreen: Error fetching user data: $e');
        setState(() {
          _displayName = widget.userName;
        });
      }
    } else {
      print('HomeScreen: No authenticated user found.');
      setState(() {
        _displayName = widget.userName;
      });
    }
  }

  void _onItemTapped(int index) {
    print('HomeScreen: Bottom navigation tapped, index: $index');
    setState(() {
      _selectedIndex = index;
    });
    print('HomeScreen: Displaying screen: ${_screens[index].runtimeType}');
  }

  // Function to get initials from the display name
  String _getInitials(String name) {
    if (name.isEmpty || name.trim().isEmpty) {
      return '??'; // Default initials if name is empty
    }
    final nameParts = name.trim().split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (name.length > 1) {
      return name.substring(0, 2).toUpperCase();
    } else {
      return name.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    print('HomeScreen: Building UI...');
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${_displayName ?? widget.userName}'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        leading: Builder(
          builder: (context) => IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue[600], // Background color for fallback
              backgroundImage: _profileImageUrl != null &&
                  _profileImageUrl!.isNotEmpty &&
                  Uri.tryParse(_profileImageUrl!)?.isAbsolute == true
                  ? NetworkImage(_profileImageUrl!)
                  : const AssetImage('assets/default_profile.png') as ImageProvider,
              child: (_profileImageUrl == null ||
                  _profileImageUrl!.isEmpty ||
                  Uri.tryParse(_profileImageUrl!)?.isAbsolute != true)
                  ? Text(
                _getInitials(_displayName ?? widget.userName),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
                  : null,
            ),
            onPressed: () {
              print('HomeScreen: Opening drawer...');
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),

      // Drawer Navigation
      drawer: Drawer(
        child: Container(
          color: const Color(0xFF1C2526),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(color: Color(0xFF1C2526)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        print('HomeScreen: Navigating to ProfileScreen from Drawer profile image...');
                        Navigator.pop(context); // Close the drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(
                              onProfileUpdated: _fetchUserData, // Pass callback to refresh data
                            ),
                          ),
                        ).then((_) {
                          print('HomeScreen: Returned from ProfileScreen, re-fetching user data...');
                          _fetchUserData(); // Re-fetch data after returning
                        });
                      },
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blue[600], // Background color for fallback
                        backgroundImage: _profileImageUrl != null &&
                            _profileImageUrl!.isNotEmpty &&
                            Uri.tryParse(_profileImageUrl!)?.isAbsolute == true
                            ? NetworkImage(_profileImageUrl!)
                            : const AssetImage('assets/default_profile.png') as ImageProvider,
                        child: (_profileImageUrl == null ||
                            _profileImageUrl!.isEmpty ||
                            Uri.tryParse(_profileImageUrl!)?.isAbsolute != true)
                            ? Text(
                          _getInitials(_displayName ?? widget.userName),
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _displayName ?? widget.userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'I am on Yuva',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
              _buildDrawerItem(
                icon: Icons.person_outline,
                title: 'Profile',
                onTap: () {
                  print('HomeScreen: Navigating to ProfileScreen from Drawer...');
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        onProfileUpdated: _fetchUserData, // Pass callback to refresh data
                      ),
                    ),
                  ).then((_) {
                    print('HomeScreen: Returned from ProfileScreen, re-fetching user data...');
                    _fetchUserData(); // Re-fetch data after returning
                  });
                },
              ),
              _buildDrawerItem(
                icon: Icons.grid_view,
                title: 'Hubs',
                onTap: () {
                  print('HomeScreen: Navigating to HubsScreen...');
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HubsScreen()));
                },
              ),
              _buildDrawerItem(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Wallet',
                onTap: () {
                  print('HomeScreen: Navigating to WalletScreen...');
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const WalletScreen()));
                },
              ),
              _buildDrawerItem(
                icon: Icons.bookmark_border,
                title: 'Bookmarks',
                onTap: () {
                  print('HomeScreen: Navigating to BookmarksScreen...');
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BookmarksScreen()));
                },
              ),
              _buildDrawerItem(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () {
                  print('HomeScreen: Navigating to SettingsScreen...');
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()));
                },
              ),
            ],
          ),
        ),
      ),

      // Main Body (tab view)
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Challenges',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.connect_without_contact),
            label: 'Network',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Buy/Sell',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam),
            label: 'Clips',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
        ],
      ),
    );
  }

  // Drawer Item Builder
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      onTap: onTap,
    );
  }
}