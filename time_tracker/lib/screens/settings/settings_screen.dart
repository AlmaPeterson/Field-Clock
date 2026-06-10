import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _rateController = TextEditingController();
  String _rounding = '15';
  bool _showEarnings = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('worker_name') ?? '';
    _rateController.text =
        (prefs.getDouble('hourly_rate') ?? 0.0).toString();
    _rounding = prefs.getString('rounding') ?? '15';
    _showEarnings = prefs.getBool('show_earnings') ?? false;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'worker_name', _nameController.text.trim());
    await prefs.setDouble(
        'hourly_rate', double.tryParse(_rateController.text) ?? 0.0);
    await prefs.setString('rounding', _rounding);
    await prefs.setBool('show_earnings', _showEarnings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.theme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save',
                style: TextStyle(
                    color: theme.primary,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // ── Worker ──────────────────────────────────
                _SectionHeader('WORKER'),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration:
                      const InputDecoration(labelText: 'Your Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Default Hourly Rate (\$)'),
                ),

                const SizedBox(height: 28),

                // ── Appearance ──────────────────────────────
                _SectionHeader('APPEARANCE'),
                const SizedBox(height: 12),

                // Dark / Light toggle
                _SettingsTile(
                  label: 'Theme',
                  child: Row(
                    children: [
                      _ThemeToggle(
                        label: 'Dark',
                        icon: Icons.dark_mode,
                        selected: theme.isDark,
                        onTap: () =>
                            themeProvider.setDark(true),
                      ),
                      const SizedBox(width: 8),
                      _ThemeToggle(
                        label: 'Light',
                        icon: Icons.light_mode,
                        selected: !theme.isDark,
                        onTap: () =>
                            themeProvider.setDark(false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Accent color picker
                _SettingsTile(
                  label: 'Accent Color',
                  child: Wrap(
                    spacing: 10,
                    children: AppColors.accents.entries
                        .map((e) => _ColorDot(
                              color: e.value,
                              name: e.key,
                              selected:
                                  theme.accent == e.value,
                              onTap: () =>
                                  themeProvider.setAccent(e.key),
                            ))
                        .toList(),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Time Tracking ────────────────────────────
                _SectionHeader('TIME TRACKING'),
                const SizedBox(height: 12),

                _SettingsTile(
                  label: 'Time Rounding',
                  child: Row(
                    children: ['15', '30'].map((val) {
                      final selected = _rounding == val;
                      return Padding(
                        padding:
                            const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _rounding = val),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? theme.primary
                                  : theme.surfaceAlt,
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${val}m',
                              style: TextStyle(
                                color: selected
                                    ? Colors.black
                                    : theme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                _SettingsTile(
                  label: 'Show Earnings in Summaries',
                  child: Switch(
                    value: _showEarnings,
                    activeColor: theme.primary,
                    onChanged: (v) =>
                        setState(() => _showEarnings = v),
                  ),
                ),

                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _save,
                  child: const Text('Save Settings'),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelLarge);
}

class _SettingsTile extends StatelessWidget {
  final String label;
  final Widget child;
  _SettingsTile({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().theme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: theme.onSurface)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeToggle({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().theme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color:
              selected ? theme.primary : theme.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? Colors.black
                    : theme.onSurface),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.black
                    : theme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Tooltip(
          message: name,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Colors.white
                    : Colors.transparent,
                width: 3,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: color.withOpacity(0.6),
                          blurRadius: 8,
                          spreadRadius: 1)
                    ]
                  : [],
            ),
            child: selected
                ? const Icon(Icons.check,
                    color: Colors.white, size: 18)
                : null,
          ),
        ),
      );
}