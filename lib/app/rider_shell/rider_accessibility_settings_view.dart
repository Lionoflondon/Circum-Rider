import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../rider_design/rider_ui.dart';

class RiderAccessibilitySettingsView extends StatefulWidget {
  const RiderAccessibilitySettingsView({super.key});

  static const appearanceKey = 'rider.accessibility.appearance';
  static const textSizeKey = 'rider.accessibility.textSize';
  static const highContrastKey = 'rider.accessibility.highContrast';
  static const reduceMotionKey = 'rider.accessibility.reduceMotion';
  static const screenReaderKey = 'rider.accessibility.screenReader';

  @override
  State<RiderAccessibilitySettingsView> createState() =>
      _RiderAccessibilitySettingsViewState();
}

class _RiderAccessibilitySettingsViewState
    extends State<RiderAccessibilitySettingsView> {
  String _appearance = 'system';
  String _textSize = 'default';
  bool _highContrast = false;
  bool _reduceMotion = false;
  bool _screenReader = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _appearance =
          prefs.getString(RiderAccessibilitySettingsView.appearanceKey) ??
              'system';
      _textSize = prefs.getString(RiderAccessibilitySettingsView.textSizeKey) ??
          'default';
      _highContrast =
          prefs.getBool(RiderAccessibilitySettingsView.highContrastKey) ??
              false;
      _reduceMotion =
          prefs.getBool(RiderAccessibilitySettingsView.reduceMotionKey) ??
              false;
      _screenReader =
          prefs.getBool(RiderAccessibilitySettingsView.screenReaderKey) ??
              false;
      _loading = false;
    });
  }

  Future<void> _setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
    if (!mounted) return;
    setState(() {
      if (key == RiderAccessibilitySettingsView.appearanceKey) {
        _appearance = value;
      } else if (key == RiderAccessibilitySettingsView.textSizeKey) {
        _textSize = value;
      }
    });
  }

  Future<void> _setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    if (!mounted) return;
    setState(() {
      if (key == RiderAccessibilitySettingsView.highContrastKey) {
        _highContrast = value;
      } else if (key == RiderAccessibilitySettingsView.reduceMotionKey) {
        _reduceMotion = value;
      } else if (key == RiderAccessibilitySettingsView.screenReaderKey) {
        _screenReader = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RiderPalette.background,
      appBar: AppBar(
        title: const Text('Accessibility'),
        backgroundColor: RiderPalette.background,
        foregroundColor: RiderPalette.paper,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: RiderPalette.blue),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
              children: [
                _HeaderCard(
                  highContrast: _highContrast,
                  reduceMotion: _reduceMotion,
                ),
                const SizedBox(height: 16),
                _ChoiceCard(
                  title: 'Appearance',
                  subtitle: 'Choose how the Rider app follows display mode.',
                  value: _appearance,
                  options: const [
                    _ChoiceOption('system', 'Follow System'),
                    _ChoiceOption('dark', 'Dark'),
                    _ChoiceOption('light', 'Light'),
                  ],
                  onChanged: (value) => _setString(
                    RiderAccessibilitySettingsView.appearanceKey,
                    value,
                  ),
                ),
                const SizedBox(height: 14),
                _ChoiceCard(
                  title: 'Text Size',
                  subtitle: 'Adjust Rider interface text where supported.',
                  value: _textSize,
                  options: const [
                    _ChoiceOption('small', 'Small'),
                    _ChoiceOption('default', 'Default'),
                    _ChoiceOption('large', 'Large'),
                  ],
                  onChanged: (value) => _setString(
                    RiderAccessibilitySettingsView.textSizeKey,
                    value,
                  ),
                ),
                const SizedBox(height: 14),
                _ToggleCard(
                  title: 'High Contrast',
                  subtitle:
                      'Increase separation between text, icons and glass surfaces.',
                  value: _highContrast,
                  onChanged: (value) => _setBool(
                    RiderAccessibilitySettingsView.highContrastKey,
                    value,
                  ),
                ),
                const SizedBox(height: 14),
                _ToggleCard(
                  title: 'Reduce Motion',
                  subtitle: 'Limit decorative transitions where supported.',
                  value: _reduceMotion,
                  onChanged: (value) => _setBool(
                    RiderAccessibilitySettingsView.reduceMotionKey,
                    value,
                  ),
                ),
                const SizedBox(height: 14),
                _ToggleCard(
                  title: 'Screen Reader Optimisations',
                  subtitle:
                      'Prioritise clearer labels and simpler announcement order.',
                  value: _screenReader,
                  onChanged: (value) => _setBool(
                    RiderAccessibilitySettingsView.screenReaderKey,
                    value,
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.highContrast,
    required this.reduceMotion,
  });

  final bool highContrast;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      radius: 24,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: RiderPalette.blue.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: RiderPalette.blue.withValues(alpha: .24),
              ),
            ),
            child: const Icon(
              Icons.accessibility_new_rounded,
              color: RiderPalette.blue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rider accessibility',
                  style: TextStyle(
                    color: RiderPalette.paper,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _summary,
                  style: const TextStyle(
                    color: RiderPalette.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _summary {
    if (highContrast && reduceMotion) {
      return 'High contrast and reduced motion are enabled.';
    }
    if (highContrast) return 'High contrast is enabled.';
    if (reduceMotion) return 'Reduced motion is enabled.';
    return 'Tune text, contrast, motion and assistive labels.';
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final String value;
  final List<_ChoiceOption> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return RiderGlassSurface(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(title: title, subtitle: subtitle),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(option.label),
                  selected: value == option.value,
                  onSelected: (_) => onChanged(option.value),
                  selectedColor: RiderPalette.blue.withValues(alpha: .24),
                  backgroundColor: Colors.white.withValues(alpha: .04),
                  side: BorderSide(
                    color: value == option.value
                        ? RiderPalette.blue.withValues(alpha: .6)
                        : Colors.white.withValues(alpha: .1),
                  ),
                  labelStyle: TextStyle(
                    color: value == option.value
                        ? RiderPalette.paper
                        : RiderPalette.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: title,
      child: RiderGlassSurface(
        radius: 24,
        padding: EdgeInsets.zero,
        child: SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: RiderPalette.blue,
          activeTrackColor: RiderPalette.blue.withValues(alpha: .28),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          title: Text(
            title,
            style: const TextStyle(
              color: RiderPalette.paper,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: const TextStyle(color: RiderPalette.muted, height: 1.35),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: RiderPalette.paper,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: RiderPalette.muted, height: 1.35),
          ),
        ],
      );
}

class _ChoiceOption {
  const _ChoiceOption(this.value, this.label);

  final String value;
  final String label;
}
