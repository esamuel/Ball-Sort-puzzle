import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Ball Sort Puzzle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Version 1.0.0'),
            SizedBox(height: 16),
            Text('This game features both tap and drag-and-drop controls, multiple move rules, and responsive sizing.'),
            SizedBox(height: 16),
            Text('Privacy & Support'),
            SizedBox(height: 4),
            Text('Add your privacy policy and support links here.'),
          ],
        ),
      ),
    );
  }
}
