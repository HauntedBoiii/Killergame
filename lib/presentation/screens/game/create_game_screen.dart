import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/data/models/game.dart';
import 'package:moerderspiel/presentation/providers/game_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/app_button.dart';
import 'package:moerderspiel/presentation/widgets/common/app_text_field.dart';

class CreateGameScreen extends ConsumerStatefulWidget {
  const CreateGameScreen({super.key});

  @override
  ConsumerState<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends ConsumerState<CreateGameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  GameMode _mode = GameMode.task;
  bool _requireAdmin = false;
  bool _teamMode = false;
  bool _loading = false;
  int _initialTasksPerPlayer = 1;
  bool _tasksAreSingleUse = false;

  final List<TextEditingController> _safeZoneCtrl = [];
  final List<ProtectionTime> _protectionTimes = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final c in _safeZoneCtrl) c.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final settings = GameSettings(
        teamMode: _teamMode,
        safeZones: _safeZoneCtrl.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
        protectionTimes: _protectionTimes,
        requireAdminConfirmation: _requireAdmin,
        initialTasksPerPlayer: _initialTasksPerPlayer,
        tasksAreSingleUse: _tasksAreSingleUse,
      );
      final game = await ref.read(gameRepositoryProvider).createGame(
            name: _nameCtrl.text.trim(),
            mode: _mode,
            settings: settings,
          );
      if (mounted) context.pushReplacement('/game/${game.id}/lobby');
    } catch (e) {
      if (mounted) showSnack(context, 'Fehler: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Spiel erstellen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppTextField(
              controller: _nameCtrl,
              label: 'Spielname',
              prefixIcon: Icons.sports_esports,
              validator: (v) => v == null || v.trim().isEmpty ? 'Pflichtfeld' : null,
            ),
            const SizedBox(height: 24),

            Text('Eliminierungsmodus', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _ModeCard(
                  selected: _mode == GameMode.task,
                  icon: Icons.task_alt,
                  title: 'Aufgaben',
                  subtitle: 'Geheime Aufgaben pro Spieler',
                  onTap: () => setState(() => _mode = GameMode.task),
                )),
                const SizedBox(width: 12),
                Expanded(child: _ModeCard(
                  selected: _mode == GameMode.object,
                  icon: Icons.inventory_2_outlined,
                  title: 'Gegenstand',
                  subtitle: 'Bestimmten Gegenstand übergeben',
                  onTap: () => setState(() => _mode = GameMode.object),
                )),
              ],
            ),

            const SizedBox(height: 24),
            _SettingsCard(
              icon: Icons.settings_outlined,
              label: 'Allgemein',
              children: [
                _SettingsTile(
                  icon: Icons.shield_outlined,
                  iconColor: Colors.blue,
                  title: 'Admin-Bestätigung',
                  subtitle: 'Kills müssen vom Admin bestätigt werden',
                  trailing: Switch(
                    value: _requireAdmin,
                    onChanged: (v) => setState(() => _requireAdmin = v),
                  ),
                ),
                const Divider(height: 1, indent: 16),
                _SettingsTile(
                  icon: Icons.group_outlined,
                  iconColor: Colors.teal,
                  title: 'Teammodus',
                  subtitle: 'Noch nicht implementiert (Dummy)',
                  trailing: Switch(
                    value: _teamMode,
                    onChanged: (v) => setState(() => _teamMode = v),
                  ),
                ),
              ],
            ),

            if (_mode == GameMode.task) ...[
              const SizedBox(height: 16),
              _SettingsCard(
                icon: Icons.task_alt,
                label: 'Aufgaben',
                iconColor: Colors.orange,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.format_list_numbered, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            const Text('Aufgaben pro Spieler',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Padding(
                          padding: EdgeInsets.only(left: 24),
                          child: Text('Startmenge bei Spielbeginn',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                        const SizedBox(height: 14),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 1, label: Text('1')),
                            ButtonSegment(value: 2, label: Text('2')),
                            ButtonSegment(value: 3, label: Text('3')),
                          ],
                          selected: {_initialTasksPerPlayer},
                          onSelectionChanged: (s) =>
                              setState(() => _initialTasksPerPlayer = s.first),
                          expandedInsets: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.electric_bolt_outlined,
                    iconColor: Colors.orange,
                    title: 'Aufgaben sind Einweg',
                    subtitle: 'Benutzte Aufgaben sind verbraucht',
                    trailing: Switch(
                      value: _tasksAreSingleUse,
                      onChanged: (v) => setState(() => _tasksAreSingleUse = v),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Schutzzonen', style: theme.textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _safeZoneCtrl.add(TextEditingController())),
                ),
              ],
            ),
            const Text(
              'Orte, an denen niemand eliminiert werden darf (z.B. Küche, Schule)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ...List.generate(_safeZoneCtrl.length, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _safeZoneCtrl[i],
                      decoration: InputDecoration(
                        labelText: 'Schutzzone ${i + 1}',
                        prefixIcon: const Icon(Icons.shield_outlined),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => setState(() {
                      _safeZoneCtrl[i].dispose();
                      _safeZoneCtrl.removeAt(i);
                    }),
                  ),
                ],
              ),
            )),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Schutzzeiten', style: theme.textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () async {
                    final start = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 22, minute: 0));
                    if (start == null || !mounted) return;
                    final end = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
                    if (end == null) return;
                    setState(() => _protectionTimes.add(ProtectionTime(
                      startTime: '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
                      endTime: '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
                      label: 'Nachtruhe',
                    )));
                  },
                ),
              ],
            ),
            const Text(
              'Zeiträume, in denen das Spiel pausiert (z.B. nachts)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            ...List.generate(_protectionTimes.length, (i) {
              final pt = _protectionTimes[i];
              return ListTile(
                leading: const Icon(Icons.access_time, color: Colors.blue),
                title: Text('${pt.startTime} – ${pt.endTime}'),
                subtitle: Text(pt.label ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() => _protectionTimes.removeAt(i)),
                ),
                contentPadding: EdgeInsets.zero,
              );
            }),

            const SizedBox(height: 32),
            AppButton(
              label: 'Spiel erstellen',
              onPressed: _create,
              isLoading: _loading,
              icon: Icons.rocket_launch,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Settings Card ──────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final List<Widget> children;

  const _SettingsCard({
    required this.icon,
    required this.label,
    required this.children,
    this.iconColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.titleSmall?.copyWith(
              color: iconColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            )),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: iconColor.withOpacity(0.25)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 1),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

// ── Mode Card ──────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.grey.withOpacity(0.3),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected ? theme.colorScheme.primary.withOpacity(0.1) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? theme.colorScheme.primary : Colors.grey, size: 28),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? theme.colorScheme.primary : null,
            )),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
