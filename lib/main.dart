import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/game_screen.dart';
import 'services/preferences.dart';
import 'services/audio_service.dart';
import 'services/premium_service.dart';
import 'services/ad_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Force landscape orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const BallSortApp());
}

class BallSortApp extends StatefulWidget {
  const BallSortApp({super.key});

  static _BallSortAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_BallSortAppState>();

  @override
  State<BallSortApp> createState() => _BallSortAppState();
}

class _BallSortAppState extends State<BallSortApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await AudioService.initialize();
    await PremiumService.initialize();
    await AdService.initialize();
  }

  Future<void> _loadTheme() async {
    final t = await AppPrefs.loadThemeMode();
    setState(() {
      switch (t) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        default:
          _themeMode = ThemeMode.system;
      }
    });
  }

  Future<void> refreshTheme() => _loadTheme();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ball Sort Puzzle',
      theme: ThemeData(
          colorSchemeSeed: Colors.deepPurple, brightness: Brightness.light),
      darkTheme: ThemeData(
          colorSchemeSeed: Colors.deepPurple, brightness: Brightness.dark),
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      home: const GameScreen(),
    );
  }
}
