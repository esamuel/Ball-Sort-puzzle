import 'package:flutter/material.dart';
import '../services/preferences.dart';
import '../services/feedback_service.dart';
import '../services/audio_service.dart';
import '../services/premium_service.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _moveRule = 'medium';
  int _tubeCount = 15;
  String _themeMode = 'system';
  bool _sound = true;
  bool _haptics = true;
  double _musicVolume = 0.15;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final mr = await AppPrefs.loadMoveRule();
    final tc = await AppPrefs.loadTubeCount();
    final tm = await AppPrefs.loadThemeMode();
    final snd = await AppPrefs.loadSoundEnabled();
    final hpt = await AppPrefs.loadHapticsEnabled();
    setState(() {
      _moveRule = mr ?? 'medium';
      _tubeCount = tc ?? 15;
      _themeMode = tm ?? 'system';
      _sound = snd;
      _haptics = hpt;
    });
    // Initialize UI volume from current background player setting
    // Note: We don't persist volume yet; using a sensible default.
  }

  Future<void> _save() async {
    await AppPrefs.saveMoveRule(_moveRule);
    await AppPrefs.saveTubeCount(_tubeCount);
    await AppPrefs.saveThemeMode(_themeMode);
    await AppPrefs.saveSoundEnabled(_sound);
    await AppPrefs.saveHapticsEnabled(_haptics);
    // Apply theme immediately
    await BallSortApp.of(context)?.refreshTheme();
    // Reload feedback settings (sounds/haptics)
    await FeedbackService.reload();
  }

  void _showPremiumUpgrade() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const ListTile(title: Text('Gameplay')),
          RadioListTile<String>(
            value: 'easy',
            groupValue: _moveRule,
            title: const Text('Move Rule: Easy'),
            subtitle: const Text('Move to any tube that is not full'),
            onChanged: (v) => setState(() => _moveRule = v!),
          ),
          RadioListTile<String>(
            value: 'medium',
            groupValue: _moveRule,
            title: const Text('Move Rule: Medium'),
            subtitle:
                const Text('Same-color top, or to empty if moving run ≥ 2'),
            onChanged: (v) => setState(() => _moveRule = v!),
          ),
          RadioListTile<String>(
            value: 'hard',
            groupValue: _moveRule,
            title: const Text('Move Rule: Hard'),
            subtitle:
                const Text('Same-color top, or to empty if moving run ≥ 3'),
            onChanged: (v) => setState(() => _moveRule = v!),
          ),
          RadioListTile<String>(
            value: 'expert',
            groupValue: _moveRule,
            title: const Text('Move Rule: Expert'),
            subtitle: const Text(
                'Only onto same-color top; empty only if tube is mono-color'),
            onChanged: (v) => setState(() => _moveRule = v!),
          ),
          const Divider(),
          ListTile(
            title: const Text('Tube Count'),
            subtitle: Text('$_tubeCount tubes'),
            trailing: DropdownButton<int>(
              value: _tubeCount,
              items: const [7, 9, 11, 13, 15]
                  .map(
                      (e) => DropdownMenuItem<int>(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (v) => setState(() => _tubeCount = v ?? _tubeCount),
            ),
          ),
          const Divider(),
          const ListTile(title: Text('Audio')),
          SwitchListTile(
            title: const Text('Sound Effects'),
            subtitle: const Text('Move and win sounds'),
            value: AudioService.soundEnabled,
            onChanged: (value) async {
              await AudioService.toggleSound();
              setState(() {});
            },
          ),
          SwitchListTile(
            title: const Text('Background Music'),
            subtitle: const Text('Ambient background music'),
            value: AudioService.musicEnabled,
            onChanged: (value) async {
              await AudioService.toggleMusic();
              setState(() {});
            },
          ),
          ListTile(
            title: const Text('Ambient Volume'),
            subtitle: Text('${(_musicVolume * 100).round()}%'),
            trailing: SizedBox(
              width: 180,
              child: Slider(
                min: 0.0,
                max: 1.0,
                divisions: 20,
                value: _musicVolume,
                onChanged: (v) {
                  setState(() => _musicVolume = v);
                },
                onChangeEnd: (v) async {
                  await AudioService.setBackgroundVolume(v);
                },
              ),
            ),
          ),
          const Divider(),
          const ListTile(title: Text('Premium')),
          ListTile(
            leading: Icon(
              PremiumService.isPremium ? Icons.star : Icons.star_border,
              color: PremiumService.isPremium ? Colors.amber : Colors.grey,
            ),
            title: Text(
              PremiumService.isPremium
                  ? 'Premium Active'
                  : 'Upgrade to Premium',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: PremiumService.isPremium ? Colors.amber : Colors.blue,
              ),
            ),
            subtitle: Text(
              PremiumService.isPremium
                  ? 'All features unlocked'
                  : 'Unlock all difficulty levels and remove ads',
            ),
            trailing: PremiumService.isPremium
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: PremiumService.isPremium ? null : _showPremiumUpgrade,
          ),
          if (PremiumService.isPremium) ...[
            const ListTile(
              leading: Icon(Icons.check, color: Colors.green),
              title: Text('All difficulty levels unlocked'),
              dense: true,
            ),
            const ListTile(
              leading: Icon(Icons.check, color: Colors.green),
              title: Text('Ad-free experience'),
              dense: true,
            ),
            const ListTile(
              leading: Icon(Icons.check, color: Colors.green),
              title: Text('Detailed statistics'),
              dense: true,
            ),
            const ListTile(
              leading: Icon(Icons.check, color: Colors.green),
              title: Text('Custom themes'),
              dense: true,
            ),
            const ListTile(
              leading: Icon(Icons.check, color: Colors.green),
              title: Text('Unlimited undo moves'),
              dense: true,
            ),
          ],
          const Divider(),
          const ListTile(title: Text('Appearance')),
          RadioListTile<String>(
            value: 'system',
            groupValue: _themeMode,
            title: const Text('Theme: System'),
            onChanged: (v) => setState(() => _themeMode = v!),
          ),
          RadioListTile<String>(
            value: 'light',
            groupValue: _themeMode,
            title: const Text('Theme: Light'),
            onChanged: (v) => setState(() => _themeMode = v!),
          ),
          RadioListTile<String>(
            value: 'dark',
            groupValue: _themeMode,
            title: const Text('Theme: Dark'),
            onChanged: (v) => setState(() => _themeMode = v!),
          ),
          const Divider(),
          const ListTile(title: Text('Feedback')),
          SwitchListTile(
            title: const Text('Sounds'),
            value: _sound,
            onChanged: (v) => setState(() => _sound = v),
          ),
          SwitchListTile(
            title: const Text('Haptics'),
            value: _haptics,
            onChanged: (v) => setState(() => _haptics = v),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () async {
              await _save();
              if (mounted) Navigator.of(context).pop();
            },
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
