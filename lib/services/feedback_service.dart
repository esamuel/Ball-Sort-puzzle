import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'preferences.dart';

class FeedbackService {
  static bool _haptics = true;
  static bool _sounds = true;
  static bool _loaded = false;
  static final AudioPlayer _player = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  // Map events to asset paths (place your audio files under assets/sounds/)
  static const _soundSelect = 'assets/sounds/select.mp3';
  static const _soundSuccess = 'assets/sounds/success.mp3';
  static const _soundWarning = 'assets/sounds/warning.mp3';
  static const _soundError = 'assets/sounds/error.mp3';
  static const _soundWin = 'assets/sounds/win.mp3';
  static const _soundGameOver = 'assets/sounds/gameover.mp3';

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _haptics = await AppPrefs.loadHapticsEnabled();
    _sounds = await AppPrefs.loadSoundEnabled();
    _loaded = true;
  }

  static Future<void> reload() async {
    _loaded = false;
    await _ensureLoaded();
  }

  static Future<void> _play(String asset) async {
    if (!_sounds) return;
    try {
      await _player.stop();
      await _player.play(AssetSource(asset.replaceFirst('assets/', '')));
    } catch (_) {
      // Fallback to system click if asset missing or player error
      SystemSound.play(SystemSoundType.click);
    }
  }

  static Future<void> select() async {
    await _ensureLoaded();
    if (_haptics) HapticFeedback.selectionClick();
    await _play(_soundSelect);
  }

  static Future<void> success() async {
    await _ensureLoaded();
    if (_haptics) HapticFeedback.lightImpact();
    await _play(_soundSuccess);
  }

  static Future<void> warning() async {
    await _ensureLoaded();
    if (_haptics) HapticFeedback.mediumImpact();
    await _play(_soundWarning);
  }

  static Future<void> error() async {
    await _ensureLoaded();
    if (_haptics) HapticFeedback.heavyImpact();
    await _play(_soundError);
  }

  static Future<void> win() async {
    await _ensureLoaded();
    if (_haptics) HapticFeedback.mediumImpact();
    await _play(_soundWin);
  }

  static Future<void> gameOver() async {
    await _ensureLoaded();
    if (_haptics) HapticFeedback.heavyImpact();
    await _play(_soundGameOver);
  }
}
