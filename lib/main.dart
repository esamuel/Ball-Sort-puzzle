import 'package:flutter/material.dart';
import 'screens/game_screen.dart';

void main() {
  runApp(const BallSortApp());
}

class BallSortApp extends StatelessWidget {
  const BallSortApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ball Sort Puzzle',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const GameScreen(),
    );
  }
}
