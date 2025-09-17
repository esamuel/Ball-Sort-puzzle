import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
  static AudioPlayer? _backgroundPlayer;
  static AudioPlayer? _effectsPlayer;
  static bool _soundEnabled = true;
  static bool _musicEnabled = true;
  static bool _initialized = false;
  static double _backgroundVolume = 0.15;

  // Initialize the audio service
  static Future<void> initialize() async {
    if (_initialized) return;

    _backgroundPlayer = AudioPlayer();
    _effectsPlayer = AudioPlayer();

    // Load preferences
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool('sound_enabled') ?? true;
    _musicEnabled = prefs.getBool('music_enabled') ?? true;

    _initialized = true;

    // Start background music if enabled
    if (_musicEnabled) {
      startBackgroundMusic();
    }
  }

  // Background music control
  static Future<void> startBackgroundMusic() async {
    if (!_initialized || !_musicEnabled || _backgroundPlayer == null) return;

    try {
      await _backgroundPlayer!.setReleaseMode(ReleaseMode.loop);
      // Lower ambient volume
      await _backgroundPlayer!.setVolume(_backgroundVolume);
      // Play custom ambient track (ensure assets/sounds/ambient.mp3 exists)
      await _backgroundPlayer!.play(AssetSource('sounds/ambient.mp3'));
    } catch (e) {
      print('Error playing background music: $e');
    }
  }

  static Future<void> stopBackgroundMusic() async {
    if (_backgroundPlayer != null) {
      await _backgroundPlayer!.stop();
    }
  }

  static Future<void> pauseBackgroundMusic() async {
    if (_backgroundPlayer != null) {
      await _backgroundPlayer!.pause();
    }
  }

  static Future<void> resumeBackgroundMusic() async {
    if (_backgroundPlayer != null && _musicEnabled) {
      await _backgroundPlayer!.resume();
    }
  }

  static Future<void> setBackgroundVolume(double volume) async {
    _backgroundVolume = volume.clamp(0.0, 1.0);
    if (_backgroundPlayer != null) {
      await _backgroundPlayer!.setVolume(_backgroundVolume);
    }
  }

  // Sound effects
  static Future<void> playMoveSound() async {
    if (!_initialized || !_soundEnabled || _effectsPlayer == null) return;

    try {
      await _effectsPlayer!.setVolume(0.7);
      await _effectsPlayer!.play(AssetSource('sounds/bouncy-ball.mp3'));
    } catch (e) {
      print('Error playing move sound: $e');
    }
  }

  static Future<void> playWinSound() async {
    if (!_initialized || !_soundEnabled || _effectsPlayer == null) return;

    try {
      await _effectsPlayer!.setVolume(0.8);
      await _effectsPlayer!.play(AssetSource('sounds/win.wav'));
    } catch (e) {
      print('Error playing win sound: $e');
    }
  }

  static Future<void> playGameOverSound() async {
    if (!_initialized || !_soundEnabled || _effectsPlayer == null) return;

    try {
      await _effectsPlayer!.setVolume(0.8);
      await _effectsPlayer!.play(AssetSource('sounds/your time is up.m4a'));
    } catch (e) {
      print('Error playing game over sound: $e');
    }
  }

  // Settings control
  static Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound_enabled', _soundEnabled);
  }

  static Future<void> toggleMusic() async {
    _musicEnabled = !_musicEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('music_enabled', _musicEnabled);

    if (_musicEnabled) {
      startBackgroundMusic();
    } else {
      stopBackgroundMusic();
    }
  }

  static bool get soundEnabled => _soundEnabled;
  static bool get musicEnabled => _musicEnabled;

  // Cleanup
  static Future<void> dispose() async {
    await _backgroundPlayer?.dispose();
    await _effectsPlayer?.dispose();
    _backgroundPlayer = null;
    _effectsPlayer = null;
    _initialized = false;
  }
}
