import 'package:flutter/material.dart';

class NetworkingScreen extends StatelessWidget {
  const NetworkingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: const Center(
        child: Text(
          'Networking Screen',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}