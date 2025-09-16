import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tube.dart';
import '../widgets/tube_widget.dart';
import '../services/preferences.dart';
import '../services/feedback_service.dart';
import '../services/stats_service.dart';
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
  easy,   // any non-full tube
  medium, // empty or same-color top (classic)
  hard,   // only same-color top (destination must not be empty)
}

// Game type display names and descriptions
Map<GameType, Map<String, String>> gameTypeInfo = {
  GameType.randomShuffle: {'name': 'Random Shuffle', 'description': 'Classic random distribution'},
  GameType.rainbowPattern: {'name': 'Rainbow Pattern', 'description': 'Colors arranged in rainbow sequence'},
  GameType.checkerboard: {'name': 'Checkerboard', 'description': 'Alternating color checkerboard pattern'},
  GameType.spiralPattern: {'name': 'Spiral Pattern', 'description': 'Colors arranged in spiral formation'},
  GameType.columnsNearSorted: {'name': 'Columns', 'description': 'Each tube starts sorted; shuffle only top layers'},
};

// Tube count options for difficulty adjustment
const List<int> tubeCountOptions = [9, 11, 13, 15];

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
      default:
        // Fallback: scale roughly as totalTubes - 3, but clamp to sensible bounds
        return (totalTubes - 3).clamp(6, 12);
    }
  }
  final int emptyTubes = 2; // exactly two empty tubes for playability
  int totalTubes = 15; // default to 15 tubes, can be changed to 9, 11, 13
  
  // Calculate number of colors based on game tubes (not including empty tubes)
  int get numberOfColors => totalTubes - emptyTubes;
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
  int _score = 0;
  int _bestTime = 0;
  int _bestScore = 0;
  int _reshufflesRemaining = 3;

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
              subtitle: const Text('Move to empty tubes or onto same-color top'),
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
              subtitle: const Text('Only onto same-color top (no empty tubes)'),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _moveRule = v);
                  AppPrefs.saveMoveRule('hard');
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Resume'),
                onTap: () => Navigator.of(context).pop(),
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
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
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

    final rng = seed != null ? Random(seed) : Random();

    // Create game based on selected game type
    final int filledTubeCount = numberOfColors;
    final List<String> chosenColors = List<String>.from(colors)..shuffle(rng);
    final usedColors = chosenColors.take(filledTubeCount).toList();

    // Create filled tubes
    List<Tube> filled = List.generate(
      filledTubeCount,
      (_) => Tube([], capacity: ballsPerColor),
    );

    if (_gameType == GameType.randomShuffle) {
      // Random shuffle: distribute balls randomly via bag + round-robin
      List<String> bag = [];
      for (var c in usedColors) {
        bag.addAll(List.filled(ballsPerColor, c));
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
          filled[t].balls.add(color);
        }
      }
    } else if (_gameType == GameType.checkerboard) {
      // Checkerboard: alternate color by (layer + tube) parity using first 2 colors
      final c0 = usedColors.isNotEmpty ? usedColors[0] : 'red';
      final c1 = usedColors.length > 1 ? usedColors[1] : 'blue';
      for (int layer = 0; layer < ballsPerColor; layer++) {
        for (int t = 0; t < filledTubeCount; t++) {
          final useC0 = ((layer + t) % 2 == 0);
          filled[t].balls.add(useC0 ? c0 : c1);
        }
      }
    } else if (_gameType == GameType.spiralPattern) {
      // Diagonal/spiral-like: shift color index by layer and tube
      for (int layer = 0; layer < ballsPerColor; layer++) {
        for (int t = 0; t < filledTubeCount; t++) {
          final idx = (t + layer) % usedColors.length;
          filled[t].balls.add(usedColors[idx]);
        }
      }
    } else if (_gameType == GameType.columnsNearSorted) {
      // Start fully sorted columns: tube t has only color t
      for (int t = 0; t < filledTubeCount; t++) {
        final color = usedColors[t % usedColors.length];
        filled[t].balls.addAll(List.filled(ballsPerColor, color));
      }
      // Shuffle only the top few layers across all tubes to create a near-sorted puzzle
      final int layersToDisrupt = (ballsPerColor / 4).clamp(2, 4).toInt(); // 2-4 layers
      // Collect the top layers into a bag
      final List<String> disruptBag = [];
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
    final empties = List.generate(emptyTubeCount, (_) => Tube([], capacity: ballsPerColor));
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
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _resetTimer() {
    _elapsed = Duration.zero;
    _startTime = null;
  }

  String _formatTime(Duration d) {
    final int m = d.inMinutes.remainder(600);
    final int s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
    final timeBonus = max(0, 300 - _elapsed.inSeconds); // Bonus for fast completion
    final moveBonus = max(0, 100 - moves); // Bonus for fewer moves
    return timeBonus + moveBonus;
  }

  void _onTubeTap(int tubeIndex) {
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
    if (from == to) return false;
    if (tubes[from].isEmpty) return false;
    if (tubes[to].isFull) return false;

    final String moving = tubes[from].topBall;
    switch (_moveRule) {
      case MoveRule.easy:
        // Any non-full destination
        return true;
      case MoveRule.medium:
        // Empty or same color top
        if (tubes[to].isEmpty) return true;
        return moving == tubes[to].topBall;
      case MoveRule.hard:
        // Only same color top (destination must not be empty)
        if (tubes[to].isEmpty) return false;
        return moving == tubes[to].topBall;
    }
  }

  void _moveBall(int from, int to) {
    if (!_canMoveBall(from, to)) return;

    setState(() {
      final ball = tubes[from].balls.removeLast();
      tubes[to].balls.add(ball);
      moves++;
      selectedTube = null;
    });

    FeedbackService.success();

    if (_isGameWon()) {
      _stopTimer();
      _saveBestScores();
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
        content: Text('You are stuck. You have $_reshufflesRemaining reshuffle(s) left.'),
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
  void _reshufflePlayableTubes() {
    if (_reshufflesRemaining <= 0) return;

    final int playableCount = totalTubes - emptyTubes; // exclude last two indexes always
    final List<String> bag = [];
    for (int i = 0; i < playableCount; i++) {
      bag.addAll(tubes[i].balls);
      tubes[i].balls.clear();
    }
    final rng = Random();
    bag.shuffle(rng);

    // Redistribute round-robin into playable tubes up to capacity
    int idx = 0;
    for (final b in bag) {
      int safety = 0;
      while (tubes[idx].isFull) {
        idx = (idx + 1) % playableCount;
        if (++safety > playableCount * ballsPerColor) break;
      }
      if (!tubes[idx].isFull) {
        tubes[idx].balls.add(b);
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
    final String ball = tubes[lastMove.to].balls.removeLast();
    tubes[lastMove.from].balls.add(ball);
    moves = max(0, moves - 1);
    
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

  void _showTubeCountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Number of Tubes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: tubeCountOptions.map((tubeCount) {
            String difficulty = '';
            if (tubeCount == 9) difficulty = 'Easy';
            else if (tubeCount == 11) difficulty = 'Medium';
            else if (tubeCount == 13) difficulty = 'Hard';
            else if (tubeCount == 15) difficulty = 'Expert';
            
            return ListTile(
              title: Text('$tubeCount Tubes'),
              subtitle: Text('$difficulty - ${tubeCount - 2} colors'),
              leading: Radio<int>(
                value: tubeCount,
                groupValue: totalTubes,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      totalTubes = value;
                      _initGame();
                    });
                    AppPrefs.saveTubeCount(value);
                    Navigator.of(context).pop();
                  }
                },
              ),
            );
          }).toList(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            onPressed: _showTubeCountDialog,
          ),
          IconButton(
            icon: const Icon(Icons.rule),
            tooltip: 'Move Rules',
            onPressed: _showMoveRuleDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _newGame,
          ),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            onPressed: _restartGame,
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _history.isNotEmpty ? _undoMove : null,
          ),
          PopupMenuButton<String>(
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
      body: Column(
        children: [
          // Game stats
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Time: ${_formatTime(_elapsed)}', style: const TextStyle(fontSize: 16)),
                Text('Moves: $moves', style: const TextStyle(fontSize: 16)),
                Text(
                  'Rule: ${_moveRule.name[0].toUpperCase()}${_moveRule.name.substring(1)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          // Game tubes in single row (fit all tubes on screen)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Available height/width and adaptive gap
                const double horizontalPadding = 8.0; // tighter padding to allow bigger tubes on phones
                final mediaPadding = MediaQuery.of(context).padding;
                final double availableHeight = constraints.maxHeight;
                // Subtract horizontal padding and device safe-area insets to prevent right overflow
                final double availableWidth =
                    constraints.maxWidth - horizontalPadding - mediaPadding.left - mediaPadding.right;
                final bool isTablet = MediaQuery.of(context).size.shortestSide >= 600;
                final double gap = isTablet ? 1.0 : 0.0; // reduce gaps on phones for larger tubes

                // Height-derived tube width: per-slot height + borders/padding (~6)
                final double perSlot = (availableHeight - 6.0) / ballsPerColor;
                final double heightDerivedTubeWidth = (perSlot + 6.0).floorToDouble().clamp(38.0, 96.0);

                // Width-derived tube width so that all tubes + gaps fit exactly
                double widthDerivedTubeWidth =
                    ((availableWidth - (totalTubes - 1) * gap) / totalTubes).floorToDouble().clamp(30.0, 120.0);
                // Safety: nudge down by 0.5 to ensure total <= available width on tight devices
                widthDerivedTubeWidth = (widthDerivedTubeWidth - 0.5).floorToDouble().clamp(28.0, 120.0);

                // Final tube width: ensure everything fits horizontally and keeps touchable size
                final double tubeWidth = (heightDerivedTubeWidth < widthDerivedTubeWidth
                        ? heightDerivedTubeWidth
                        : widthDerivedTubeWidth)
                    .floorToDouble()
                    .clamp(32.0, 120.0);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: horizontalPadding / 2, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      for (int index = 0; index < tubes.length; index++) ...[
                        SizedBox(
                          width: tubeWidth,
                          child: TubeWidget(
                            key: _tubeKeys[index],
                            tube: tubes[index],
                            highlight: selectedTube == index,
                            capacity: ballsPerColor,
                            tubeIndex: index,
                            suppressTopForColor: null,
                            onTap: () => _onTubeTap(index),
                            onDrop: (from, to, ball) {
                              if (from != to && _canMoveBall(from, to)) {
                                _moveBall(from, to);
                              }
                            },
                            canDropPredicate: (ball, dest) {
                              // Mirror _moveRule using only dest info
                              switch (_moveRule) {
                                case MoveRule.easy:
                                  return !dest.isFull;
                                case MoveRule.medium:
                                  if (dest.isFull) return false;
                                  if (dest.isEmpty) return true;
                                  return dest.topBall == ball;
                                case MoveRule.hard:
                                  if (dest.isFull || dest.isEmpty) return false;
                                  return dest.topBall == ball;
                              }
                            },
                          ),
                        ),
                        if (index < tubes.length - 1) SizedBox(width: gap),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          // Game mode buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _shuffleGame,
                  child: const Text('Shuffle'),
                ),
                ElevatedButton(
                  onPressed: _rainbowGame,
                  child: const Text('Rainbow'),
                ),
                ElevatedButton(
                  onPressed: _presetMediumGame,
                  child: const Text('Checkerboard'),
                ),
                ElevatedButton(
                  onPressed: _columnsNearSortedGame,
                  child: const Text('Columns'),
                ),
                ElevatedButton.icon(
                  onPressed: _reshufflesRemaining > 0 ? _reshufflePlayableTubes : null,
                  icon: const Icon(Icons.shuffle),
                  label: Text('Reshuffle ($_reshufflesRemaining)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Move {
  final int from;
  final int to;
  final String ball;

  _Move(this.from, this.to, this.ball);
}
