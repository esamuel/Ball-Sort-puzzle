import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('How to Play')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Section(
            title: 'Goal',
            body:
                'Sort the balls so that each tube contains balls of a single color. You win when all tubes are either empty or perfectly sorted.',
          ),
          _Section(
            title: 'Controls',
            body:
                'Tap: Select a source tube, then tap a destination tube.\nDrag: Drag the TOP ball of a tube onto a valid destination tube.',
          ),
          _Section(
            title: 'Valid Moves',
            body:
                'Easy: Move to any tube that is not full.\nMedium: Move to empty tubes or onto a tube whose top ball matches the moving color.\nHard: Only onto same-color top (no empty tube moves).',
          ),
          _Section(
            title: 'Stuck?',
            body:
                'If no valid moves exist, a dialog appears. You have limited Reshuffles that randomly re-distribute balls among the playable tubes (excluding the rightmost empty tubes).',
          ),
          _Section(
            title: 'Tips',
            body:
                '- Use empty tubes to open space.\n- Try to build color stacks from the bottom up.\n- Consolidate partial stacks before spreading to other tubes.',
          ),
          _Section(
            title: 'FAQ',
            body:
                'Why can\'t I drop here? The destination is either full or not valid under the current move rule.\nWhy did the game end? No valid moves remained and no reshuffles were left.',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
