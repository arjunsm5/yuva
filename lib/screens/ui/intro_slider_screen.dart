import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:yuva/screens/account/login_screen.dart';

class IntroSliderScreen extends StatefulWidget {
  const IntroSliderScreen({super.key});

  @override
  State<IntroSliderScreen> createState() => _IntroSliderScreenState();
}

class _IntroSliderScreenState extends State<IntroSliderScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  final List<Map<String, String>> slides = [
    {
      'animation': 'assets/lottie/intro1.json',
      'title': 'Connect. Collaborate. Grow.',
      'desc': 'Join a powerful network of students, mentors, and opportunities.',
    },
    {
      'animation': 'assets/lottie/intro2.json',
      'title': 'Build the Future, Your Way',
      'desc': 'Turn your passion into progress with tools that help you grow.',
    },
    {
      'animation': 'assets/lottie/intro3.json',
      'title': 'Level Up with Challenges',
      'desc': 'Test your skills, earn rewards, and stand out.',
    },
    {
      'animation': 'assets/lottie/intro4.json',
      'title': 'Earn While You Learn',
      'desc': 'Find part-time gigs, internships, and real-world projects.',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Initialize PageController with a large initial page to allow infinite scrolling
    _pageController = PageController(initialPage: slides.length * 1000);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      if (_pageController.hasClients) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double buttonAreaHeight = screenSize.height * 0.12;

    return Scaffold(
      body: Container(
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
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemBuilder: (context, index) {
                    final slide = slides[index % slides.length];
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenSize.width * 0.05,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: constraints.maxHeight * 0.05),
                              Expanded(
                                flex: 6,
                                child: Center(
                                  child: Lottie.asset(
                                    slide['animation']!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Column(
                                children: [
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
                              SizedBox(height: constraints.maxHeight * 0.06),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index % slides.length;
                    });
                  },
                ),
              ),
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