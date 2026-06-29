import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/data/models/game.dart';
import 'package:moerderspiel/data/models/task.dart';
import 'package:moerderspiel/presentation/providers/codename_provider.dart';
import 'package:moerderspiel/presentation/providers/game_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/app_button.dart';
import 'package:moerderspiel/presentation/widgets/common/app_text_field.dart';

enum _CreateMode { assassinTask, assassinObject, doppelagent }

const _kCategories = <String, String>{
  'all':       'Alle',
  'agenten':   'Agenten',
  'orte':      'Orte',
  'objekte':   'Objekte',
  'essen':     'Essen',
  'tiere':     'Tiere',
  'alltag':    'Alltag',
  'konzepte':  'Konzepte',
  'popkultur': 'Popkultur',
  'laender':   'Länder',
};

class CreateGameScreen extends ConsumerStatefulWidget {
  const CreateGameScreen({super.key});

  @override
  ConsumerState<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends ConsumerState<CreateGameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _pageCtrl = PageController(viewportFraction: 0.82, initialPage: 0);

  _CreateMode _createMode = _CreateMode.assassinTask;
  String _selectedCategory = 'all';
  String _selectedMode = 'online';
  bool _requireAdmin = false;
  bool _loading = false;
  int _initialTasksPerPlayer = 1;
  bool _tasksAreSingleUse = false;

  final List<TextEditingController> _safeZoneCtrl = [];
  final List<ProtectionTime> _protectionTimes = [];

  bool get _isAssassin => _createMode != _CreateMode.doppelagent;
  bool get _isTaskMode => _createMode == _CreateMode.assassinTask;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pageCtrl.dispose();
    for (final c in _safeZoneCtrl) { c.dispose(); }
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    if (_createMode == _CreateMode.doppelagent) {
      setState(() => _loading = true);
      try {
        final session = await ref.read(codenameRepositoryProvider).createSession(
              name: _nameCtrl.text.trim(),
              category: _selectedCategory,
              mode: _selectedMode,
            );
        if (mounted) context.pushReplacement('/codename/${session.id}/lobby');
      } catch (e) {
        if (mounted) showSnack(context, 'Fehler: $e', isError: true);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final mode = _createMode == _CreateMode.assassinTask ? GameMode.task : GameMode.object;
      final settings = GameSettings(
        teamMode: false,
        safeZones: _safeZoneCtrl.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList(),
        protectionTimes: _protectionTimes,
        requireAdminConfirmation: _requireAdmin,
        initialTasksPerPlayer: _initialTasksPerPlayer,
        tasksAreSingleUse: _tasksAreSingleUse,
      );
      final game = await ref.read(gameRepositoryProvider).createGame(
            name: _nameCtrl.text.trim(),
            mode: mode,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _nameCtrl,
                label: 'Spielname',
                prefixIcon: Icons.sports_esports,
                validator: (v) => v == null || v.trim().isEmpty ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 24),

              // ── Spieltyp-Carousel ──────────────────────────────
              Text('Spielmodus', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              SizedBox(
                height: 168,
                child: PageView(
                  controller: _pageCtrl,
                  onPageChanged: (i) =>
                      setState(() => _createMode = _CreateMode.values[i]),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _TypeCard(
                        selected: _createMode == _CreateMode.assassinTask,
                        icon: Icons.task_alt,
                        title: 'Mörder (Aufgabe)',
                        subtitle: 'Geheime Aufgaben — eliminiere dein Ziel\ndurch einen bestimmten Trick',
                        onTap: () => _pageCtrl.animateToPage(0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _TypeCard(
                        selected: _createMode == _CreateMode.assassinObject,
                        icon: Icons.inventory_2_outlined,
                        title: 'Mörder (Gegenstand)',
                        subtitle: 'Übergib deinem Ziel einen\nbestimmten Gegenstand',
                        onTap: () => _pageCtrl.animateToPage(1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _TypeCard(
                        selected: _createMode == _CreateMode.doppelagent,
                        icon: Icons.psychology_outlined,
                        title: 'Doppelagent',
                        subtitle: 'Wer kennt das Codewort nicht?\nFinde den Verräter — oder lenke den Verdacht von dir...',
                        isNew: true,
                        onTap: () => _pageCtrl.animateToPage(2,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _DotIndicator(count: 3, active: _createMode.index),
              const SizedBox(height: 24),

              // ── Assassinen-Settings ────────────────────────────
              if (_isAssassin) ...[
                _SettingsCard(
                  icon: Icons.settings_outlined,
                  label: 'Allgemein',
                  children: [
                    _SettingsTile(
                      icon: Icons.shield_outlined,
                      iconColor: Colors.grey,
                      title: 'Admin-Bestätigung',
                      subtitle: 'Kills müssen vom Admin bestätigt werden',
                      trailing: Switch(
                        value: _requireAdmin,
                        onChanged: (v) => setState(() => _requireAdmin = v),
                      ),
                    ),
                  ],
                ),

                if (_isTaskMode) ...[
                  const SizedBox(height: 16),
                  const _AdminTaskPoolCard(),
                  const SizedBox(height: 16),
                  _SettingsCard(
                    icon: Icons.task_alt,
                    label: 'Aufgaben',
                    iconColor: Colors.grey,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.format_list_numbered, size: 16, color: Colors.grey),
                                SizedBox(width: 8),
                                Text('Aufgaben pro Spieler',
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
                        iconColor: Colors.grey,
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

                const SizedBox(height: 16),
                _SettingsCard(
                  icon: Icons.shield_outlined,
                  label: 'Schutzzonen',
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () =>
                        setState(() => _safeZoneCtrl.add(TextEditingController())),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        'Orte, an denen niemand eliminiert werden darf (z.B. Küche, Schule)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    if (_safeZoneCtrl.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text('Keine Schutzzonen definiert.',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                        child: Column(
                          children: List.generate(_safeZoneCtrl.length, (i) => Padding(
                            padding: const EdgeInsets.only(top: 8),
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
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.red),
                                  onPressed: () => setState(() {
                                    _safeZoneCtrl[i].dispose();
                                    _safeZoneCtrl.removeAt(i);
                                  }),
                                ),
                              ],
                            ),
                          )),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),
                _SettingsCard(
                  icon: Icons.access_time,
                  label: 'Schutzzeiten',
                  trailing: IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () async {
                      final ctx = context;
                      final start = await showTimePicker(
                          context: ctx,
                          initialTime: const TimeOfDay(hour: 22, minute: 0));
                      if (start == null || !mounted) return;
                      final end = await showTimePicker(
                          context: ctx, // ignore: use_build_context_synchronously
                          initialTime: const TimeOfDay(hour: 8, minute: 0));
                      if (end == null) return;
                      setState(() => _protectionTimes.add(ProtectionTime(
                            startTime:
                                '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
                            endTime:
                                '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
                            label: 'Nachtruhe',
                          )));
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        'Zeiträume, in denen das Spiel pausiert (z.B. nachts)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    if (_protectionTimes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text('Keine Schutzzeiten definiert.',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      )
                    else
                      Column(
                        children: List.generate(_protectionTimes.length, (i) {
                          final pt = _protectionTimes[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
                            leading: const Icon(Icons.access_time,
                                color: Colors.grey, size: 18),
                            title: Text('${pt.startTime} – ${pt.endTime}',
                                style: const TextStyle(fontSize: 13)),
                            subtitle: pt.label != null
                                ? Text(pt.label!, style: const TextStyle(fontSize: 11))
                                : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () =>
                                  setState(() => _protectionTimes.removeAt(i)),
                            ),
                          );
                        }),
                      ),
                  ],
                ),
              ],

              // ── Doppelagent-Settings ───────────────────────────
              if (!_isAssassin) ...[
                const _SettingsCard(
                  icon: Icons.info_outline,
                  label: 'Hinweise',
                  children: [
                    _InfoTile(
                      icon: Icons.group_outlined,
                      text: 'Mindestens 7 Spieler erforderlich, damit Belohnungen aktiv sind.',
                    ),
                    Divider(height: 1),
                    _InfoTile(
                      icon: Icons.code,
                      text: 'Andere Spieler treten per Code bei.',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  icon: Icons.mic_outlined,
                  label: 'Hinweis-Modus',
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'online',
                                icon: Icon(Icons.wifi_outlined),
                                label: Text('Online'),
                              ),
                              ButtonSegment(
                                value: 'hybrid',
                                icon: Icon(Icons.people_outlined),
                                label: Text('Mündlich'),
                              ),
                            ],
                            selected: {_selectedMode},
                            onSelectionChanged: (s) =>
                                setState(() => _selectedMode = s.first),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _selectedMode == 'online'
                                ? 'Jeder tippt seinen Hinweis in die App — erzwungene Reihenfolge.'
                                : 'Hinweise werden laut gesagt. Die App trackt nur Reihenfolge & Abstimmung.',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsCard(
                  icon: Icons.label_outline,
                  label: 'Wort-Kategorie',
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _kCategories.entries.map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: _selectedCategory == e.key,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = e.key),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),
              AppButton(
                label: _isAssassin ? 'Spiel erstellen' : 'Doppelagent erstellen',
                onPressed: _create,
                isLoading: _loading,
                icon: _isAssassin ? Icons.rocket_launch : Icons.psychology_outlined,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Type Card (Carousel) ───────────────────────────────────

class _TypeCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isNew;
  final VoidCallback onTap;

  const _TypeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Ink(
      decoration: BoxDecoration(
        border: Border.all(
          color: selected ? primary : Colors.grey.withValues(alpha: 0.3),
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        color: selected
            ? primary.withValues(alpha: 0.08)
            : theme.cardTheme.color,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        color: selected ? primary : Colors.grey, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: selected ? primary : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
                    ),
                  ],
                ),
              ),
              if (isNew)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'NEU',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dot Indicator ──────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  final int count;
  final int active;
  const _DotIndicator({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? primary : Colors.grey.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── Info Tile (Doppelagent) ────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
        ],
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
  final Widget? trailing;

  const _SettingsCard({
    required this.icon,
    required this.label,
    required this.children,
    this.iconColor = Colors.grey,
    this.trailing,
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
            if (trailing != null) ...[const Spacer(), trailing!],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: iconColor.withValues(alpha: 0.25)),
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
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 1),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

// ── Admin Task Pool Card ───────────────────────────────────

class _AdminTaskPoolCard extends ConsumerStatefulWidget {
  const _AdminTaskPoolCard();

  @override
  ConsumerState<_AdminTaskPoolCard> createState() => _AdminTaskPoolCardState();
}

class _AdminTaskPoolCardState extends ConsumerState<_AdminTaskPoolCard> {
  bool _saving = false;

  Future<void> _showAddDialog() async {
    final descCtrl = TextEditingController();
    int difficulty = 1;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Aufgabe erstellen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: descCtrl,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Schwierigkeit',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 1, label: Text('⭐')),
                  ButtonSegment(value: 2, label: Text('⭐⭐')),
                  ButtonSegment(value: 3, label: Text('⭐⭐⭐')),
                ],
                selected: {difficulty},
                onSelectionChanged: (s) =>
                    setDialogState(() => difficulty = s.first),
                expandedInsets: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: descCtrl.text.isNotEmpty
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Erstellen'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && descCtrl.text.trim().isNotEmpty) {
      setState(() => _saving = true);
      try {
        await ref.read(taskRepositoryProvider).createAdminTask(
              description: descCtrl.text.trim(),
              difficulty: difficulty,
            );
        ref.invalidate(adminTasksProvider);
        if (mounted) showSnack(context, 'Aufgabe erstellt!');
      } catch (e) {
        if (mounted) showSnack(context, 'Fehler: $e', isError: true);
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Aufgabe löschen?'),
        content: Text('"${task.description}" dauerhaft löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(taskRepositoryProvider).deleteAdminTask(task.id);
        ref.invalidate(adminTasksProvider);
      } catch (e) {
        if (mounted) showSnack(context, 'Fehler: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(adminTasksProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.playlist_add_check, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text('Mein Aufgaben-Pool',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.grey,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                )),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Eigene Aufgaben',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 20),
                          onPressed: _showAddDialog,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Neue Aufgabe erstellen',
                        ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Wiederverwendbar in allen deinen Spielen. Einzelne Aufgaben können pro Spiel deaktiviert werden.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
              tasksAsync.when(
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return Text(
                      'Noch keine Aufgaben. Tippe auf + um eine zu erstellen.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    );
                  }
                  return Column(
                    children: tasks
                        .map((task) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              title: Text(task.description,
                                  style: const TextStyle(fontSize: 13)),
                              subtitle: Text('⭐' * task.difficulty,
                                  style: const TextStyle(fontSize: 11)),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red, size: 18),
                                onPressed: () => _delete(task),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ))
                        .toList(),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) =>
                    Text('Fehler: $e', style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
