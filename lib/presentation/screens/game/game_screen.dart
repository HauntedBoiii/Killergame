import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/data/models/assignment.dart';
import 'package:moerderspiel/data/models/elimination.dart';
import 'package:moerderspiel/data/models/game.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';
import 'package:moerderspiel/presentation/providers/game_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/avatar_widget.dart';
import 'package:moerderspiel/presentation/widgets/game/kill_history_item.dart';

class GameScreen extends ConsumerStatefulWidget {
  final String gameId;
  const GameScreen({super.key, required this.gameId});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(gameProvider(widget.gameId), (_, next) {
      if (next.value?.isFinished == true && mounted) {
        context.pushReplacement('/game/${widget.gameId}/over');
      }
    });
    ref.listenManual(eliminationsProvider(widget.gameId), (prev, next) {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null || !mounted) return;
      final prevList = prev?.value ?? [];
      final nextList = next.value ?? [];
      for (final elim in nextList) {
        if (elim.killerId == userId && elim.status == EliminationStatus.rejected) {
          final wasAlreadyRejected = prevList.any(
            (e) => e.id == elim.id && e.status == EliminationStatus.rejected,
          );
          if (!wasAlreadyRejected) {
            showSnack(context, '❌ Dein Kill wurde abgelehnt!', isError: true);
            break;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameProvider(widget.gameId));
    final userId = ref.watch(currentUserIdProvider) ?? '';

    return gameAsync.when(
      data: (game) {
        if (game == null) return const Scaffold(body: Center(child: Text('Spiel nicht gefunden')));
        return _GameBody(gameId: widget.gameId, game: game, userId: userId);
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Fehler: $e'))),
    );
  }
}

class _GameBody extends ConsumerWidget {
  final String gameId;
  final Game game;
  final String userId;

  const _GameBody({required this.gameId, required this.game, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playersAsync = ref.watch(playersProvider(gameId));
    final eliminationsAsync = ref.watch(eliminationsProvider(gameId));
    final assignmentAsync = ref.watch(assignmentProvider(gameId));
    final myPlayer = ref.watch(myPlayerProvider(gameId));
    final pendingKill = ref.watch(pendingKillProvider(gameId));
    final myTasksAsync = ref.watch(myTasksProvider(gameId));

    final alivePlayers = playersAsync.value?.where((p) => p.isAlive).length ?? 0;
    final totalPlayers = playersAsync.value?.length ?? 0;
    final isAlive = myPlayer?.isAlive ?? true;
    final isAdmin = myPlayer?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(game.name),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => context.push('/game/$gameId/admin'),
              tooltip: 'Admin',
            ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/game/$gameId/history'),
            tooltip: 'Kill-Historie',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(assignmentProvider(gameId));
          ref.invalidate(myTasksProvider(gameId));
        },
        child: CustomScrollView(
          slivers: [
            // Stats bar
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 340;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Stat(value: '$alivePlayers', label: narrow ? 'Leben' : 'Lebend', icon: '💚'),
                        Container(height: 36, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
                        _Stat(value: '${totalPlayers - alivePlayers}', label: narrow ? 'Tot' : 'Eliminiert', icon: '💀'),
                        Container(height: 36, width: 1, color: Colors.grey.withValues(alpha: 0.3)),
                        _Stat(value: '${myPlayer?.kills ?? 0}', label: narrow ? 'Kills' : 'Deine Kills', icon: '🗡️'),
                      ],
                    );
                  },
                ),
              ).animate().fadeIn(),
            ),

            // Safe zones
            if (game.settings.safeZones.isNotEmpty)
              SliverToBoxAdapter(
                child: _InfoCard(
                  icon: Icons.shield_outlined,
                  color: Colors.blue,
                  title: 'Schutzzonen',
                  content: game.settings.safeZones.join(' · '),
                ).animate().fadeIn(delay: 50.ms),
              ),

            // Protection times
            if (game.settings.protectionTimes.isNotEmpty)
              SliverToBoxAdapter(
                child: _InfoCard(
                  icon: Icons.access_time,
                  color: Colors.purple,
                  title: 'Schutzzeiten',
                  content: game.settings.protectionTimes
                      .map((p) => '${p.startTime}–${p.endTime}${p.label != null ? ' (${p.label})' : ''}')
                      .join(' · '),
                ).animate().fadeIn(delay: 80.ms),
              ),

            // Pending kill banner
            if (pendingKill != null)
              SliverToBoxAdapter(
                child: _PendingKillBanner(
                  elimination: pendingKill,
                  gameId: gameId,
                ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
              ),

            // Eliminated banner
            if (!isAlive)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Text('☠️', style: TextStyle(fontSize: 32)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Du wurdest eliminiert',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('Das Spiel läuft noch weiter. Schau zu wer gewinnt!'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Target card
            if (isAlive)
              SliverToBoxAdapter(
                child: assignmentAsync.when(
                  data: (assignment) {
                    if (assignment == null) return const SizedBox.shrink();
                    return _TargetCard(gameId: gameId, assignment: assignment);
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),

            // Tasks preview — only in task mode
            if (isAlive && game.mode == GameMode.task)
              SliverToBoxAdapter(
                child: myTasksAsync.when(
                  data: (tasks) {
                    if (tasks.isEmpty) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () => context.push('/game/$gameId/tasks'),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('📋', style: TextStyle(fontSize: 24)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${tasks.length} Aufgabe(n)',
                                      style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    tasks.first.task?.description ?? '',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, color: Colors.orange),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          ],
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),

            // Object mode hint
            if (isAlive && game.mode == GameMode.object)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.teal.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('🎁', style: TextStyle(fontSize: 24)),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Gegenstand übergeben', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Übergib deinem Ziel den vereinbarten Gegenstand',
                                style: TextStyle(fontSize: 13, color: Colors.teal)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
              ),

            // Kill button — dramatic
            if (isAlive)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: _KillButton(gameId: gameId),
                ),
              ),

            // Recent kills
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Neueste Kills', style: theme.textTheme.titleLarge),
              ),
            ),
            eliminationsAsync.when(
              data: (eliminations) {
                final confirmed = eliminations.where((e) => e.isConfirmed).take(5).toList();
                if (confirmed.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text('☠️', style: TextStyle(fontSize: 40, color: Colors.grey.withValues(alpha: 0.5))),
                            const SizedBox(height: 8),
                            Text('Das Spiel hat noch kein Blut gesehen...',
                                style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => KillHistoryItem(elimination: confirmed[i], currentUserId: userId)
                        .animate(delay: Duration(milliseconds: i * 60)).fadeIn().slideX(begin: 0.05),
                    childCount: confirmed.length,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            ),

            // Leave game button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: _LeaveButton(gameId: gameId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info Card (safe zones / protection times) ──────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String content;

  const _InfoCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(content,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leave Game Button ──────────────────────────────────────

class _LeaveButton extends ConsumerStatefulWidget {
  final String gameId;
  const _LeaveButton({required this.gameId});

  @override
  ConsumerState<_LeaveButton> createState() => _LeaveButtonState();
}

class _LeaveButtonState extends ConsumerState<_LeaveButton> {
  bool _loading = false;

  Future<void> _leave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Spiel verlassen?'),
        content: const Text(
            'Du wirst aus dem aktiven Spiel entfernt. Dein Jäger bekommt dein Ziel. Deine Aufgaben verfallen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Verlassen')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      final result = await ref.read(gameRepositoryProvider).leaveGame(widget.gameId);
      if (!mounted) return;
      // Wenn kein Game-Over: zum Home navigieren
      // Bei Game-Over springt der gameProvider-Stream-Listener auf /game/over
      if (result['game_over'] != true) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Fehler: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _leave,
      icon: _loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.exit_to_app, size: 16),
      label: const Text('Spiel verlassen'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey,
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.5)),
        minimumSize: const Size(double.infinity, 44),
      ),
    );
  }
}

// ── Target Card (blurred until held) ──────────────────────

class _TargetCard extends StatefulWidget {
  final String gameId;
  final Assignment assignment;

  const _TargetCard({required this.gameId, required this.assignment});

  @override
  State<_TargetCard> createState() => _TargetCardState();
}

class _TargetCardState extends State<_TargetCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _blur;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 500),
    );
    _blur = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut, reverseCurve: Curves.easeIn),
    );
    _glow = Tween<double>(begin: 0.4, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
    final target = widget.assignment.targetProfile;

    return GestureDetector(
      onTap: () => context.push('/game/${widget.gameId}/target'),
      onLongPressStart: (_) {
        HapticFeedback.mediumImpact();
        _ctrl.forward();
      },
      onLongPressEnd: (_) => _ctrl.reverse(),
      onLongPressCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final revealed = _ctrl.value > 0.5;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 0.7),
              ]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: _glow.value),
                  blurRadius: 20 + _ctrl.value * 14,
                  spreadRadius: _ctrl.value * 3,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: _blurred(
                    AvatarWidget(imageUrl: target?.avatarUrl, name: target?.username, radius: 34),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🎯 DEIN ZIEL',
                          style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2)),
                      const SizedBox(height: 4),
                      _blurred(
                        Text(
                          target?.username ?? '???',
                          style: GoogleFonts.rajdhani(
                              fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          revealed ? 'Loslassen zum Verbergen' : '👆 Gedrückt halten zum Aufdecken',
                          key: ValueKey(revealed),
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    revealed ? Icons.lock_open_outlined : Icons.lock_outline,
                    key: ValueKey(revealed),
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 26,
                  ),
                ),
              ],
            ),
          );
        },
      ).animate().fadeIn(delay: 100.ms).shimmer(
            delay: 2000.ms,
            duration: 1500.ms,
            color: Colors.white.withValues(alpha: 0.15),
          ),
    );
  }
}

// ── Kill Button ────────────────────────────────────────────

class _KillButton extends StatefulWidget {
  final String gameId;
  const _KillButton({required this.gameId});

  @override
  State<_KillButton> createState() => _KillButtonState();
}

class _KillButtonState extends State<_KillButton> with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.03)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: RepaintBoundary(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.heavyImpact();
          context.push('/game/${widget.gameId}/report-kill');
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFB71C1C), Color(0xFF6D0000)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB71C1C).withValues(alpha: 0.55),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🗡️', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 14),
              Text(
                'KILL MELDEN',
                style: GoogleFonts.rajdhani(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3, duration: 400.ms);
  }
}

// ── Stat widget ────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final String icon;
  const _Stat({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ── Pending Kill Banner (pulsing) ──────────────────────────

class _PendingKillBanner extends ConsumerStatefulWidget {
  final Elimination elimination;
  final String gameId;
  const _PendingKillBanner({required this.elimination, required this.gameId});

  @override
  ConsumerState<_PendingKillBanner> createState() => _PendingKillBannerState();
}

class _PendingKillBannerState extends ConsumerState<_PendingKillBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    HapticFeedback.vibrate();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 0.8)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final killerName = widget.elimination.killerProfile?.username ?? 'Jemand';
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.red.withValues(alpha: _glowAnim.value),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: _glowAnim.value * 0.3),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'KILL-BESTÄTIGUNG AUSSTEHEND',
                style: GoogleFonts.rajdhani(
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                  letterSpacing: 1.5,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('$killerName behauptet, dich eliminiert zu haben.',
              style: const TextStyle(fontSize: 14)),
          if (widget.elimination.task != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Aufgabe: ${widget.elimination.task!.description}',
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    try {
                      await ref.read(gameRepositoryProvider).confirmKill(widget.elimination.id);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Fehler: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Bestätigen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await ref.read(gameRepositoryProvider).rejectKill(widget.elimination.id);
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                  label: const Text('Ablehnen', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
