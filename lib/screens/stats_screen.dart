import 'package:flutter/material.dart';
import '../services/stats_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<String, int>? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await StatsService.load();
    setState(() => _stats = s);
  }

  String _fmtTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60);
    final s = (totalSeconds % 60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Statistics'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Game Summary Section
                    _buildSection(
                      context,
                      'Game Summary',
                      Icons.games,
                      [
                        _StatCard(
                          icon: Icons.play_arrow,
                          label: 'Games Started',
                          value: s['gamesStarted']!.toString(),
                          color: Colors.blue,
                        ),
                        _StatCard(
                          icon: Icons.check_circle,
                          label: 'Wins',
                          value: s['wins']!.toString(),
                          color: Colors.green,
                        ),
                        _StatCard(
                          icon: Icons.cancel,
                          label: 'Losses',
                          value: s['losses']!.toString(),
                          color: Colors.red,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Personal Best Section
                    _buildSection(
                      context,
                      'Personal Best',
                      Icons.emoji_events,
                      [
                        _StatCard(
                          icon: Icons.timer,
                          label: 'Best Time',
                          value: s['bestTime'] == 0
                              ? 'No record'
                              : _fmtTime(s['bestTime']!),
                          color: Colors.orange,
                        ),
                        _StatCard(
                          icon: Icons.trending_down,
                          label: 'Best Moves',
                          value: s['bestMoves'] == 0
                              ? 'No record'
                              : s['bestMoves']!.toString(),
                          color: Colors.purple,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Averages Section
                    _buildSection(
                      context,
                      'Averages',
                      Icons.analytics,
                      [
                        _StatCard(
                          icon: Icons.access_time,
                          label: 'Average Time',
                          value: (s['wins']! + s['losses']! > 0 &&
                                  s['totalTime']! > 0)
                              ? _fmtTime(s['totalTime']! ~/
                                  (s['wins']! + s['losses']!))
                              : 'No data',
                          color: Colors.teal,
                        ),
                        _StatCard(
                          icon: Icons.swap_horiz,
                          label: 'Average Moves',
                          value: (s['wins']! > 0 && s['totalMoves']! > 0)
                              ? (s['totalMoves']! ~/ s['wins']!).toString()
                              : 'No data',
                          color: Colors.indigo,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Win Rate Section
                    _buildWinRateSection(context, s),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection(BuildContext context, String title, IconData icon,
      List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.deepPurple, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children.map((child) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: child,
            )),
      ],
    );
  }

  Widget _buildWinRateSection(BuildContext context, Map<String, int> s) {
    final total = s['wins']! + s['losses']!;
    final winRate = total == 0 ? 0.0 : (s['wins']! * 100 / total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.percent, color: Colors.deepPurple, size: 24),
            const SizedBox(width: 8),
            Text(
              'Win Rate',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.withOpacity(0.1),
                Colors.green.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                total == 0
                    ? 'No games completed'
                    : '${winRate.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
              ),
              if (total > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${s['wins']} wins out of $total games',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green[600],
                      ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
