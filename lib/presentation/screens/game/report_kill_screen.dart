import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/data/models/game.dart';
import 'package:moerderspiel/data/models/task.dart';
import 'package:moerderspiel/presentation/providers/game_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/app_button.dart';
import 'package:moerderspiel/presentation/widgets/common/avatar_widget.dart';

class ReportKillScreen extends ConsumerStatefulWidget {
  final String gameId;
  const ReportKillScreen({super.key, required this.gameId});

  @override
  ConsumerState<ReportKillScreen> createState() => _ReportKillScreenState();
}

class _ReportKillScreenState extends ConsumerState<ReportKillScreen>
    with SingleTickerProviderStateMixin {
  PlayerTask? _selectedTask;
  bool _loading = false;

  late AnimationController _revealCtrl;
  late Animation<double> _blur;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _revealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 500),
    );
    _blur = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
    );
    _glow = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    super.dispose();
  }

  Widget _blurred(Widget child) => AnimatedBuilder(
        animation: _blur,
        builder: (_, __) => ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: _blur.value, sigmaY: _blur.value),
          child: child,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assignmentAsync = ref.watch(assignmentProvider(widget.gameId));
    final myTasksAsync = ref.watch(myTasksProvider(widget.gameId));
    final gameAsync = ref.watch(gameProvider(widget.gameId));
    final isObjectMode = gameAsync.value?.mode == GameMode.object;

    return Scaffold(
      appBar: AppBar(title: const Text('Kill melden')),
      body: assignmentAsync.when(
        data: (assignment) {
          if (assignment == null) {
            return const Center(child: Text('Keine aktive Zuweisung'));
          }
          final target = assignment.targetProfile;
          final singleUse = gameAsync.value?.settings.tasksAreSingleUse ?? false;
          final allTasks = myTasksAsync.value ?? [];
          final availableTasks = singleUse ? allTasks.where((t) => !t.isUsed).toList() : allTasks;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Target display (hold to reveal)
              GestureDetector(
                onLongPressStart: (_) {
                  HapticFeedback.mediumImpact();
                  _revealCtrl.forward();
                },
                onLongPressEnd: (_) => _revealCtrl.reverse(),
                onLongPressCancel: () => _revealCtrl.reverse(),
                child: AnimatedBuilder(
                  animation: _revealCtrl,
                  builder: (_, __) {
                    final revealed = _revealCtrl.value > 0.5;
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary.withOpacity(0.8),
                            theme.colorScheme.primary.withOpacity(0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(_glow.value),
                            blurRadius: 16 + _revealCtrl.value * 12,
                            spreadRadius: _revealCtrl.value * 2,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _blurred(AvatarWidget(
                              imageUrl: target?.avatarUrl, name: target?.username, radius: 40)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🎯 ZIEL',
                                    style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 2)),
                                const SizedBox(height: 2),
                                _blurred(Text(
                                  target?.username ?? '???',
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                )),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Text(
                                    revealed
                                        ? 'Loslassen zum Verbergen'
                                        : '👆 Gedrückt halten zum Aufdecken',
                                    key: ValueKey(revealed),
                                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              revealed ? Icons.lock_open_outlined : Icons.lock_outline,
                              key: ValueKey(revealed),
                              color: Colors.white60,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 32),

              if (isObjectMode) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.withOpacity(0.4)),
                  ),
                  child: const Column(
                    children: [
                      Text('🎁', style: TextStyle(fontSize: 40)),
                      SizedBox(height: 8),
                      Text(
                        'Gegenstand übergeben?',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Bestätige, dass du deinem Ziel den vereinbarten Gegenstand übergeben hast.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
              Text('Welche Aufgabe hast du eingesetzt?', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Wähle die Aufgabe, mit der du das Opfer eliminiert hast.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              if (availableTasks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Keine Aufgaben verfügbar. Du kannst den Kill trotzdem ohne Aufgabe melden.',
                    textAlign: TextAlign.center,
                  ),
                ),

              ...availableTasks.map((pt) {
                final isSelected = _selectedTask?.id == pt.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTask = isSelected ? null : pt),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.primary : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isSelected ? theme.colorScheme.primary : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pt.task?.description ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (pt.isInherited)
                                const Text('Erbschaft 🩸', style: TextStyle(fontSize: 11, color: Colors.purple)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              ], // end else (task mode)

              const SizedBox(height: 32),

              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Wie funktioniert die Bestätigung?', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('• Das Opfer erhält eine Benachrichtigung'),
                    Text('• Es muss den Kill bestätigen oder ablehnen'),
                    Text('• Nach Bestätigung übernimmst du das nächste Ziel'),
                    Text('• Du erbst alle ungenutzten Aufgaben des Opfers'),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              AppButton(
                label: 'Kill melden 🗡️',
                onPressed: _report,
                isLoading: _loading,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Abbrechen',
                onPressed: () => context.pop(),
                outlined: true,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
      ),
    );
  }

  Future<void> _report() async {
    final assignment = ref.read(assignmentProvider(widget.gameId)).value;
    if (assignment == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Kill bestätigen?'),
        content: Text(
          'Hast du ${assignment.targetProfile?.username ?? 'das Ziel'} wirklich eliminiert?'
          '${_selectedTask != null ? '\n\nMit: ${_selectedTask!.task?.description}' : ''}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nein')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ja, melden!')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ref.read(gameRepositoryProvider).reportKill(
            gameId: widget.gameId,
            victimId: assignment.targetId,
            taskId: _selectedTask?.taskId,
          );
      if (mounted) {
        showSnack(context, 'Kill gemeldet! Warte auf Bestätigung...');
        context.pop();
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Fehler: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
