import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:moerderspiel/data/models/kniffel_game.dart';
import 'package:moerderspiel/presentation/providers/game_provider.dart';
import 'package:moerderspiel/presentation/providers/kniffel_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/avatar_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KniffelLeaderboardScreen extends ConsumerStatefulWidget {
  const KniffelLeaderboardScreen({super.key});

  @override
  ConsumerState<KniffelLeaderboardScreen> createState() =>
      _KniffelLeaderboardScreenState();
}

class _KniffelLeaderboardScreenState
    extends ConsumerState<KniffelLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final RealtimeChannel _channel;
  // null = global, non-null = filtered to that game's group
  String? _selectedGameId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _channel = Supabase.instance.client
        .channel('kniffel_leaderboard_live')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'kniffel_games',
          callback: (payload) {
            if (!mounted) return;
            if (payload.newRecord['status'] == 'completed') {
              ref.invalidate(kniffelDailyLeaderboardProvider);
              ref.invalidate(dailyKniffelWinnerIdProvider);
              ref.invalidate(dailyKniffelBadgesProvider);
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    Supabase.instance.client.removeChannel(_channel);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeGames = ref.watch(activeGamesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'RANGLISTE',
          style:
              GoogleFonts.rajdhani(letterSpacing: 4, fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'HEUTE'),
            Tab(text: 'ALLTIME'),
          ],
          labelStyle: GoogleFonts.rajdhani(
              fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2),
        ),
      ),
      body: Column(
        children: [
          // Scope selector (Global vs. Spielgruppe)
          activeGames.when(
            data: (games) {
              if (games.isEmpty) return const SizedBox.shrink();
              return _ScopeChips(
                games: games.map((g) => (g.id, g.name)).toList(),
                selectedGameId: _selectedGameId,
                onSelect: (id) => setState(() => _selectedGameId = id),
                isDark: isDark,
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _DailyLeaderboard(gameId: _selectedGameId),
                _AlltimeLeaderboard(gameId: _selectedGameId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scope chip row ─────────────────────────────────────────

class _ScopeChips extends StatelessWidget {
  final List<(String, String)> games;
  final String? selectedGameId;
  final void Function(String?) onSelect;
  final bool isDark;

  const _ScopeChips({
    required this.games,
    required this.selectedGameId,
    required this.onSelect,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _Chip(
            label: 'Global',
            selected: selectedGameId == null,
            onTap: () => onSelect(null),
            primary: primary,
            isDark: isDark,
          ),
          ...games.map(
            (g) => _Chip(
              label: g.$2,
              selected: selectedGameId == g.$1,
              onTap: () => onSelect(g.$1),
              primary: primary,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color primary;
  final bool isDark;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.07)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.black.withValues(alpha: 0.6)),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Daily leaderboard ──────────────────────────────────────

class _DailyLeaderboard extends ConsumerWidget {
  final String? gameId;
  const _DailyLeaderboard({required this.gameId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(kniffelDailyLeaderboardProvider(gameId));
    final winnerId = ref.watch(dailyKniffelWinnerIdProvider).value;

    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorCard(message: e.toString()),
      data: (entries) {
        if (entries.isEmpty) {
          return const _EmptyState(
            message: 'Noch niemand hat heute gespielt.\nSei der Erste!',
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(kniffelDailyLeaderboardProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              final maxRank = entries.map((e) => e.rank).reduce((a, b) => a > b ? a : b);
              final isLast = entries.length > 1 && e.rank == maxRank;
              return _DailyRow(
                entry: e,
                isWinner: e.userId == winnerId,
                isLast: isLast,
              )
                  .animate(key: ValueKey('daily_$i'))
                  .fadeIn(delay: Duration(milliseconds: 60 * i))
                  .slideX(begin: 0.05);
            },
          ),
        );
      },
    );
  }
}

class _DailyRow extends StatelessWidget {
  final KniffelDailyEntry entry;
  final bool isWinner;
  final bool isLast;
  const _DailyRow({required this.entry, required this.isWinner, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rankColor = entry.rank == 1
        ? const Color(0xFFFFB300)
        : entry.rank == 2
            ? const Color(0xFF90A4AE)
            : entry.rank == 3
                ? const Color(0xFF8D6E63)
                : null;

    final timeStr = entry.submittedAt != null
        ? DateFormat('HH:mm').format(entry.submittedAt!.toLocal())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isWinner
            ? Border.all(
                color: const Color(0xFFFFB300).withValues(alpha: 0.6),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          SizedBox(
            width: 32,
            child: Text(
              entry.rank == 1
                  ? '🥇'
                  : entry.rank == 2
                      ? '🥈'
                      : entry.rank == 3
                          ? '🥉'
                          : '#${entry.rank}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: entry.rank <= 3 ? 22 : 14,
                fontWeight: FontWeight.w700,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Avatar with optional crown or clown
          AvatarWidget(
            imageUrl: entry.avatarUrl,
            name: entry.username,
            radius: 20,
            showCrown: isWinner,
            showClown: isLast,
          ),
          const SizedBox(width: 12),

          // Name + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.username,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    if (isWinner) ...[
                      const SizedBox(width: 6),
                      const Text(
                        'Würfelgottheit',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFFFFB300),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                if (timeStr.isNotEmpty)
                  Text(
                    '$timeStr Uhr',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
          ),

          // Score
          Text(
            '${entry.finalScore}',
            style: GoogleFonts.rajdhani(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: rankColor ??
                  (isDark ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

// ── All-time leaderboard ───────────────────────────────────

class _AlltimeLeaderboard extends ConsumerWidget {
  final String? gameId;
  const _AlltimeLeaderboard({required this.gameId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(kniffelAlltimeLeaderboardProvider(gameId));
    final winnerId = ref.watch(dailyKniffelWinnerIdProvider).value;

    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorCard(message: e.toString()),
      data: (entries) {
        if (entries.isEmpty) {
          return const _EmptyState(
            message: 'Noch keine Spiele abgeschlossen.\nViel Spaß beim ersten!',
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(kniffelAlltimeLeaderboardProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              return _AlltimeRow(
                entry: entries[i],
                rank: i + 1,
                isToday: entries[i].userId == winnerId,
              )
                  .animate(key: ValueKey('alltime_$i'))
                  .fadeIn(delay: Duration(milliseconds: 60 * i))
                  .slideX(begin: 0.05);
            },
          ),
        );
      },
    );
  }
}

class _AlltimeRow extends StatelessWidget {
  final KniffelAlltimeEntry entry;
  final int rank;
  final bool isToday;
  const _AlltimeRow({
    required this.entry,
    required this.rank,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rankColor = rank == 1
        ? const Color(0xFFFFB300)
        : rank == 2
            ? const Color(0xFF90A4AE)
            : rank == 3
                ? const Color(0xFF8D6E63)
                : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isToday
            ? Border.all(
                color: const Color(0xFFFFB300).withValues(alpha: 0.5),
                width: 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  rank == 1
                      ? '🥇'
                      : rank == 2
                          ? '🥈'
                          : rank == 3
                              ? '🥉'
                              : '#$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: rank <= 3 ? 22 : 14,
                    fontWeight: FontWeight.w700,
                    color: rankColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AvatarWidget(
                imageUrl: entry.avatarUrl,
                name: entry.username,
                radius: 20,
                showCrown: isToday,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.username,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${entry.totalScore}',
                    style: GoogleFonts.rajdhani(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: rankColor ?? (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  Text(
                    'Gesamt',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MiniStat(
                  label: 'Ø',
                  value: entry.avgScore.toStringAsFixed(0),
                  isDark: isDark),
              _MiniStat(
                  label: 'Tage',
                  value: '${entry.daysPlayed}',
                  isDark: isDark),
              _MiniStat(
                  label: 'Rekord',
                  value: '${entry.bestScore}',
                  isDark: isDark),
              _MiniStat(
                  label: '👑 Kronen',
                  value: '${entry.dailyWins}',
                  isDark: isDark),
              _MiniStat(
                  label: '🤡 Loses',
                  value: '${entry.dailyLosses}',
                  isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _MiniStat(
      {required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎲', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white60
                    : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Fehler: $message',
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
