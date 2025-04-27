import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // For base64 decoding
import 'sell_screen.dart';
import 'package:geolocator/geolocator.dart'; // For location services

class BuySellScreen extends StatefulWidget {
  const BuySellScreen({super.key});

  @override
  State<BuySellScreen> createState() => _BuySellScreenState();
}

class _BuySellScreenState extends State<BuySellScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fabController;
  Position? _currentPosition; // Store user's current location

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: false);

    // Stop FAB animation after 1 spin
    Future.delayed(const Duration(milliseconds: 800), () {
      _fabController.stop();
    });

    // Fetch user's location (to be implemented)
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _fabController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Placeholder for getting user's location
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled, don't continue
      // Handle this case (e.g., show a dialog to enable location)
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, handle accordingly
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle accordingly
      return;
    }

    // Fetch the current position
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  // Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Radius of Earth in kilometers
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c; // Distance in kilometers
  }

  double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.deepPurpleAccent,
            borderRadius: BorderRadius.circular(20),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'Service Requests'),
            Tab(text: 'Other Listings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Service Requests
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sellitems')
                .where('category', isEqualTo: 'Service Request')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No service requests available.'));
              }

              final items = snapshot.data!.docs.where((doc) {
                if (_currentPosition == null) return true; // Show all if location not available
                final data = doc.data() as Map<String, dynamic>;
                final lat = data['latitude'] as double? ?? 0.0;
                final lon = data['longitude'] as double? ?? 0.0;
                final distance = _calculateDistance(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  lat,
                  lon,
                );
                return distance <= 50; // Show items within 50 km
              }).toList();

              if (items.isEmpty) {
                return const Center(child: Text('No nearby service requests found.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final data = item.data() as Map<String, dynamic>;
                  final images = data['images'] as List<dynamic>? ?? [];
                  final imageBase64 = images.isNotEmpty ? images[0] as String : null;
                  final lat = data['latitude'] as double? ?? 0.0;
                  final lon = data['longitude'] as double? ?? 0.0;
                  final distance = _currentPosition != null
                      ? _calculateDistance(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    lat,
                    lon,
                  )
                      : 0.0;

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: imageBase64 != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(imageBase64),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.broken_image,
                            size: 60,
                            color: Colors.grey,
                          ),
                        ),
                      )
                          : const Icon(
                        Icons.image,
                        size: 60,
                        color: Colors.grey,
                      ),
                      title: Text(
                        data['title'] ?? 'No Title',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            data['description'] ?? 'No Description',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Price: ₹${data['price']?.toStringAsFixed(2) ?? 'N/A'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.deepPurpleAccent,
                              fontSize: 16,
                            ),
                          ),
                          if (distance > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${distance.toStringAsFixed(2)} km away',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 18,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        // Navigate to item detail screen (to be implemented)
                      },
                    ),
                  );
                },
              );
            },
          ),
          // Tab 2: Other Listings (Books, PGs, Roommates)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sellitems')
                .where('category', whereIn: [
              'Books & Notes',
              'Pg & Hostels',
              'Roommates & Flatmates'
            ])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No listings available.'));
              }

              final items = snapshot.data!.docs.where((doc) {
                if (_currentPosition == null) return true; // Show all if location not available
                final data = doc.data() as Map<String, dynamic>;
                final lat = data['latitude'] as double? ?? 0.0;
                final lon = data['longitude'] as double? ?? 0.0;
                final distance = _calculateDistance(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  lat,
                  lon,
                );
                return distance <= 50; // Show items within 50 km
              }).toList();

              if (items.isEmpty) {
                return const Center(child: Text('No nearby listings found.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final data = item.data() as Map<String, dynamic>;
                  String priceField = data['price'] != null
                      ? 'Price'
                      : data['rentPerPerson'] != null
                      ? 'Rent'
                      : data['expectedRent'] != null
                      ? 'Rent'
                      : 'N/A';
                  double? priceValue = data['price'] ??
                      data['rentPerPerson'] ??
                      data['expectedRent'];
                  final images = data['images'] as List<dynamic>? ?? [];
                  final imageBase64 = images.isNotEmpty ? images[0] as String : null;
                  final lat = data['latitude'] as double? ?? 0.0;
                  final lon = data['longitude'] as double? ?? 0.0;
                  final distance = _currentPosition != null
                      ? _calculateDistance(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    lat,
                    lon,
                  )
                      : 0.0;

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: imageBase64 != null
                          ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          base64Decode(imageBase64),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.broken_image,
                            size: 60,
                            color: Colors.grey,
                          ),
                        ),
                      )
                          : const Icon(
                        Icons.image,
                        size: 60,
                        color: Colors.grey,
                      ),
                      title: Text(
                        data['title'] ?? 'No Title',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            data['description'] ?? 'No Description',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$priceField: ₹${priceValue?.toStringAsFixed(2) ?? 'N/A'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.deepPurpleAccent,
                              fontSize: 16,
                            ),
                          ),
                          if (distance > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${distance.toStringAsFixed(2)} km away',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          if (data['occupancy'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Occupancy: ${data['occupancy']}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 18,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        // Navigate to item detail screen (to be implemented)
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.deepPurpleAccent.withOpacity(0.6),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SellScreen()),
            );
          },
          backgroundColor: Colors.deepPurpleAccent,
          child: RotationTransition(
            turns: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
              parent: _fabController,
              curve: Curves.easeOutCubic,
            )),
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}