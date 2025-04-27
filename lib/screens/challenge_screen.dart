import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'challenge_detail_screen.dart'; // Import ChallengeDetailScreen

/// A StatelessWidget that displays a list of challenges
/// Shows both current and finished challenges with appropriate styling
class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key});

  /// Fetches challenges data from Firestore
  /// Returns a list of challenge maps with additional ID field
  Future<List<Map<String, dynamic>>> _fetchChallenges() async {
    print('Fetching challenges from Firestore...');
    final querySnapshot = await FirebaseFirestore.instance.collection('challenges').get();
    final challenges = querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id; // Add document ID to the data map
      print('Fetched challenge: $data');
      return data;
    }).toList().cast<Map<String, dynamic>>();
    print('Total challenges fetched: ${challenges.length}');
    return challenges;
  }

  /// Determines if a challenge is current based on end date
  /// Returns true if end date is in the future
  bool _isCurrentChallenge(String endDateStr) {
    print('Checking if challenge is current with endDate: $endDateStr');
    try {
      final endDate = DateFormat('dd-MM-yyyy').parse(endDateStr);
      final isCurrent = endDate.isAfter(DateTime.now());
      print('Challenge current status: $isCurrent');
      return isCurrent;
    } catch (e) {
      print('Error parsing end date: $e');
      return false;
    }
  }

  /// Calculates days left and progress percentage for a challenge
  /// Returns a map with 'daysLeft' and 'progress' keys
  Map<String, dynamic> _calculateDaysAndProgress(String startDateStr, String endDateStr) {
    print('Calculating progress for startDate: $startDateStr, endDate: $endDateStr');
    try {
      final startDate = DateFormat('dd-MM-yyyy').parse(startDateStr);
      final endDate = DateFormat('dd-MM-yyyy').parse(endDateStr);

      final totalDuration = endDate.difference(startDate).inDays;
      final now = DateTime.now();
      final remainingDuration = endDate.difference(now).inDays;
      final daysLeft = remainingDuration < 0 ? 0 : remainingDuration;

      final elapsed = totalDuration - remainingDuration;
      final progress = (elapsed / totalDuration).clamp(0.0, 1.0);

      print('Calculated: daysLeft=$daysLeft, progress=$progress');
      return {
        'daysLeft': daysLeft,
        'progress': progress,
      };
    } catch (e) {
      print('Error calculating progress: $e');
      return {
        'daysLeft': 0,
        'progress': 0.0,
      };
    }
  }

  /// Navigates to the challenge detail screen when a challenge is tapped
  /// Now only passes the challenge ID instead of the full challenge data
  void _navigateToChallengeDetail(BuildContext context, String challengeId) {
    print('Navigating to ChallengeDetailScreen with challengeId: $challengeId');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChallengeDetailScreen(challengeId: challengeId),
        ),
      ).then((value) => print('Returned from ChallengeDetailScreen with value: $value'));
    } catch (e) {
      print('Navigation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building ChallengesScreen');
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE6E0F8),
        elevation: 0,
        title: const Text('Challenges'),
      ),
      body: Builder(
        builder: (context) {
          print('Building FutureBuilder with context: $context');
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchChallenges(),
            builder: (context, snapshot) {
              print('FutureBuilder snapshot state: ${snapshot.connectionState}, hasError: ${snapshot.hasError}, hasData: ${snapshot.hasData}');
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No challenges found'));
              }

              final challenges = snapshot.data!;
              print('Processing ${challenges.length} challenges');
              final currentChallenges = challenges.where((c) => _isCurrentChallenge(c['endDate'] ?? '')).toList();
              final finishedChallenges = challenges.where((c) => !_isCurrentChallenge(c['endDate'] ?? '')).toList();

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (currentChallenges.isNotEmpty)
                    _buildChallengeCard(context, currentChallenges[0], true),
                  if (finishedChallenges.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                      child: Text(
                        'Finished Challenges',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...finishedChallenges.map((challenge) => _buildChallengeCard(context, challenge, false)).toList(),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildChallengeCard(BuildContext context, Map<String, dynamic> challenge, bool isCurrentChallenge) {
    print('Building challenge card for challenge: $challenge');
    final calculation = _calculateDaysAndProgress(
      challenge['startDate'] ?? '01-01-2025',
      challenge['endDate'] ?? '01-01-2025',
    );
    final daysLeft = calculation['daysLeft'];
    final progress = calculation['progress'];
    final challengeName = challenge['challengeName'] ?? 'Unnamed Challenge';
    final challengeId = challenge['id'] ?? ''; // Extract challenge ID

    return GestureDetector(
      onTap: () {
        print('Tapped challenge card with ID: $challengeId');
        _navigateToChallengeDetail(context, challengeId); // Pass only the challenge ID
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: Image.network(
                    challenge['imageUrl'] ?? 'https://via.placeholder.com/300',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('Image load error for URL ${challenge['imageUrl']}: $error');
                      return const Center(child: Icon(Icons.error));
                    },
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'Win ₹${challenge['reward'] ?? '0'}!',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: isCurrentChallenge ? const Color(0xFF4CAF50) : Colors.grey,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Text(
                      isCurrentChallenge ? '$daysLeft days left' : 'Completed',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              height: 8,
              margin: const EdgeInsets.only(top: 0),
              child: Stack(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    color: const Color(0xFFE0E0E0),
                  ),
                  FractionallySizedBox(
                    widthFactor: isCurrentChallenge ? progress : 1.0,
                    child: Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                challengeName,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}