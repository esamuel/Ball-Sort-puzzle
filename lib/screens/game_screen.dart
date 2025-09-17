import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tube.dart';
import '../models/ball.dart';
import '../widgets/tube_widget.dart';
import '../services/preferences.dart';
import '../services/feedback_service.dart';
import '../services/stats_service.dart';
import '../services/audio_service.dart';
import '../services/premium_service.dart';
import 'settings_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'stats_screen.dart';

// Game type options
enum GameType {
  randomShuffle,
  rainbowPattern,
  checkerboard,
  spiralPattern,
  columnsNearSorted,
}

// Move rules (difficulty)
enum MoveRule {
  easy, // any non-full tube
  medium, // same-color top or empty if moving run >= 2
  hard, // same-color top or empty if moving run >= 3
  expert, // only same-color top; empty allowed only if whole tube is one color
}

// Game type display names and descriptions
Map<GameType, Map<String, String>> gameTypeInfo = {
  GameType.randomShuffle: {
    'name': 'Random Shuffle',
    'description': 'Classic random distribution'
  },
  GameType.rainbowPattern: {
    'name': 'Rainbow Pattern',
    'description': 'Colors arranged in rainbow sequence'
  },
  GameType.checkerboard: {
    'name': 'Checkerboard',
    'description': 'Alternating color checkerboard pattern'
  },
  GameType.spiralPattern: {
    'name': 'Spiral Pattern',
    'description': 'Colors arranged in spiral formation'
  },
  GameType.columnsNearSorted: {
    'name': 'Columns',
    'description': 'Each tube starts sorted; shuffle only top layers'
  },
};

// Tube count options for difficulty adjustment
// Tube count options will be determined by premium status
List<int> get tubeCountOptions => PremiumService.getAvailableDifficulties();

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Game configuration - dynamic capacity by tube count so UI fits phones
  int get ballsPerColor {
    switch (totalTubes) {
      case 15:
        return 12;
      case 13:
        return 10;
      case 11:
        return 9;
      case 9:
        return 7;
      case 7:
        return 5; // Beginner level with fewer balls per color
      default:
        // Fallback: scale roughly as totalTubes - 3, but clamp to sensible bounds
        return (totalTubes - 3).clamp(4, 12);
    }
  }

  // Empty tube count depends on total tubes
  // For 15-tube games we start with only ONE empty tube (14 colors + 1 empty)
  // For all other sizes we keep TWO empties for playability
  int get emptyTubes => totalTubes == 15 ? 1 : 2;
  int totalTubes =
      7; // default to 7 tubes for beginners, can be changed to 9, 11, 13, 15

  // Calculate number of colors based on game tubes (not including empty tubes)
  int get numberOfColors {
    // For 15 tubes: 14 colors (leaving 1 empty)
    if (totalTubes == 15) return 14;
    return totalTubes - emptyTubes;
  }

  final List<String> colors = [
    "red",
    "blue",
    "green",
    "pink",
    "purple",
    "yellow",
    "orange",
    "cyan",
    "brown",
    "lime",
    "navy",
    "teal",
    "silver",
    "gold",
    "black"
  ];

  // Current game type
  GameType _gameType = GameType.randomShuffle;
  // Current move rule (difficulty)
  MoveRule _moveRule = MoveRule.medium;

  List<Tube> tubes = [];
  int? selectedTube;
  int moves = 0;
  int seed = DateTime.now().millisecondsSinceEpoch;

  final List<_Move> _history = [];
  // Keys to measure tube tiles for flight animation
  List<GlobalKey> _tubeKeys = [];
  OverlayEntry? _flightEntry;
  AnimationController? _flightCtrl;

  // Animation state - removed unused variables

  // Timer and scoring
  Timer? _timer;
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  int _bestTime = 0;
  int _bestScore = 0;
  int _reshufflesRemaining = 3;
  bool _timeExpired = false;

  // Time limit (seconds) based on tube count – tuned for pressure but fair
  int get _timeLimitSeconds {
    switch (totalTubes) {
      case 7:
        return 60; // 1:00 for beginner
      case 9:
        return 300; // 5 min
      case 11:
        return 420; // 7 min
      case 13:
        return 600; // 10 min
      case 15:
        return 900; // 15 min
      default:
        return 600;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPrefsThenInit();
    _loadBestScores();
  }

  Future<void> _loadPrefsThenInit() async {
    // Load move rule
    final mr = await AppPrefs.loadMoveRule();
    switch (mr) {
      case 'easy':
        _moveRule = MoveRule.easy;
        break;
      case 'hard':
        _moveRule = MoveRule.hard;
        break;
      default:
        _moveRule = MoveRule.medium;
    }
    // Load tube count if saved
    final tc = await AppPrefs.loadTubeCount();
    if (tc != null && tubeCountOptions.contains(tc)) {
      totalTubes = tc;
    }
    setState(() {});
    _initGame();
  }

  // UI: choose move rule (difficulty)
  void _showMoveRuleDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Move Rule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<MoveRule>(
              value: MoveRule.easy,
              groupValue: _moveRule,
              title: const Text('Easy'),
              subtitle: const Text('Move to any tube that is not full'),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _moveRule = v);
                  AppPrefs.saveMoveRule('easy');
                }
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<MoveRule>(
              value: MoveRule.medium,
              groupValue: _moveRule,
              title: const Text('Medium'),
              subtitle:
                  const Text('Same-color top, or to empty if moving run ≥ 2'),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _moveRule = v);
                  AppPrefs.saveMoveRule('medium');
                }
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<MoveRule>(
              value: MoveRule.hard,
              groupValue: _moveRule,
              title: const Text('Hard'),
              subtitle:
                  const Text('Same-color top, or to empty if moving run ≥ 3'),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _moveRule = v);
                  AppPrefs.saveMoveRule('hard');
                }
                Navigator.of(context).pop();
              },
            ),
            RadioListTile<MoveRule>(
              value: MoveRule.expert,
              groupValue: _moveRule,
              title: const Text('Expert'),
              subtitle: const Text(
                  'Only same-color top; empty only if tube is mono-color'),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _moveRule = v);
                  AppPrefs.saveMoveRule('expert');
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showPauseOverlay() {
    // Pause the timer and music
    _stopTimer();
    AudioService.pauseBackgroundMusic();
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.play_arrow),
                    title: const Text('Resume'),
                    onTap: () {
                      Navigator.of(context).pop();
                      // Resume timer and music if game has started
                      if (moves > 0 && _startTime != null && _timer == null) {
                        _startTimer();
                      }
                      AudioService.resumeBackgroundMusic();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.refresh),
                    title: const Text('New Game'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _newGame();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.restart_alt),
                    title: const Text('Restart'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _restartGame();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.undo),
                    title: Text(
                        'Undo Last Move${_history.isNotEmpty ? ' (${_history.length} available)' : ''}'),
                    enabled: _history.isNotEmpty,
                    onTap: _history.isNotEmpty
                        ? () {
                            Navigator.of(context).pop();
                            _undoMove();
                          }
                        : null,
                  ),
                  ListTile(
                    leading: const Icon(Icons.shuffle),
                    title: Text('Reshuffle ($_reshufflesRemaining left)'),
                    enabled: _reshufflesRemaining > 0,
                    onTap: _reshufflesRemaining > 0
                        ? () {
                            Navigator.of(context).pop();
                            _reshufflePlayableTubes();
                          }
                        : null,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.rule),
                    title: const Text('Move Rules'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _showMoveRuleDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.filter_list),
                    title: const Text('Tube Count'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _showTubeCountDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      );
                      await _loadPrefsThenInit();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Help'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About'),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _stopTimer();
    _flightCtrl?.dispose();
    _flightEntry?.remove();
    super.dispose();
  }

  void _initGame({int? seed}) {
    // Reset counters and history
    moves = 0;
    _history.clear();
    selectedTube = null;
    _reshufflesRemaining = 3;
    _timeExpired = false;

    // Reset timer
    _stopTimer();
    _resetTimer();

    final rng = seed != null ? Random(seed) : Random();

    // Create game based on selected game type
    final int filledTubeCount = numberOfColors;
    final List<String> chosenColors = List<String>.from(colors)..shuffle(rng);
    final usedColors = chosenColors.take(filledTubeCount).toList();

    // Create filled tubes
    List<Tube> filled = List.generate(
      filledTubeCount,
      (_) => Tube(<Ball>[], capacity: ballsPerColor),
    );

    if (totalTubes == 15) {
      // Special 15-tube start (Option A), but let the selected mode shape tubes #1..#12.
      // - Tube #15 stays empty (added below)
      // - Tubes #13/#14 are mono-color with the two-ball swap
      // - Tubes #1..#12 are built according to _gameType

      // First, clear and prepare first 12 tubes
      for (int t = 0; t < min(12, filled.length); t++) {
        filled[t].balls.clear();
      }

      // Apply selected pattern to first 12 tubes only
      if (_gameType == GameType.randomShuffle) {
        // Bag of balls for the first 12 tubes
        List<Ball> bag = [];
        for (var c in usedColors.take(12)) {
          bag.addAll(List.generate(ballsPerColor, (_) => Ball(c)));
        }
        bag.shuffle(rng);
        int idx = 0;
        for (final b in bag) {
          while (filled[idx].isFull) {
            idx = (idx + 1) % 12;
          }
          filled[idx].balls.add(b);
          idx = (idx + 1) % 12;
        }
      } else if (_gameType == GameType.rainbowPattern) {
        // Horizontal stripes across tubes 0..11
        for (int layer = 0; layer < ballsPerColor; layer++) {
          final String color = usedColors[layer % usedColors.length];
          for (int t = 0; t < 12; t++) {
            filled[t].balls.add(Ball(color));
          }
        }
      } else if (_gameType == GameType.checkerboard) {
        // Diagonal checkerboard: create diagonal stripes using first 2 colors
        final c0 = usedColors.isNotEmpty ? usedColors[0] : 'red';
        final c1 = usedColors.length > 1 ? usedColors[1] : 'blue';
        for (int layer = 0; layer < ballsPerColor; layer++) {
          for (int t = 0; t < 12; t++) {
            // Diagonal pattern: use (layer - t) % 2 for diagonal stripes
            final useC0 = ((layer - t) % 2 == 0);
            filled[t].balls.add(Ball(useC0 ? c0 : c1));
          }
        }
      } else if (_gameType == GameType.spiralPattern) {
        for (int layer = 0; layer < ballsPerColor; layer++) {
          for (int t = 0; t < 12; t++) {
            final idx = (t + layer) % usedColors.length;
            filled[t].balls.add(Ball(usedColors[idx]));
          }
        }
      } else if (_gameType == GameType.columnsNearSorted) {
        for (int t = 0; t < 12; t++) {
          final color = usedColors[t % usedColors.length];
          filled[t]
              .balls
              .addAll(List.generate(ballsPerColor, (_) => Ball(color)));
        }
        final int layersToDisrupt = (ballsPerColor / 4).clamp(2, 4).toInt();
        final List<Ball> disruptBag = [];
        for (int t = 0; t < 12; t++) {
          for (int l = 0; l < layersToDisrupt; l++) {
            if (filled[t].balls.isNotEmpty) {
              disruptBag.add(filled[t].balls.removeLast());
            }
          }
        }
        disruptBag.shuffle(rng);
        int p = 0;
        for (final b in disruptBag) {
          filled[p % 12].balls.add(b);
          p++;
        }
      }

      // Ensure tubes #13 and #14 are mono-color
      if (filled.length >= 14) {
        filled[12].balls.clear();
        filled[13].balls.clear();
        filled[12]
            .balls
            .addAll(List.generate(ballsPerColor, (_) => Ball(usedColors[12])));
        filled[13]
            .balls
            .addAll(List.generate(ballsPerColor, (_) => Ball(usedColors[13])));
      }
      // Swap top two between tube #14 (index 13) and tube #13 (index 12):
      // - Take top two from tube14 and place them at the BOTTOM of tube13
      // - Then take now top two from tube13 (originally its own color) and place them on TOP of tube14
      if (filledTubeCount >= 14) {
        final tube13 = filled[12]; // target for bottom insertion
        final tube14 = filled[13]; // source of top two

        // Take top two from tube14
        final List<Ball> from14Top = [];
        for (int i = 0; i < 2 && tube14.balls.isNotEmpty; i++) {
          from14Top.add(tube14.balls.removeLast());
        }

        // Remove top two from tube13 (to move to top of tube14)
        final List<Ball> from13Top = [];
        for (int i = 0; i < 2 && tube13.balls.isNotEmpty; i++) {
          from13Top.add(tube13.balls.removeLast());
        }

        // Insert the two from tube14 to the BOTTOM of tube13 (preserve order so first removed ends up lower)
        for (int i = from14Top.length - 1; i >= 0; i--) {
          tube13.balls.insert(0, from14Top[i]);
        }

        // Place the two from tube13 onto the TOP of tube14 (order preserved: last removed becomes top)
        for (final b in from13Top) {
          tube14.balls.add(b);
        }
      }
    } else if (totalTubes == 13 ||
        totalTubes == 11 ||
        totalTubes == 9 ||
        totalTubes == 7) {
      // For 13/11/9/7 tubes: build stripes without exceeding per-color totals.
      // Stripe only across the first `stripeTubes` tubes, then mono-color for the rest.
      final int stripeTubes = min(filledTubeCount, ballsPerColor);
      for (int layer = 0; layer < ballsPerColor; layer++) {
        final String color = usedColors[layer % usedColors.length];
        for (int t = 0; t < stripeTubes; t++) {
          filled[t].balls.add(Ball(color));
        }
      }
      for (int t = stripeTubes; t < filledTubeCount; t++) {
        final String color = usedColors[t % usedColors.length];
        filled[t]
            .balls
            .addAll(List.generate(ballsPerColor, (_) => Ball(color)));
      }
    } else if (_gameType == GameType.randomShuffle) {
      // Random shuffle: distribute balls randomly via bag + round-robin
      List<Ball> bag = [];
      for (var c in usedColors) {
        bag.addAll(List.generate(ballsPerColor, (_) => Ball(c)));
      }
      bag.shuffle(rng);
      int idx = 0;
      for (final b in bag) {
        while (filled[idx].isFull) {
          idx = (idx + 1) % filled.length;
        }
        filled[idx].balls.add(b);
        idx = (idx + 1) % filled.length;
      }
    } else if (_gameType == GameType.rainbowPattern) {
      // Horizontal stripes: each row (layer) is a single color across all tubes
      for (int layer = 0; layer < ballsPerColor; layer++) {
        final color = usedColors[layer % usedColors.length];
        for (int t = 0; t < filledTubeCount; t++) {
          filled[t].balls.add(Ball(color));
        }
      }
    } else if (_gameType == GameType.checkerboard) {
      // Checkerboard: alternate color by (layer + tube) parity using first 2 colors
      final c0 = usedColors.isNotEmpty ? usedColors[0] : 'red';
      final c1 = usedColors.length > 1 ? usedColors[1] : 'blue';
      for (int layer = 0; layer < ballsPerColor; layer++) {
        for (int t = 0; t < filledTubeCount; t++) {
          final useC0 = ((layer + t) % 2 == 0);
          filled[t].balls.add(Ball(useC0 ? c0 : c1));
        }
      }
    } else if (_gameType == GameType.spiralPattern) {
      // Diagonal/spiral-like: shift color index by layer and tube
      for (int layer = 0; layer < ballsPerColor; layer++) {
        for (int t = 0; t < filledTubeCount; t++) {
          final idx = (t + layer) % usedColors.length;
          filled[t].balls.add(Ball(usedColors[idx]));
        }
      }
    } else if (_gameType == GameType.columnsNearSorted) {
      // Start fully sorted columns: tube t has only color t
      for (int t = 0; t < filledTubeCount; t++) {
        final color = usedColors[t % usedColors.length];
        filled[t]
            .balls
            .addAll(List.generate(ballsPerColor, (_) => Ball(color)));
      }
      // Shuffle only the top few layers across all tubes to create a near-sorted puzzle
      final int layersToDisrupt =
          (ballsPerColor / 4).clamp(2, 4).toInt(); // 2-4 layers
      // Collect the top layers into a bag
      final List<Ball> disruptBag = [];
      for (int t = 0; t < filledTubeCount; t++) {
        for (int l = 0; l < layersToDisrupt; l++) {
          if (filled[t].balls.isNotEmpty) {
            disruptBag.add(filled[t].balls.removeLast());
          }
        }
      }
      disruptBag.shuffle(rng);
      // Redistribute the bag round-robin back to the tubes' tops
      int p = 0;
      for (final b in disruptBag) {
        filled[p % filledTubeCount].balls.add(b);
        p++;
      }
    }

    // Add empty tubes
    final int emptyTubeCount = totalTubes - filledTubeCount;
    final empties = List.generate(
        emptyTubeCount, (_) => Tube(<Ball>[], capacity: ballsPerColor));
    tubes = [...filled, ...empties];

    // Ensure we have the right number of keys for the tubes
    _tubeKeys = List.generate(tubes.length, (_) => GlobalKey());

    setState(() {});
    // After initializing, if there are no valid moves, prompt immediately
    _checkForStalemateAndPrompt();
  }

  void _startTimer() {
    _timer?.cancel();
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startTime == null) return;
      setState(() {
        _elapsed = DateTime.now().difference(_startTime!);
      });

      // Enforce time limit after first move has started
      if (!_timeExpired && _elapsed.inSeconds >= _timeLimitSeconds) {
        _onTimeExpired();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _resetTimer() {
    _elapsed = Duration.zero;
    _startTime = null;
    setState(() {});
  }

  String _formatTime(Duration d) {
    final int m = d.inMinutes.remainder(600);
    final int s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Duration get _remainingTime {
    final remaining = _timeLimitSeconds - _elapsed.inSeconds;
    return Duration(seconds: remaining.clamp(0, _timeLimitSeconds));
  }

  void _onTimeExpired() {
    _timeExpired = true;
    _stopTimer();
    AudioService.playGameOverSound();
    StatsService.recordLoss();
    FeedbackService.gameOver();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Time\'s Up!'),
        content: Text('You ran out of time. Moves made: $moves'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _newGame();
            },
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }

  void _loadBestScores() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bestTime = prefs.getInt('best_time_${_gameType.name}') ?? 0;
      _bestScore = prefs.getInt('best_score_${_gameType.name}') ?? 0;
    });
  }

  void _saveBestScores() async {
    final prefs = await SharedPreferences.getInstance();
    final currentTime = _elapsed.inSeconds;
    final currentScore = _calculateScore();

    if (_bestTime == 0 || currentTime < _bestTime) {
      _bestTime = currentTime;
      await prefs.setInt('best_time_${_gameType.name}', _bestTime);
    }

    if (currentScore > _bestScore) {
      _bestScore = currentScore;
      await prefs.setInt('best_score_${_gameType.name}', _bestScore);
    }

    setState(() {});
  }

  int _calculateScore() {
    // Calculate score based on time and moves
    final timeBonus =
        max(0, 300 - _elapsed.inSeconds); // Bonus for fast completion
    final moveBonus = max(0, 100 - moves); // Bonus for fewer moves
    return timeBonus + moveBonus;
  }

  void _onTubeTap(int tubeIndex) {
    if (_timeExpired) return; // Block input when time is up
    if (selectedTube == null) {
      // Only select tubes that have balls
      if (tubes[tubeIndex].isEmpty) {
        // invalid selection
        FeedbackService.error();
        return;
      }
      setState(() {
        selectedTube = tubeIndex;
      });
      FeedbackService.select();
    } else if (selectedTube == tubeIndex) {
      setState(() {
        selectedTube = null;
      });
      FeedbackService.select();
    } else {
      // Always try to move the ball, let _moveBall handle validation
      final from = selectedTube!;
      if (_canMoveBall(from, tubeIndex)) {
        _moveBall(from, tubeIndex);
      } else {
        // invalid move feedback
        FeedbackService.error();
      }
    }
  }

  bool _canMoveBall(int from, int to) {
    if (_timeExpired) return false;
    if (from == to) return false;
    if (tubes[from].isEmpty) return false;
    if (tubes[to].isFull) return false;

    // Starter grace rule: allow first N moves into empty tubes to begin organizing
    final int _graceMoves = (totalTubes == 15 || totalTubes == 13) ? 3 : 2;
    if (moves < _graceMoves && tubes[to].isEmpty) return true;

    final String moving = tubes[from].topBallColor;
    final int runLen = _topRunLength(from);
    switch (_moveRule) {
      case MoveRule.easy:
        // Any non-full destination
        return true;
      case MoveRule.medium:
        // Medium rule tweak:
        // - Allow onto same color top
        // - Allow to empty ONLY if moving a contiguous run of >= 2
        if (tubes[to].isEmpty) return runLen >= 2;
        return moving == tubes[to].topBallColor;
      case MoveRule.hard:
        // Hard rule tweak:
        // - Allow onto same color top only
        // - Allow to empty ONLY if moving a contiguous run of >= 3
        if (tubes[to].isEmpty) return runLen >= 3;
        return moving == tubes[to].topBallColor;
      case MoveRule.expert:
        // Expert:
        // - Only onto same color top
        // - Allow to empty ONLY if source tube is entirely one color
        if (tubes[to].isEmpty) {
          final isMono = tubes[from].isSorted &&
              tubes[from].balls.isNotEmpty; // all balls same color
          return isMono;
        }
        return moving == tubes[to].topBallColor;
    }
  }

  void _moveBall(int from, int to) {
    if (!_canMoveBall(from, to)) return;

    // Start timer on first move
    if (moves == 0 && _startTime == null) {
      _startTimer();
    }

    setState(() {
      final ball = tubes[from].balls.removeLast();
      // Mark the ball as moved by user
      final movedBall = ball.copyWith(hasBeenMovedByUser: true);
      tubes[to].balls.add(movedBall);
      _history.add(_Move(from, to, movedBall));
      moves++;
      selectedTube = null;
    });

    FeedbackService.success();
    AudioService.playMoveSound();

    if (_isGameWon()) {
      _stopTimer();
      _saveBestScores();
      AudioService.playWinSound();
      _showWinDialog();
      return;
    }

    // After each move, check for stalemate
    _checkForStalemateAndPrompt();
  }

  bool _isGameWon() {
    // Win only when every non-empty tube is completely full and homogeneous
    return tubes.every((tube) => tube.isEmpty || tube.isFullAndSorted);
  }

  bool _hasAnyValidMove() {
    for (int i = 0; i < tubes.length; i++) {
      for (int j = 0; j < tubes.length; j++) {
        if (i == j) continue;
        if (_canMoveBall(i, j)) return true;
      }
    }
    return false;
  }

  // Compute the length of the contiguous same-color run at the top of a tube
  int _topRunLength(int tubeIndex) {
    if (tubes[tubeIndex].isEmpty) return 0;
    final String color = tubes[tubeIndex].topBallColor;
    int len = 0;
    for (int i = tubes[tubeIndex].balls.length - 1; i >= 0; i--) {
      if (tubes[tubeIndex].balls[i].color == color) {
        len++;
      } else {
        break;
      }
    }
    return len;
  }

  void _checkForStalemateAndPrompt() {
    if (_hasAnyValidMove()) return;
    if (_reshufflesRemaining > 0) {
      FeedbackService.warning();
      _showNoMovesDialogWithReshuffle();
    } else {
      FeedbackService.gameOver();
      _showGameOverDialog();
    }
  }

  void _showNoMovesDialogWithReshuffle() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('No Moves Available'),
        content: Text(
            'You are stuck. You have $_reshufflesRemaining reshuffle(s) left.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showGameOverDialog();
            },
            child: const Text('Game Over'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _reshufflePlayableTubes();
            },
            child: const Text('Reshuffle'),
          ),
        ],
      ),
    );
  }

  void _showGameOverDialog() {
    // Record loss before showing dialog
    StatsService.recordLoss();
    AudioService.playGameOverSound();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over'),
        content: Text('No valid moves remain. Total moves: $moves'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _newGame();
            },
            child: const Text('New Game'),
          ),
        ],
      ),
    );
  }

  // Reshuffle only the playable tubes, excluding the last two tubes (right side)
  // Only reshuffle balls that haven't been moved by the user
  void _reshufflePlayableTubes() {
    if (_reshufflesRemaining <= 0) return;

    final int playableCount =
        totalTubes - emptyTubes; // exclude last two indexes always

    // Separate balls into user-moved and non-user-moved
    final List<Ball> userMovedBalls = [];
    final List<Ball> nonUserMovedBalls = [];

    for (int i = 0; i < playableCount; i++) {
      for (final ball in tubes[i].balls) {
        if (ball.hasBeenMovedByUser) {
          userMovedBalls.add(ball);
        } else {
          nonUserMovedBalls.add(ball);
        }
      }
      tubes[i].balls.clear();
    }

    // Only shuffle the non-user-moved balls
    final rng = Random();
    nonUserMovedBalls.shuffle(rng);

    // Redistribute non-user-moved balls round-robin into playable tubes
    int idx = 0;
    for (final ball in nonUserMovedBalls) {
      int safety = 0;
      while (tubes[idx].isFull) {
        idx = (idx + 1) % playableCount;
        if (++safety > playableCount * ballsPerColor) break;
      }
      if (!tubes[idx].isFull) {
        tubes[idx].balls.add(ball);
        idx = (idx + 1) % playableCount;
      }
    }

    // Add user-moved balls back to their original positions (they stay where they are)
    // For simplicity, we'll add them back to the first available spots
    idx = 0;
    for (final ball in userMovedBalls) {
      int safety = 0;
      while (tubes[idx].isFull) {
        idx = (idx + 1) % playableCount;
        if (++safety > playableCount * ballsPerColor) break;
      }
      if (!tubes[idx].isFull) {
        tubes[idx].balls.add(ball);
        idx = (idx + 1) % playableCount;
      }
    }

    setState(() {
      _reshufflesRemaining = (_reshufflesRemaining - 1).clamp(0, 3);
      selectedTube = null;
    });

    FeedbackService.warning();

    // After reshuffle, check again; if still stuck and no reshuffles, game over
    _checkForStalemateAndPrompt();
  }

  void _showWinDialog() {
    // Record win with current stats
    StatsService.recordWin(moves: moves, elapsedSeconds: _elapsed.inSeconds);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Congratulations!'),
        content: Text('You won in ${_formatTime(_elapsed)} with $moves moves!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    FeedbackService.win();
  }

  void _undoMove() {
    if (_history.isEmpty) return;

    final lastMove = _history.removeLast();
    final Ball ball = tubes[lastMove.to].balls.removeLast();
    tubes[lastMove.from].balls.add(ball);
    moves = max(0, moves - 1);

    // Clear any selection when undoing
    selectedTube = null;

    // Provide feedback for undo action
    FeedbackService.select(); // Light feedback for undo

    setState(() {});
  }

  void _newGame() {
    // Record a new game start for statistics
    StatsService.recordStart();
    setState(() => _initGame(seed: Random().nextInt(1000000)));
  }

  void _restartGame() {
    setState(() => _initGame(seed: seed));
  }

  void _shuffleGame() {
    setState(() {
      _gameType = GameType.randomShuffle;
      seed = Random().nextInt(1000000);
      _initGame(seed: seed);
    });
  }

  void _rainbowGame() {
    setState(() {
      _gameType = GameType.rainbowPattern;
      seed = Random().nextInt(1000000);
      _initGame(seed: seed);
    });
  }

  void _presetMediumGame() {
    setState(() {
      _gameType = GameType.checkerboard;
      seed = Random().nextInt(1000000);
      _initGame(seed: seed);
    });
  }

  void _columnsNearSortedGame() {
    setState(() {
      _gameType = GameType.columnsNearSorted;
      seed = Random().nextInt(1000000);
      _initGame(seed: seed);
    });
  }

  // Deprecated quick toggle; replaced by selection dialog
  // Kept removed to satisfy lints and avoid accidental usage.

  void _showTubeCountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Number of Tubes'),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        content: SizedBox(
          width: double.minPositive,
          height: 200,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show all difficulty levels
                ...([7, 9, 11, 13, 15]).map((tubeCount) {
                  String difficulty = '';
                  if (tubeCount == 7)
                    difficulty = 'Beginner';
                  else if (tubeCount == 9)
                    difficulty = 'Easy';
                  else if (tubeCount == 11)
                    difficulty = 'Medium';
                  else if (tubeCount == 13)
                    difficulty = 'Hard';
                  else if (tubeCount == 15) difficulty = 'Expert';

                  bool isUnlocked =
                      PremiumService.isDifficultyUnlocked(tubeCount);

                  return InkWell(
                    onTap: () {
                      if (isUnlocked) {
                        setState(() {
                          totalTubes = tubeCount;
                          _initGame();
                        });
                        AppPrefs.saveTubeCount(tubeCount);
                        Navigator.of(context).pop();
                      } else {
                        _showPremiumUpgradeDialog();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Radio<int>(
                            value: tubeCount,
                            groupValue: totalTubes,
                            onChanged: isUnlocked
                                ? (value) {
                                    if (value != null) {
                                      setState(() {
                                        totalTubes = value;
                                        _initGame();
                                      });
                                      AppPrefs.saveTubeCount(value);
                                      Navigator.of(context).pop();
                                    }
                                  }
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('$tubeCount Tubes',
                                        style: const TextStyle(fontSize: 14)),
                                    if (!isUnlocked) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.lock,
                                          size: 16, color: Colors.orange),
                                    ],
                                  ],
                                ),
                                Text('$difficulty - ${tubeCount - 2} colors',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: isUnlocked
                                            ? Colors.grey
                                            : Colors.orange)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showPremiumUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text('Upgrade to Premium'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unlock all difficulty levels and premium features:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text('• All difficulty levels (9, 11, 13, 15 tubes)'),
            const Text('• Remove all advertisements'),
            const Text('• Detailed statistics and achievements'),
            const Text('• Custom ball themes and colors'),
            const Text('• Unlimited undo moves'),
            const Text('• Priority support'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Text(
                'Premium Upgrade: \$2.99\nOne-time purchase • No subscriptions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              bool success = await PremiumService.purchasePremium();
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Premium upgrade successful!'),
                    backgroundColor: Colors.green,
                  ),
                );
                setState(() {}); // Refresh UI
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Purchase failed. Please try again.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  // Helper method to build 3D stat items
  Widget _buildStatItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // Helper method to build 3D buttons
  Widget _build3DButton(String text, VoidCallback? onPressed,
      {IconData? icon}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adjust button size based on available space
        final isCompact = MediaQuery.of(context).size.width < 400;
        final fontSize = isCompact ? 10.0 : 12.0;
        final horizontalPadding = isCompact ? 8.0 : 12.0;
        final verticalPadding = isCompact ? 6.0 : 8.0;
        final iconSize = isCompact ? 14.0 : 16.0;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: onPressed != null
                  ? [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ]
                  : [
                      Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ],
            ),
            boxShadow: onPressed != null
                ? [
                    BoxShadow(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 8,
                    ),
                    const BoxShadow(
                      color: Colors.white70,
                      offset: Offset(0, -1),
                      blurRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onPressed,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: iconSize,
                        color: onPressed != null
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                          color: onPressed != null
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.outline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        // Pause the timer when going back
        _stopTimer();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Ball Sort - $totalTubes Tubes'),
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.pause_circle_outline),
              tooltip: 'Pause',
              onPressed: _showPauseOverlay,
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Select Tube Count (9/11/13/15)',
              onPressed: _showTubeCountDialog,
            ),
            IconButton(
              icon: const Icon(Icons.rule),
              tooltip: 'Move Rules',
              onPressed: _showMoveRuleDialog,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'New Game',
              onPressed: _newGame,
            ),
            IconButton(
              icon: const Icon(Icons.restart_alt),
              tooltip: 'Restart (same seed)',
              onPressed: _restartGame,
            ),
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: _timeExpired
                  ? 'Time\'s up - undo disabled'
                  : _isGameWon()
                      ? 'Game completed - no undo needed'
                      : _history.isNotEmpty
                          ? 'Undo last move (${_history.length} moves to undo)'
                          : 'No moves to undo',
              onPressed: _timeExpired || _isGameWon() || _history.isEmpty
                  ? null
                  : _undoMove,
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) async {
                switch (value) {
                  case 'settings':
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                    // After settings, reapply prefs
                    await _loadPrefsThenInit();
                    break;
                  case 'help':
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    );
                    break;
                  case 'about':
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                    break;
                  case 'stats':
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StatsScreen()),
                    );
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'settings', child: Text('Settings')),
                PopupMenuItem(value: 'help', child: Text('Help')),
                PopupMenuItem(value: 'about', child: Text('About')),
                PopupMenuItem(value: 'stats', child: Text('Stats')),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surface.withOpacity(0.95),
                  Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.8),
                ],
              ),
            ),
            child: Column(
              children: [
                // Compact stats panel for landscape
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.surface,
                        Theme.of(context).colorScheme.surface.withOpacity(0.9),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(0, 4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.7),
                        offset: const Offset(0, -1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 400) {
                        // Stack vertically on very small screens
                        return Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem('Time', _formatTime(_elapsed)),
                                _buildStatItem('Moves', '$moves'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildStatItem('Rule',
                                '${_moveRule.name[0].toUpperCase()}${_moveRule.name.substring(1)}'),
                          ],
                        );
                      } else {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Time', _formatTime(_remainingTime)),
                            _buildStatItem('Time', _formatTime(_remainingTime)),
                            _buildStatItem('Moves', '$moves'),
                            _buildStatItem('Rule',
                                '${_moveRule.name[0].toUpperCase()}${_moveRule.name.substring(1)}'),
                          ],
                        );
                      }
                    },
                  ),
                ),
                // Optimized landscape game board - no gaps, maximized tubes
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(0),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.3),
                          Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.1),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                for (int index = 0;
                                    index < tubes.length;
                                    index++)
                                  Expanded(
                                    child: TubeWidget(
                                      key: _tubeKeys[index],
                                      tube: tubes[index],
                                      highlight: selectedTube == index,
                                      capacity: ballsPerColor,
                                      tubeIndex: index,
                                      suppressTopForColor: null,
                                      onTap: () => _onTubeTap(index),
                                      onDrop: (from, to, ballColor) {
                                        if (from != to &&
                                            _canMoveBall(from, to)) {
                                          _moveBall(from, to);
                                        }
                                      },
                                      canDropPredicate: (fromIndex, toIndex,
                                          ballColor, dest) {
                                        // Mirror _moveRule using only dest info
                                        switch (_moveRule) {
                                          case MoveRule.easy:
                                            return !dest.isFull;
                                          case MoveRule.medium:
                                            if (dest.isFull) return false;
                                            // Mirror starter grace: allow first N moves to empty
                                            final int _graceMoves =
                                                (totalTubes == 15 ||
                                                        totalTubes == 13)
                                                    ? 3
                                                    : 2;
                                            if (dest.isEmpty)
                                              return moves < _graceMoves;
                                            return dest.topBallColor ==
                                                ballColor;
                                          case MoveRule.hard:
                                            if (dest.isFull) return false;
                                            if (dest.isEmpty)
                                              return true; // free access to empty tubes
                                            return dest.topBallColor ==
                                                ballColor;
                                          case MoveRule.expert:
                                            if (dest.isFull) return false;
                                            if (dest.isEmpty)
                                              return true; // free access to empty tubes
                                            return dest.topBallColor ==
                                                ballColor;
                                        }
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Compact game mode buttons for landscape
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.surface,
                        Theme.of(context).colorScheme.surface.withOpacity(0.9),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        offset: const Offset(0, 4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Check if we need to wrap buttons for smaller screens
                      final isSmallScreen = constraints.maxWidth < 600;

                      if (isSmallScreen) {
                        return Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _build3DButton('Shuffle', _shuffleGame),
                            _build3DButton('Rainbow', _rainbowGame),
                            _build3DButton('Checker', _presetMediumGame),
                            _build3DButton('Columns', _columnsNearSortedGame),
                            _build3DButton(
                              'Reshuffle ($_reshufflesRemaining)',
                              _reshufflesRemaining > 0
                                  ? _reshufflePlayableTubes
                                  : null,
                              icon: Icons.shuffle,
                            ),
                          ],
                        );
                      } else {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _build3DButton('Shuffle', _shuffleGame),
                              const SizedBox(width: 8),
                              _build3DButton('Rainbow', _rainbowGame),
                              const SizedBox(width: 8),
                              _build3DButton('Checker', _presetMediumGame),
                              const SizedBox(width: 8),
                              _build3DButton('Columns', _columnsNearSortedGame),
                              const SizedBox(width: 8),
                              _build3DButton(
                                'Reshuffle ($_reshufflesRemaining)',
                                _reshufflesRemaining > 0
                                    ? _reshufflePlayableTubes
                                    : null,
                                icon: Icons.shuffle,
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Move {
  final int from;
  final int to;
  final Ball ball;

  _Move(this.from, this.to, this.ball);
}
