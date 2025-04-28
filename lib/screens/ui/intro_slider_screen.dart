import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:yuva/screens/account/login_screen.dart'; // Import LoginScreen

class IntroSliderScreen extends StatefulWidget {
  const IntroSliderScreen({super.key});

  @override
  State<IntroSliderScreen> createState() => _IntroSliderScreenState();
}

class _IntroSliderScreenState extends State<IntroSliderScreen> {
  final PageController _controller = PageController();
  bool isLastPage = false;
  Timer? _timer;

  final List<Map<String, String>> slides = [
    {
      'animation': 'assets/lottie/intro1.json',
      'title': 'Build the Future, Your Way',
      'desc': 'Turn your passion into progress with tools that help you grow.'
    },
    {
      'animation': 'assets/lottie/intro2.json',
      'title': 'Connect. Collaborate. Grow.',
      'desc': 'Join a powerful network of students, mentors, and opportunities.'
    },
    {
      'animation': 'assets/lottie/intro3.json',
      'title': 'Level Up with Challenges',
      'desc': 'Test your skills, earn rewards, and stand out.'
    },
    {
      'animation': 'assets/lottie/intro4.json',
      'title': 'Earn While You Learn',
      'desc': 'Find part-time gigs, internships, and real-world projects.'
    },
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_controller.hasClients) {
        int nextPage = _controller.page!.toInt() + 1;
        if (nextPage >= slides.length) {
          _controller.animateToPage(0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut);
        } else {
          _controller.nextPage(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
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
          ),
          // PageView for Slides
          PageView.builder(
            controller: _controller,
            itemCount: slides.length,
            onPageChanged: (index) {
              setState(() => isLastPage = index == slides.length - 1);
            },
            itemBuilder: (context, index) {
              final slide = slides[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lottie Animation
                    Expanded(
                      flex: 4,
                      child: Lottie.asset(
                        slide['animation']!,
                        fit: BoxFit.contain,
                        height: 250,
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Title
                    Text(
                      slide['title']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        shadows: [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Description
                    Text(
                      slide['desc']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Get Started Button (only on last page)
                    if (isLastPage)
                      AnimatedOpacity(
                        opacity: isLastPage ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
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
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                            elevation: 5,
                          ),
                          child: const Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          // Dots Indicator
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(slides.length, (i) {
                bool active = (_controller.hasClients
                    ? _controller.page?.round() == i
                    : i == 0);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}