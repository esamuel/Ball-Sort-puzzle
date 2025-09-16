import 'package:flutter/material.dart';
import '../services/preferences.dart';
import '../services/feedback_service.dart';
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
            subtitle: const Text('Move to empty tubes or onto same-color top'),
            onChanged: (v) => setState(() => _moveRule = v!),
          ),
          RadioListTile<String>(
            value: 'hard',
            groupValue: _moveRule,
            title: const Text('Move Rule: Hard'),
            subtitle: const Text('Only onto same-color top (no empty tubes)'),
            onChanged: (v) => setState(() => _moveRule = v!),
          ),
          const Divider(),
          ListTile(
            title: const Text('Tube Count'),
            subtitle: Text('$_tubeCount tubes'),
            trailing: DropdownButton<int>(
              value: _tubeCount,
              items: const [9, 11, 13, 15]
                  .map((e) => DropdownMenuItem<int>(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (v) => setState(() => _tubeCount = v ?? _tubeCount),
            ),
          ),
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
