import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tube.dart';
import '../widgets/tube_widget.dart';

// Game type options
enum GameType {
  shuffle,
  stripesWithSorted,
  twoColorStripes,
  gradientWaves,
  presetEasy,
  presetMedium,
  presetHard,
  rainbow,
  checkerboard,
  spiral,
}

// Game type display names and descriptions
Map<GameType, Map<String, String>> gameTypeInfo = {
  GameType.shuffle: {'name': 'Random Shuffle', 'description': 'Classic random distribution'},
  GameType.stripesWithSorted: {'name': 'Stripes + Sorted', 'description': 'Horizontal stripes with 2 sorted tubes'},
  GameType.twoColorStripes: {'name': 'Two-Color Stripes', 'description': 'Alternating two colors in stripes'},
  GameType.gradientWaves: {'name': 'Gradient Waves', 'description': 'Color gradient wave pattern'},
  GameType.rainbow: {'name': 'Rainbow Pattern', 'description': 'Colors arranged in rainbow sequence'},
  GameType.checkerboard: {'name': 'Checkerboard', 'description': 'Alternating color checkerboard pattern'},
  GameType.spiral: {'name': 'Spiral Pattern', 'description': 'Colors arranged in spiral formation'},
  GameType.presetEasy: {'name': 'Preset Easy', 'description': 'Nearly solved puzzle'},
  GameType.presetMedium: {'name': 'Preset Medium', 'description': 'Moderately mixed puzzle'},
  GameType.presetHard: {'name': 'Preset Hard', 'description': 'Heavily mixed puzzle'},
};

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Game configuration
  final int ballsPerColor = 12; // tube capacity
  final int emptyTubes = 2; // exactly two empty tubes for playability
  static const int totalTubes = 15;
  
  // Calculate number of colors based on game tubes (not including empty tubes)
  int get numberOfColors => totalTubes - emptyTubes; // 13 colors for game tubes
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

  // Current game type - start with recommended shuffle mode
  GameType _gameType = GameType.shuffle;

  List<Tube> tubes = [];
  int? selectedTube;
  int moves = 0;
  int seed = DateTime.now().millisecondsSinceEpoch;

  final List<_Move> _history = [];
  // Keys to measure tube tiles for flight animation
  List<GlobalKey> _tubeKeys = [];
  OverlayEntry? _flightEntry;
  AnimationController? _flightCtrl;
  int? _animatingToIndex;
  String? _animatingColor;

  // Timer/Score
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  int get _seconds => _elapsed.inSeconds;
  int get _score {
    // Simple formula: higher is better, penalize moves and time
    final int base = 100000 ~/ (_seconds + 1);
    return (base - moves * 10).clamp(0, 999999);
  }

  // Bests per mode (persisted)
  final Map<GameType, Duration> _bestTime = {};
  final Map<GameType, int> _bestScore = {};

  @override
  void initState() {
    super.initState();
    _initGame();
    _loadBests();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flightCtrl?.dispose();
    _flightEntry?.remove();
    _flightEntry = null;
    super.dispose();
  }

  void _initGame({int? seed}) {
    // Reset counters and history
    moves = 0;
    _history.clear();
    selectedTube = null;

    final rng = seed != null ? Random(seed) : Random();

    if (_gameType == GameType.shuffle) {
      // Shuffle mode: distribute randomly across filled tubes
      final int filledTubeCount = numberOfColors; // Use numberOfColors instead of totalTubes - emptyTubes
      final List<String> chosenColors = List<String>.from(colors)..shuffle(rng);
      final usedColors = chosenColors.take(filledTubeCount).toList();

      // Build a bag with exactly 12 balls per used color
      List<String> bag = [];
      for (var c in usedColors) {
        bag.addAll(List.filled(ballsPerColor, c));
      }
      bag.shuffle(rng);

      List<Tube> filled = List.generate(
        filledTubeCount,
        (_) => Tube([], capacity: ballsPerColor),
      );
      int idx = 0;
      for (final b in bag) {
        while (filled[idx].isFull) {
          idx = (idx + 1) % filled.length;
        }
        filled[idx].balls.add(b);
        idx = (idx + 1) % filled.length;
      }
      final empties = List.generate(emptyTubes, (_) => Tube([], capacity: ballsPerColor));
      tubes = [...filled, ...empties];
    } else if (_gameType == GameType.stripesWithSorted) {
      // Stripes + 3 right tubes where one is EMPTY and two are already sorted
      // Remaining left tubes (12) form horizontal stripes per row (one color per row)
      final int sortedCount = 2; // two sorted tubes
      final int extraEmpty = 1;  // one empty tube on the far right
      final int stripesCols = totalTubes - sortedCount - extraEmpty; // 12
      // Choose 3 sorted tube colors and 12 row colors deterministically
      final List<String> shuffled = List<String>.from(colors)..shuffle(rng);
      final List<String> sortedColors = shuffled.take(sortedCount).toList();
      final List<String> rowColors = shuffled.skip(sortedCount).take(ballsPerColor).toList(); // 12 rows

      // Build stripe tubes (12 tubes), each tube gets rowColors in order top->bottom
      List<Tube> stripeTubes = List.generate(
        stripesCols,
        (_) => Tube([], capacity: ballsPerColor),
      );
      // Fill by rows: for each row r, place that color into every stripe tube
      for (int r = 0; r < ballsPerColor; r++) {
        final String colorForRow = rowColors[r % rowColors.length];
        for (int c = 0; c < stripesCols; c++) {
          stripeTubes[c].balls.add(colorForRow);
        }
      }

      // Create 2 sorted tubes + 1 empty tube at the right
      List<Tube> sortedTubes = sortedColors
          .map((c) => Tube(List.filled(ballsPerColor, c), capacity: ballsPerColor))
          .toList();
      final Tube emptyTube = Tube([], capacity: ballsPerColor);

      tubes = [...stripeTubes, ...sortedTubes, emptyTube];
    } else if (_gameType == GameType.twoColorStripes) {
      // Left 12: alternating two colors per row across tubes, Right: two sorted (those two colors) + empty
      final int sortedCount = 2;
      final int extraEmpty = 1;
      final int stripesCols = totalTubes - sortedCount - extraEmpty; // 12
      final List<String> shuffled = List<String>.from(colors)..shuffle(rng);
      final String c1 = shuffled[0];
      final String c2 = shuffled[1];
      List<Tube> stripeTubes = List.generate(
        stripesCols,
        (_) => Tube([], capacity: ballsPerColor),
      );
      for (int r = 0; r < ballsPerColor; r++) {
        final String colorForRow = (r % 2 == 0) ? c1 : c2;
        for (int c = 0; c < stripesCols; c++) {
          stripeTubes[c].balls.add(colorForRow);
        }
      }
      final List<Tube> sortedTubes = [
        Tube(List.filled(ballsPerColor, c1), capacity: ballsPerColor),
        Tube(List.filled(ballsPerColor, c2), capacity: ballsPerColor),
      ];
      final Tube emptyTube = Tube([], capacity: ballsPerColor);
      tubes = [...stripeTubes, ...sortedTubes, emptyTube];
    } else if (_gameType == GameType.gradientWaves) {
      // Left 12: gradient/wave – rows are colors 0..11, each subsequent tube shifted by +k rows (circular)
      final int sortedCount = 2;
      final int extraEmpty = 1;
      final int stripesCols = totalTubes - sortedCount - extraEmpty; // 12
      final List<String> shuffled = List<String>.from(colors)..shuffle(rng);
      final List<String> rowColors = shuffled.take(ballsPerColor).toList(); // 12 colors for rows
      List<Tube> stripeTubes = List.generate(
        stripesCols,
        (_) => Tube([], capacity: ballsPerColor),
      );
      for (int c = 0; c < stripesCols; c++) {
        for (int r = 0; r < ballsPerColor; r++) {
          final String clr = rowColors[(r + c) % rowColors.length];
          stripeTubes[c].balls.add(clr);
        }
      }
      final List<Tube> sortedTubes = [
        Tube(List.filled(ballsPerColor, rowColors[0]), capacity: ballsPerColor),
        Tube(List.filled(ballsPerColor, rowColors[1]), capacity: ballsPerColor),
      ];
      final Tube emptyTube = Tube([], capacity: ballsPerColor);
      tubes = [...stripeTubes, ...sortedTubes, emptyTube];
    } else if (_gameType == GameType.rainbow) {
      // Rainbow pattern: colors arranged in rainbow sequence across tubes
      final int filledTubeCount = numberOfColors;
      final List<String> rainbowColors = ['red', 'orange', 'yellow', 'green', 'cyan', 'blue', 'purple', 'pink', 'brown', 'lime', 'navy', 'teal', 'silver'];
      List<String> bag = [];
      for (int i = 0; i < filledTubeCount; i++) {
        final String color = rainbowColors[i % rainbowColors.length];
        bag.addAll(List.filled(ballsPerColor, color));
      }
      bag.shuffle(rng);
      
      List<Tube> filled = List.generate(filledTubeCount, (_) => Tube([], capacity: ballsPerColor));
      int idx = 0;
      for (final b in bag) {
        while (filled[idx].isFull) {
          idx = (idx + 1) % filled.length;
        }
        filled[idx].balls.add(b);
        idx = (idx + 1) % filled.length;
      }
      final empties = List.generate(emptyTubes, (_) => Tube([], capacity: ballsPerColor));
      tubes = [...filled, ...empties];
    } else if (_gameType == GameType.checkerboard) {
      // Checkerboard pattern: alternating colors in a checkerboard pattern
      final int filledTubeCount = numberOfColors;
      final List<String> shuffled = List<String>.from(colors)..shuffle(rng);
      final usedColors = shuffled.take(filledTubeCount).toList();
      
      List<String> bag = [];
      for (int tubeIdx = 0; tubeIdx < filledTubeCount; tubeIdx++) {
        for (int ballIdx = 0; ballIdx < ballsPerColor; ballIdx++) {
          // Checkerboard pattern based on tube and ball position
          final int colorIdx = ((tubeIdx + ballIdx) % 2 == 0) ? 0 : 1;
          final String color = usedColors[colorIdx % usedColors.length];
          bag.add(color);
        }
      }
      bag.shuffle(rng);
      
      List<Tube> filled = List.generate(filledTubeCount, (_) => Tube([], capacity: ballsPerColor));
      int idx = 0;
      for (final b in bag) {
        while (filled[idx].isFull) {
          idx = (idx + 1) % filled.length;
        }
        filled[idx].balls.add(b);
        idx = (idx + 1) % filled.length;
      }
      final empties = List.generate(emptyTubes, (_) => Tube([], capacity: ballsPerColor));
      tubes = [...filled, ...empties];
    } else if (_gameType == GameType.spiral) {
      // Spiral pattern: colors arranged in spiral formation
      final int filledTubeCount = numberOfColors;
      final List<String> shuffled = List<String>.from(colors)..shuffle(rng);
      final usedColors = shuffled.take(filledTubeCount).toList();
      
      List<String> bag = [];
      for (int i = 0; i < filledTubeCount; i++) {
        for (int j = 0; j < ballsPerColor; j++) {
          // Spiral pattern: color changes based on position in spiral
          final int spiralPos = (i * ballsPerColor + j) % usedColors.length;
          bag.add(usedColors[spiralPos]);
        }
      }
      bag.shuffle(rng);
      
      List<Tube> filled = List.generate(filledTubeCount, (_) => Tube([], capacity: ballsPerColor));
      int idx = 0;
      for (final b in bag) {
        while (filled[idx].isFull) {
          idx = (idx + 1) % filled.length;
        }
        filled[idx].balls.add(b);
        idx = (idx + 1) % filled.length;
      }
      final empties = List.generate(emptyTubes, (_) => Tube([], capacity: ballsPerColor));
      tubes = [...filled, ...empties];
    } else {
      // Preset challenges – build near-solved then mix with limited rotations
      final int filledTubeCount = numberOfColors; // Use numberOfColors for consistency
      final List<String> chosenColors = List<String>.from(colors)..shuffle(rng);
      final usedColors = chosenColors.take(filledTubeCount).toList();
      List<Tube> filled = usedColors
          .map((c) => Tube(List.filled(ballsPerColor, c), capacity: ballsPerColor))
          .toList();

      // Difficulty mixing: number of rotations/moves
      int mixRounds;
      switch (_gameType) {
        case GameType.presetEasy:
          mixRounds = 2;
          break;
        case GameType.presetMedium:
          mixRounds = 5;
          break;
        case GameType.presetHard:
        default:
          mixRounds = 10;
          break;
      }
      // Rotate top k balls among a random ring of tubes each round
      for (int round = 0; round < mixRounds; round++) {
        final int ring = min(6 + rng.nextInt(5), filled.length); // ring size 6..10
        final int take = 1 + rng.nextInt(3); // take 1..2 (rarely 3) balls
        // snapshot tops
        List<List<String>> tops = [];
        for (int i = 0; i < ring; i++) {
          final t = filled[i];
          final int k = min(take, t.balls.length);
          tops.add(t.balls.sublist(t.balls.length - k));
          // Create a new list without the last k elements to avoid fixed-length list issues
          t.balls = t.balls.sublist(0, t.balls.length - k);
        }
        // place into next tube
        for (int i = 0; i < ring; i++) {
          final into = filled[(i + 1) % ring];
          into.balls.addAll(tops[i]);
        }
      }
      final empties = List.generate(emptyTubes, (_) => Tube([], capacity: ballsPerColor));
      tubes = [...filled, ...empties];
    }
    // Rebuild keys to match tubes length
    _tubeKeys = List.generate(tubes.length, (_) => GlobalKey());

    // Reset timer; start on first user move
    _resetTimer();
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
    final int m = d.inMinutes.remainder(600); // up to 999:59
    final int s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _ensureTimerStarted() {
    if (_startTime == null) {
      _startTimer();
    }
  }

  Future<void> _loadBests() async {
    final sp = await SharedPreferences.getInstance();
    for (final gt in GameType.values) {
      final tKey = 'best_time_${gt.name}';
      final sKey = 'best_score_${gt.name}';
      final int? secs = sp.getInt(tKey);
      final int? sc = sp.getInt(sKey);
      if (secs != null) _bestTime[gt] = Duration(seconds: secs);
      if (sc != null) _bestScore[gt] = sc;
    }
  }

  Future<void> _updateBestsIfBetter() async {
    final sp = await SharedPreferences.getInstance();
    final gt = _gameType;
    final Duration t = _elapsed;
    final int sc = _score;
    bool changed = false;
    if (!_bestTime.containsKey(gt) || t < _bestTime[gt]!) {
      _bestTime[gt] = t;
      await sp.setInt('best_time_${gt.name}', t.inSeconds);
      changed = true;
    }
    if (!_bestScore.containsKey(gt) || sc > _bestScore[gt]!) {
      _bestScore[gt] = sc;
      await sp.setInt('best_score_${gt.name}', sc);
      changed = true;
    }
    if (changed) setState(() {});
  }

  void _onTubeTap(int index) {
    if (selectedTube == null) {
      setState(() => selectedTube = index);
    } else {
      if (_moveBall(selectedTube!, index)) {
        setState(() {});
        if (_checkWin()) _showWinPopup();
      } else {
        // Show quick feedback when an invalid move is attempted via taps
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Invalid move: target must be empty or match top color, and not be full'),
            duration: Duration(milliseconds: 900),
          ),
        );
      }
      selectedTube = null;
    }
  }

  bool _moveBall(int from, int to) {
    if (tubes[from].balls.isEmpty) return false;
    String ball = tubes[from].balls.last;

    if (tubes[to].canAccept(ball)) {
      _ensureTimerStarted();
      tubes[from].balls.removeLast();
      tubes[to].balls.add(ball);
      // record move and increment
      _history.add(_Move(from, to, ball));
      moves += 1;
      return true;
    }
    return false;
  }

  void _undo() {
    if (_history.isEmpty) return;
    final last = _history.removeLast();
    // Reverse the move if valid
    if (tubes[last.to].balls.isNotEmpty &&
        tubes[last.to].balls.last == last.ball) {
      tubes[last.to].balls.removeLast();
      tubes[last.from].balls.add(last.ball);
      moves = (moves > 0) ? moves - 1 : 0;
      setState(() {});
    }
  }

  bool _checkWin() {
    return tubes.every((tube) =>
        tube.balls.isEmpty ||
        (tube.balls.length == ballsPerColor &&
            tube.balls.every((b) => b == tube.balls.first)));
  }

  void _showWinPopup() {
    _stopTimer();
    _updateBestsIfBetter();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("🎉 You Won!"),
        content: Text("All tubes are sorted!\nTime: ${_formatTime(_elapsed)}\nMoves: $moves"),
        actions: [
          TextButton(
            child: const Text("Play Again"),
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _initGame());
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ball Sort Puzzle"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Game', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  onPressed: () {
                    setState(() {
                      seed = DateTime.now().millisecondsSinceEpoch;
                      _initGame(seed: seed);
                    });
                  },
                ),
                // const SizedBox(width: 8),
                // Preset button with difficulty picker
                ElevatedButton.icon(
                  icon: const Icon(Icons.flag),
                  label: const Text('Recommended', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                    foregroundColor: Colors.green.shade800,
                  ),
                  onPressed: () async {
                    final GameType? sel = await showMenu<GameType>(
                      context: context,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      position: const RelativeRect.fromLTRB(200, 120, 0, 0),
                      items: [
                        PopupMenuItem(
                          value: GameType.shuffle,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Random Shuffle', style: TextStyle(fontWeight: FontWeight.w700)),
                              Text('Best for beginners', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: GameType.rainbow,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Rainbow Pattern', style: TextStyle(fontWeight: FontWeight.w700)),
                              Text('Colorful and fun', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: GameType.presetMedium,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Preset Medium', style: TextStyle(fontWeight: FontWeight.w700)),
                              Text('Balanced challenge', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    );
                    if (sel != null) {
                      setState(() {
                        _gameType = sel;
                        seed = DateTime.now().millisecondsSinceEpoch;
                        _initGame(seed: seed);
                      });
                    }
                  },
                ),
                // const SizedBox(width: 12),
                // Enhanced game type selector with better UI
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.games, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      const Text('Mode: ', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14)),
                      DropdownButton<GameType>(
                        value: _gameType,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 14),
                        iconEnabledColor: Colors.blue,
                        underline: const SizedBox.shrink(),
                        items: GameType.values.map((type) {
                          final info = gameTypeInfo[type]!;
                          return DropdownMenuItem(
                            value: type,
                            child: Tooltip(
                              message: info['description']!,
                              child: Text(
                                info['name']!,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (type) {
                          if (type == null) return;
                          setState(() {
                            _gameType = type;
                            seed = DateTime.now().millisecondsSinceEpoch;
                            _initGame(seed: seed);
                          });
                        },
                      ),
                    ],
                  ),
                ),
                // const SizedBox(width: 12),
                Text('Time: ' + _formatTime(_elapsed), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 16)),
                // const SizedBox(width: 12),
                Text('Moves: ' + moves.toString(), style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), // reset (same seed)
            tooltip: 'Reset',
            onPressed: () => setState(() => _initGame(seed: seed)),
          ),
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: _history.isEmpty ? null : () => _undo(),
          ),
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Shuffle (new seed)',
            onPressed: () {
              setState(() {
                seed = DateTime.now().millisecondsSinceEpoch;
                _initGame(seed: seed);
              });
            },
          ),
          PopupMenuButton<GameType>(
            icon: const Icon(Icons.tune),
            tooltip: 'Game Modes',
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onSelected: (type) {
              setState(() {
                _gameType = type;
                seed = DateTime.now().millisecondsSinceEpoch;
                _initGame(seed: seed);
              });
            },
            itemBuilder: (_) => GameType.values.map((type) {
              final info = gameTypeInfo[type]!;
              return PopupMenuItem(
                value: type,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      info['name']!,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      info['description']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
        builder: (context, constraints) {
          // Fully responsive grid that fits in both orientations without scrolling.
          // We choose the number of columns that maximizes tube width while ensuring
          // the total grid height fits in the viewport.
          const double hPad = 4; // horizontal padding used by GridView
          final media = MediaQuery.of(context);
          final bool isLandscape = media.orientation == Orientation.landscape;
          final double topPad = isLandscape ? 56.0 : 4.0;   // thinner padding for phones
          final double bottomPad = 4.0; // thinner bottom padding
          const double crossAxisSpacing = 3; // normal gaps
          const double mainAxisSpacing = 4; // normal gaps
          // TubeWidget inner margins (duplicate constants to keep solver self-contained)
          const double tubeBorderWidth = 1.5; // px (top + bottom)
          const double horizontalPadding = 2; // px on each side
          const double verticalPadding = 0; // px on each side
          const double safetyEps = 0.0; // keep math identical to TubeWidget

          final double availW = constraints.maxWidth - hPad * 2;
          final double availH = constraints.maxHeight - topPad - bottomPad;
          int bestCols = 1;
          double bestTileWidth = 0;
          double bestAspect = 0;

          for (int cols = 1; cols <= tubes.length; cols++) {
            // width per tile accounting for gaps
            final double totalGapsW = crossAxisSpacing * (cols - 1);
            final double tileW = (availW - totalGapsW) / cols;

            // Horizontal inner margins reduce inner width for a ball to fit
            final double horizontalMarginsPx =
                2 * (horizontalPadding + tubeBorderWidth);
            final double innerBallWidth =
                (tileW - horizontalMarginsPx).clamp(1.0, tileW);

            // Vertical requirement: stack of capacity balls (each innerBallWidth tall)
            // plus vertical borders/padding/safety to ensure no clip
            final double verticalFramePx =
                2 * (tubeBorderWidth + verticalPadding) + safetyEps;
            final double baseTileH = ballsPerColor * innerBallWidth + verticalFramePx;

            // rows required to place all tubes
            final int rows = (tubes.length / cols).ceil();
            final double totalGapsH = mainAxisSpacing * (rows - 1);
            final double gridH = rows * baseTileH + totalGapsH;

            if (gridH <= availH) {
              // Fits vertically; prefer larger tile width (bigger balls). If tie, prefer more columns.
              if (tileW > bestTileWidth ||
                  (tileW == bestTileWidth && cols > bestCols)) {
                bestCols = cols;
                bestTileWidth = tileW;
                bestAspect = tileW / baseTileH; // childAspectRatio = W/H
              }
            }
          }

          // Fallback: if nothing fits (extreme small screens), still render with at least 1 column
          if (bestTileWidth == 0) {
            bestCols = (tubes.length).clamp(1, tubes.length);
            final double totalGapsW = crossAxisSpacing * (bestCols - 1);
            final double tileW = (availW - totalGapsW) / bestCols;
            final double horizontalMarginsPx = 2 * (horizontalPadding + tubeBorderWidth);
            final double innerBallWidth = (tileW - horizontalMarginsPx).clamp(1.0, tileW);
            final double verticalFramePx = 2 * (tubeBorderWidth + verticalPadding) + safetyEps;
            final double baseTileH = ballsPerColor * innerBallWidth + verticalFramePx;
            bestTileWidth = tileW;
            bestAspect = tileW / baseTileH;
          }

          // Compute final tile dimensions for flight animation
          final double tileWForFlight = (availW - crossAxisSpacing * (bestCols - 1)) / bestCols;
          final double tileHForFlight = tileWForFlight / bestAspect;

          // Determine if grid needs vertical scrolling (rare on phones with very small height)
          final int rows = (tubes.length / bestCols).ceil();
          final double baseGridH = rows * (tileHForFlight) + mainAxisSpacing * (rows - 1);
          final bool gridScrollable = baseGridH > (constraints.maxHeight - topPad - bottomPad - 2);

          return GridView.builder(
            padding: EdgeInsets.fromLTRB(hPad, topPad, hPad, bottomPad),
            physics: gridScrollable ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: bestCols,
              mainAxisSpacing: mainAxisSpacing,
              crossAxisSpacing: crossAxisSpacing,
              childAspectRatio: bestAspect,
            ),
            itemCount: tubes.length,
            itemBuilder: (ctx, i) {
              return KeyedSubtree(
                key: _tubeKeys[i],
                child: TubeWidget(
                  tube: tubes[i],
                  highlight: selectedTube == i,
                  capacity: ballsPerColor,
                  tubeIndex: i,
                  suppressTopForColor: (_animatingToIndex == i) ? _animatingColor : null,
                  hintAccept: selectedTube != null &&
                      selectedTube != i &&
                      (tubes[selectedTube!].balls.isNotEmpty &&
                       tubes[i].canAccept(tubes[selectedTube!].balls.last)),
                  onTap: () => _onTubeTap(i),
                  onDrop: (from, to, ball) {
                    if (from == to) return;
                    if (tubes[from].balls.isEmpty) return;
                    // Only move if the dragged ball is actually on top
                    if (tubes[from].balls.last != ball) return;

                    // Commit-on-landing approach to avoid duplicates:
                    // If destination can accept, remove from source, animate to destination, then add on landing.
                    if (!tubes[to].canAccept(ball)) return;

                    // Precompute flight path using current positions (destination not yet modified)
                    final _FlightPath path = _computeFlightPath(
                      from: from,
                      to: to,
                      color: ball,
                      tileW: tileWForFlight,
                      tileH: tileHForFlight,
                    );

                    // Remove from source immediately; destination will be updated on landing
                    tubes[from].balls.removeLast();
                    setState(() {
                      _animatingToIndex = to;
                      _animatingColor = ball;
                    });

                    _startBallFlightWithPositions(
                      path,
                      onComplete: () {
                        // Add to destination on landing, then clear flags and check win
                        tubes[to].balls.add(ball);
                        setState(() {});
                        if (_checkWin()) _showWinPopup();
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      ),
    );
  }

  Offset _quadraticBezier(Offset p0, Offset p1, Offset p2, double t) {
    final double u = 1 - t;
    return Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
  }

  Offset _quadraticBezierClamped(Offset p0, Offset p1, Offset p2, double t) {
    final double u = 1 - t;
    final Offset result = Offset(
      u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx,
      u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy,
    );
    
    // Constrain Y position to never go below the destination point
    final double maxY = p2.dy;
    final double clampedY = result.dy.clamp(double.negativeInfinity, maxY);
    
    return Offset(result.dx, clampedY);
  }

  // --- Precomputed flight path variant ---
  _FlightPath _computeFlightPath({
    required int from,
    required int to,
    required String color,
    required double tileW,
    required double tileH,
  }) {
    final RenderBox? fromBox = _tubeKeys[from].currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? toBox = _tubeKeys[to].currentContext?.findRenderObject() as RenderBox?;
    if (fromBox == null || toBox == null) {
      return _FlightPath(start: Offset.zero, end: Offset.zero, color: color, slot: 0, tileH: tileH);
    }

    final Offset fromTopLeft = fromBox.localToGlobal(Offset.zero);
    final Offset toTopLeft = toBox.localToGlobal(Offset.zero);

    const double tubeBorderWidth = 1.5;
    const double horizontalPadding = 2;
    const double verticalPadding = 0;

    final double innerWidth = (tileW - 2 * (horizontalPadding + tubeBorderWidth)).clamp(1.0, tileW);
    final double slot = innerWidth;

    final int srcCount = tubes[from].balls.length;
    final int srcPlaceholders = (ballsPerColor - srcCount).clamp(0, ballsPerColor);
    final double srcCenterY = verticalPadding + tubeBorderWidth + srcPlaceholders * slot + slot / 2;

    final int dstCount = tubes[to].balls.length;
    // The incoming ball will be placed at the top of existing balls
    // Calculate position from top: placeholders + existing balls + new ball position
    final int dstPlaceholdersAfter = (ballsPerColor - (dstCount + 1)).clamp(0, ballsPerColor);
    // Position from top: border + placeholders + half slot for center of new ball position
    final double dstCenterY = verticalPadding + tubeBorderWidth + (dstPlaceholdersAfter * slot) + (dstCount * slot) + slot / 2;

    final Offset start = fromTopLeft + Offset(tileW / 2, srcCenterY);
    final Offset end = toTopLeft + Offset(tileW / 2, dstCenterY);
    return _FlightPath(start: start, end: end, color: color, slot: slot, tileH: tileH);
  }

  void _startBallFlightWithPositions(_FlightPath path, {VoidCallback? onComplete}) {
    if (path.slot <= 0) return;
    // Cancel any in-progress animation/overlay to avoid duplicate artifacts
    _flightCtrl?.stop();
    _flightEntry?.remove();
    _flightEntry = null;
    _flightCtrl?.dispose();
    _flightCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    final CurvedAnimation curve = CurvedAnimation(parent: _flightCtrl!, curve: Curves.easeInOutCubic);

    final OverlayState? overlay = Overlay.of(context);
    _flightEntry?.remove();
    _flightEntry = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
          animation: curve,
          builder: (context, child) {
            final t = curve.value;
            final double dx = (path.end.dx - path.start.dx).abs();
            // Reduce lift significantly and ensure control point doesn't create overshoot
            final double lift = (path.tileH * 0.08) + 0.02 * dx; // Much smaller lift
            final double controlY = min(path.start.dy, path.end.dy) - lift;
            // Ensure control point Y is never below destination Y to prevent overshoot
            final double safeControlY = controlY.clamp(double.negativeInfinity, path.end.dy - 10);
            final Offset ctrl = Offset(
              (path.start.dx + path.end.dx) / 2,
              safeControlY,
            );
            // Use a modified curve that ensures the ball lands exactly at the destination
            final Offset pos = _quadraticBezierClamped(path.start, ctrl, path.end, t);
            final double scale = 0.94 + 0.08 * (1 - (2 * (t - 0.5)).abs());
            return Positioned(
              left: pos.dx - (path.slot * 0.5),
              top: pos.dy - (path.slot * 0.5),
              child: Opacity(
                opacity: 0.95,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: path.slot,
                    height: path.slot,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 4))],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/balls/${path.color}.png', fit: BoxFit.cover),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    overlay?.insert(_flightEntry!);
    _flightCtrl!.forward().whenComplete(() {
      _flightEntry?.remove();
      _flightEntry = null;
      // Complete the logical move (add to destination), then clear animation flags
      onComplete?.call();
      setState(() {
        _animatingToIndex = null;
        _animatingColor = null;
      });
      // Dispose controller instance
      _flightCtrl?.dispose();
      _flightCtrl = null;
    });
  }

}

class _FlightPath {
  final Offset start;
  final Offset end;
  final String color;
  final double slot;
  final double tileH;
  _FlightPath({required this.start, required this.end, required this.color, required this.slot, required this.tileH});
}

class _Move {
  final int from;
  final int to;
  final String ball;
  _Move(this.from, this.to, this.ball);
}
