import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Play'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _HelpCard(
                icon: Icons.flag,
                title: 'Goal',
                content:
                    'Sort the balls so that each tube contains balls of a single color. You win when all tubes are either empty or perfectly sorted.',
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              _HelpCard(
                icon: Icons.touch_app,
                title: 'Controls',
                content:
                    'Two ways to play:\n\n• Tap Mode: Select a source tube, then tap destination\n• Drag Mode: Drag the TOP ball directly to destination tube',
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              _HelpCard(
                icon: Icons.rule,
                title: 'Difficulty Rules',
                content:
                    '🔵 Beginner: 7 tubes, 5 balls per color - perfect for learning!\n\n🟢 Easy: 9 tubes - move to any tube that is not full\n\n🟡 Medium: 11 tubes - move to empty tubes OR onto matching color\n\n🟠 Hard: 13 tubes - only onto same-color top (no empty moves)\n\n🔴 Expert: 15 tubes - maximum challenge!',
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              _HelpCard(
                icon: Icons.help_outline,
                title: 'Stuck? No Problem!',
                content:
                    'When no valid moves exist:\n\n• Use the Reshuffle button (3 times per game)\n• Try the Undo button (↶) to backtrack\n• Change difficulty rules in settings',
                color: Colors.purple,
              ),
              const SizedBox(height: 16),
              _HelpCard(
                icon: Icons.lightbulb,
                title: 'Pro Tips',
                content:
                    '💡 Use empty tubes strategically for temporary storage\n\n💡 Build complete color stacks from bottom up\n\n💡 Consolidate partial stacks before spreading\n\n💡 Plan moves ahead - think like Tetris!',
                color: Colors.amber,
              ),
              const SizedBox(height: 16),
              _HelpCard(
                icon: Icons.quiz,
                title: 'Common Questions',
                content:
                    'Q: Why can\'t I drop here?\nA: Destination is full or violates current difficulty rule\n\nQ: Why did the game end?\nA: No valid moves remained and no reshuffles left\n\nQ: How do I change difficulty?\nA: Tap the gear icon (⚙️) in the top bar to select 7/9/11/13/15 tubes\n\nQ: What\'s the easiest setting?\nA: Start with Beginner (7 tubes) - perfect for learning!',
                color: Colors.teal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  const _HelpCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    fontSize: 14,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
