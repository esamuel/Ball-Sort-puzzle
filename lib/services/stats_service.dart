import 'package:shared_preferences/shared_preferences.dart';

class StatsService {
  static const _kGamesStarted = 'stats_games_started';
  static const _kWins = 'stats_wins';
  static const _kLosses = 'stats_losses';
  static const _kTotalMoves = 'stats_total_moves';
  static const _kTotalTime = 'stats_total_time_seconds';
  static const _kBestMoves = 'stats_best_moves';
  static const _kBestTime = 'stats_best_time_seconds';

  static Future<void> recordStart() async {
    final p = await SharedPreferences.getInstance();
    final started = p.getInt(_kGamesStarted) ?? 0;
    await p.setInt(_kGamesStarted, started + 1);
  }

  static Future<void> recordWin({required int moves, required int elapsedSeconds}) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kWins, (p.getInt(_kWins) ?? 0) + 1);
    await p.setInt(_kTotalMoves, (p.getInt(_kTotalMoves) ?? 0) + moves);
    await p.setInt(_kTotalTime, (p.getInt(_kTotalTime) ?? 0) + elapsedSeconds);
    final bestMoves = p.getInt(_kBestMoves);
    if (bestMoves == null || moves < bestMoves) {
      await p.setInt(_kBestMoves, moves);
    }
    final bestTime = p.getInt(_kBestTime);
    if (bestTime == null || elapsedSeconds < bestTime) {
      await p.setInt(_kBestTime, elapsedSeconds);
    }
  }

  static Future<void> recordLoss() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kLosses, (p.getInt(_kLosses) ?? 0) + 1);
  }

  static Future<Map<String, int>> load() async {
    final p = await SharedPreferences.getInstance();
    return {
      'gamesStarted': p.getInt(_kGamesStarted) ?? 0,
      'wins': p.getInt(_kWins) ?? 0,
      'losses': p.getInt(_kLosses) ?? 0,
      'totalMoves': p.getInt(_kTotalMoves) ?? 0,
      'totalTime': p.getInt(_kTotalTime) ?? 0,
      'bestMoves': p.getInt(_kBestMoves) ?? 0,
      'bestTime': p.getInt(_kBestTime) ?? 0,
    };
  }
}
