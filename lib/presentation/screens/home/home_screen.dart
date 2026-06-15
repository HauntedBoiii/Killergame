import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moerderspiel/core/services/push_notification_service.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/data/models/game.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';
import 'package:moerderspiel/presentation/providers/game_provider.dart';
import 'package:moerderspiel/presentation/providers/theme_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/avatar_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => PushNotificationService.init());
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final activeGames = ref.watch(activeGamesProvider);
    final finishedGames = ref.watch(finishedGamesProvider);
    final isDark = ref.watch(themeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MÖRDERSPIEL',
          style: GoogleFonts.rajdhani(letterSpacing: 4, fontWeight: FontWeight.w900),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined),
              onPressed: () => ref.read(themeProvider.notifier).toggle(),
              tooltip: 'Design wechseln',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeGamesProvider);
          ref.invalidate(finishedGamesProvider);
          ref.invalidate(profileProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome banner
            profile.when(
              data: (p) => GestureDetector(
                onTap: () => context.push('/profile'),
                child: _WelcomeBanner(
                  username: p?.username,
                  avatarUrl: p?.avatarUrl,
                  kills: p?.totalKills ?? 0,
                  wins: p?.totalWins ?? 0,
                  games: p?.totalGames ?? 0,
                ).animate(key: const ValueKey('home_welcome')).fadeIn().slideY(begin: -0.1),
              ),
              loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 20),

            // Active games
            activeGames.when(
              data: (games) {
                if (games.isEmpty) return const SizedBox.shrink();
                return Column(
                  children: games.mapIndexed((i, game) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ActiveGameCard(game: game)
                        .animate(key: ValueKey('home_game_${game.id}'))
                        .fadeIn(delay: Duration(milliseconds: 100 + i * 60))
                        .scale(begin: const Offset(0.97, 0.97)),
                  )).toList(),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // Action cards
            Text('Neues Spiel', style: theme.textTheme.titleLarge).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    icon: Icons.add_circle_outline,
                    label: 'Spiel\nerstellen',
                    color: theme.colorScheme.primary,
                    onTap: () => context.push('/game/create'),
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionCard(
                    icon: Icons.group_add_outlined,
                    label: 'Spiel\nbeitreten',
                    color: const Color(0xFF2979FF),
                    onTap: () => context.push('/game/join'),
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Finished games
            finishedGames.when(
              data: (games) {
                if (games.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vergangene Spiele', style: theme.textTheme.titleLarge)
                        .animate(key: const ValueKey('home_past_title')).fadeIn(delay: 500.ms),
                    const SizedBox(height: 12),
                    ...games.take(5).mapIndexed(
                      (i, g) => _FinishedGameTile(game: g)
                          .animate(key: ValueKey('home_past_${g.id}'))
                          .fadeIn(delay: Duration(milliseconds: 600 + i * 60)),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Welcome Banner ─────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final String? username;
  final String? avatarUrl;
  final int kills;
  final int wins;
  final int games;

  const _WelcomeBanner({
    required this.username,
    required this.avatarUrl,
    required this.kills,
    required this.wins,
    required this.games,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFF6D0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB71C1C).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
            ),
            child: AvatarWidget(imageUrl: avatarUrl, name: username, radius: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Willkommen,',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                ),
                Text(
                  username ?? 'Mörder',
                  style: GoogleFonts.rajdhani(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniStat(icon: '🗡️', value: '$kills', label: 'Kills'),
                    const SizedBox(width: 12),
                    _MiniStat(icon: '🏆', value: '$wins', label: 'Wins'),
                    const SizedBox(width: 12),
                    _MiniStat(icon: '🎮', value: '$games', label: 'Spiele'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  const _MiniStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$icon $value',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
      ],
    );
  }
}

// ── Active Game Card (with live player count) ──────────────

class _ActiveGameCard extends ConsumerWidget {
  final Game game;
  const _ActiveGameCard({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersAsync = ref.watch(playersProvider(game.id));
    final players = playersAsync.value ?? [];
    final aliveCount = players.where((p) => p.isAlive).length;
    final totalCount = players.length;
    final isActive = game.status == GameStatus.active;
    final statusColor = isActive ? Colors.red : Colors.orange;
    final route = isActive ? '/game/${game.id}' : '/game/${game.id}/lobby';

    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: statusColor.withValues(alpha: 0.6), width: 2),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Pulsing status dot
                _PulsingDot(color: statusColor),
                const SizedBox(width: 8),
                Text(
                  isActive ? 'AKTIVES SPIEL' : 'IN DER LOBBY',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    game.code,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      fontSize: 13,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              game.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _GameStat(icon: Icons.people, value: '$totalCount', label: 'Spieler', color: Colors.grey),
                const SizedBox(width: 16),
                if (isActive) ...[
                  _GameStat(icon: Icons.favorite, value: '$aliveCount', label: 'Am Leben', color: Colors.green),
                  const SizedBox(width: 16),
                  _GameStat(
                    icon: Icons.person_off_outlined,
                    value: '${totalCount - aliveCount}',
                    label: 'Eliminiert',
                    color: Colors.grey,
                  ),
                ],
                const Spacer(),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.withValues(alpha: 0.6)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
        ),
      ),
    );
  }
}

class _GameStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _GameStat({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text('$value ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.8))),
      ],
    );
  }
}

// ── Action Cards ───────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 34),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.2,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Finished Game Tile ─────────────────────────────────────

class _FinishedGameTile extends StatelessWidget {
  final Game game;
  const _FinishedGameTile({required this.game});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.history, color: Colors.grey, size: 20),
        ),
        title: Text(game.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(formatDate(game.endedAt ?? game.createdAt),
            style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.8))),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.withValues(alpha: 0.5)),
        onTap: () => context.push('/game/${game.id}/over'),
      ),
    );
  }
}

// ── Extension ─────────────────────────────────────────────

extension _IterableIndexed<T> on Iterable<T> {
  Iterable<E> mapIndexed<E>(E Function(int i, T e) f) sync* {
    var i = 0;
    for (final e in this) {
      yield f(i++, e);
    }
  }
}
