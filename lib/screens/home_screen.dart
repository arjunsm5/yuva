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
    _fetchUserData();
  }

  // Fetching user profile from Firestore
  Future<void> _fetchUserData() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          setState(() {
            _displayName = userDoc['name'] ?? widget.userName;
            _profileImageUrl = userDoc['profileImageUrl'];
          });
        }
      } catch (e) {
        print('Error fetching user data: $e');
        setState(() {
          _displayName = widget.userName;
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${_displayName ?? widget.userName}'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        leading: Builder(
          builder: (context) => IconButton(
            icon: CircleAvatar(
              radius: 16,
              backgroundImage: _profileImageUrl != null
                  ? NetworkImage(_profileImageUrl!)
                  : const AssetImage('assets/default_profile.png') as ImageProvider,
              child: _profileImageUrl == null
                  ? const Icon(Icons.person, size: 20, color: Colors.grey)
                  : null,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
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
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : const AssetImage('assets/default_profile.png') as ImageProvider,
                      child: _profileImageUrl == null
                          ? const Icon(Icons.person, size: 40, color: Colors.grey)
                          : null,
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
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()));
                },
              ),
              _buildDrawerItem(
                icon: Icons.grid_view,
                title: 'Hubs',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HubsScreen()));
                },
              ),
              _buildDrawerItem(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Wallet',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const WalletScreen()));
                },
              ),
              _buildDrawerItem(
                icon: Icons.bookmark_border,
                title: 'Bookmarks',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const BookmarksScreen()));
                },
              ),
              _buildDrawerItem(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: () {
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
