import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // App Info Card
              _AboutCard(
                icon: Icons.sports_esports,
                title: 'Ball Sort Puzzle',
                content:
                    'Version 1.0.0\n\nA relaxing and challenging puzzle game featuring intuitive tap and drag-and-drop controls, multiple difficulty levels, and responsive design for all devices.',
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 16),

              // Features Card
              _AboutCard(
                icon: Icons.star,
                title: 'Game Features',
                content:
                    '🎮 Two control modes: Tap & Drag\n🎯 Multiple difficulty rules\n📱 Optimized for mobile & tablet\n⏱️ Timer and move tracking\n📊 Detailed statistics\n🔄 Undo and reshuffle options',
                color: Colors.blue,
              ),
              const SizedBox(height: 16),

              // Privacy Card
              _AboutCard(
                icon: Icons.privacy_tip,
                title: 'Privacy Policy',
                content:
                    '🔒 Your data stays on your device\n📱 No personal information collected\n🚫 No ads or tracking\n💾 Only game progress is saved locally\n🔐 Completely offline gameplay',
                color: Colors.green,
              ),
              const SizedBox(height: 16),

              // Support Card
              _AboutCard(
                icon: Icons.support_agent,
                title: 'Support & Feedback',
                content:
                    'Need help or have suggestions?\n\n📧 Email: support@ballsortgame.com\n🐛 Report bugs or request features\n⭐ Rate us on the App Store\n💡 Your feedback helps improve the game!',
                color: Colors.orange,
                actions: [
                  _ActionButton(
                    icon: Icons.email,
                    label: 'Contact Support',
                    onTap: () => _copyEmail(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Credits Card
              _AboutCard(
                icon: Icons.favorite,
                title: 'Credits',
                content:
                    '👨‍💻 Developer: Samuel Eskenasy\n🎨 Game Design & Development\n🎵 Sound Effects & Audio\n🎯 Game Logic & AI\n📱 Mobile Optimization\n\nMade with ❤️ using Flutter',
                color: Colors.red,
              ),

              const SizedBox(height: 32),

              // Footer
              Text(
                '© 2024 Ball Sort Puzzle\nAll rights reserved',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _copyEmail(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: 'support@ballsortgame.com'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;
  final List<Widget>? actions;

  const _AboutCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
    this.actions,
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
            if (actions != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: actions!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
