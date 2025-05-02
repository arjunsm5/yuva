import 'dart:async'; // For handling timers (optional auto-scroll functionality)
import 'package:flutter/material.dart'; // Core Flutter package for UI components
import 'package:lottie/lottie.dart'; // Package to display Lottie animations
import 'package:yuva/screens/account/login_screen.dart'; // Import LoginScreen for navigation

// IntroSliderScreen is a StatefulWidget because it manages dynamic state (e.g., page index, timer)
class IntroSliderScreen extends StatefulWidget {
  const IntroSliderScreen({super.key}); // Constructor for IntroSliderScreen

  @override
  State<IntroSliderScreen> createState() => _IntroSliderScreenState(); // Creates the state for this widget
}

// State class for IntroSliderScreen
class _IntroSliderScreenState extends State<IntroSliderScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController; // Controller for managing PageView
  int _currentPage = 0; // Track current page
  Timer? _timer; // Timer for auto-scroll functionality

  // List of slides containing animation paths, titles, and descriptions
  final List<Map<String, String>> slides = [
    {
      'animation': 'assets/lottie/intro1.json', // Path to the first Lottie animation
      'title': 'Connect. Collaborate. Grow.',
      'desc': 'Join a powerful network of students, mentors, and opportunities.',
    },
    {
      'animation': 'assets/lottie/intro2.json', // Path to the second Lottie animation
      'title': 'Build the Future, Your Way',
      'desc': 'Turn your passion into progress with tools that help you grow.',
    },
    {
      'animation': 'assets/lottie/intro3.json', // Path to the third Lottie animation
      'title': 'Level Up with Challenges',
      'desc': 'Test your skills, earn rewards, and stand out.',
    },
    {
      'animation': 'assets/lottie/intro4.json', // Path to the fourth Lottie animation
      'title': 'Earn While You Learn',
      'desc': 'Find part-time gigs, internships, and real-world projects.',
    },
  ];

  @override
  void initState() {
    super.initState();

    // Initialize PageController
    _pageController = PageController(initialPage: 0);

    // Start auto-scrolling timer
    _startAutoScroll();
  }

  void _startAutoScroll() {
    // Cancel any existing timer
    _timer?.cancel();

    // Create a new timer that triggers every 4 seconds
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      // Make sure _pageController is attached to widget tree
      if (_pageController.hasClients) {
        // If we're at the last page, go back to the first page
        if (_currentPage == slides.length - 1) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          // Otherwise, go to the next page
          _pageController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose(); // Disposes the PageController to free resources
    _timer?.cancel(); // Cancels the timer to prevent memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get device dimensions to make layout responsive
    final Size screenSize = MediaQuery.of(context).size;
    final double buttonAreaHeight = screenSize.height * 0.12; // 12% of screen height for button area

    return Scaffold(
      body: Container(
        // Background Gradient
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.9),
              Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Content area (PageView) - takes all available space minus button area
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (index) {
                    // Update current page when user swipes or auto-scroll changes page
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenSize.width * 0.05,
                          ),
                          child: Column(
                            // Center the content vertically with more space at the top
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Spacer at top to push content down a bit from top
                              SizedBox(height: constraints.maxHeight * 0.05),

                              // Lottie Animation (centered)
                              Expanded(
                                flex: 6, // Takes more space for animation
                                child: Center(
                                  child: Lottie.asset(
                                    slide['animation']!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),

                              // Spacer to push text down closer to button
                              const Spacer(),

                              // Content moves closer to button (text block)
                              Column(
                                children: [
                                  // Title
                                  Text(
                                    slide['title']!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: screenSize.width < 360 ? 24 : 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontFamily: 'Poppins',
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black26,
                                          offset: Offset(2, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: constraints.maxHeight * 0.02),

                                  // Description
                                  Text(
                                    slide['desc']!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: screenSize.width < 360 ? 14 : 16,
                                      color: Colors.white70,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),

                              // Space between text and button (smaller than before)
                              SizedBox(height: constraints.maxHeight * 0.06),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Button area
              Container(
                height: buttonAreaHeight,
                padding: EdgeInsets.only(
                  bottom: screenSize.height * 0.03,
                ),
                child: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: screenSize.width * 0.1,
                        vertical: screenSize.height * 0.018,
                      ),
                      elevation: 5,
                    ),
                    child: Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: screenSize.width < 360 ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}