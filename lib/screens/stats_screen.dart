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
      appBar: AppBar(title: const Text('Statistics')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatTile(label: 'Games Started', value: s['gamesStarted']!.toString()),
                _StatTile(label: 'Wins', value: s['wins']!.toString()),
                _StatTile(label: 'Losses', value: s['losses']!.toString()),
                const Divider(),
                _StatTile(
                  label: 'Best Time',
                  value: s['bestTime'] == 0 ? '-' : _fmtTime(s['bestTime']!),
                ),
                _StatTile(
                  label: 'Best Moves',
                  value: s['bestMoves'] == 0 ? '-' : s['bestMoves']!.toString(),
                ),
                const Divider(),
                _StatTile(
                  label: 'Average Time',
                  value: (s['wins']! + s['losses']! > 0 && s['totalTime']! > 0)
                      ? _fmtTime(s['totalTime']! ~/ (s['wins']! + s['losses']!))
                      : '-',
                ),
                _StatTile(
                  label: 'Average Moves (wins only)',
                  value: (s['wins']! > 0 && s['totalMoves']! > 0)
                      ? (s['totalMoves']! ~/ s['wins']!).toString()
                      : '-',
                ),
                const Divider(),
                _StatTile(
                  label: 'Win Rate',
                  value: (() {
                    final total = s['wins']! + s['losses']!;
                    if (total == 0) return '-';
                    final rate = (s['wins']! * 100 / total);
                    return '${rate.toStringAsFixed(1)}%';
                  })(),
                ),
              ],
            ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
