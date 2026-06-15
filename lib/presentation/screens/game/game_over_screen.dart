import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moerderspiel/data/models/game_player.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';
import 'package:moerderspiel/presentation/providers/game_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/avatar_widget.dart';

class GameOverScreen extends ConsumerStatefulWidget {
  final String gameId;
  const GameOverScreen({super.key, required this.gameId});

  @override
  ConsumerState<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends ConsumerState<GameOverScreen> {
  late ConfettiController _confetti;
  bool _confettiFired = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _maybeFireConfetti(bool amIWinner) {
    if (amIWinner && !_confettiFired) {
      _confettiFired = true;
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _confetti.play();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameProvider(widget.gameId));
    final playersAsync = ref.watch(playersProvider(widget.gameId));
    final userId = ref.watch(currentUserIdProvider) ?? '';

    return Scaffold(
      body: gameAsync.when(
        data: (game) {
          if (game == null) return const Center(child: Text('Spiel nicht gefunden'));

          final players = playersAsync.value ?? [];
          final sorted = [...players]..sort((a, b) {
              if (a.isAlive && !b.isAlive) return -1;
              if (!a.isAlive && b.isAlive) return 1;
              return b.kills.compareTo(a.kills);
            });

          final winner = sorted.isNotEmpty ? sorted.first : null;
          final amIWinner = winner?.playerId == userId;

          _maybeFireConfetti(amIWinner);

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Hero header with avatar built in
                  SliverToBoxAdapter(
                    child: _HeroHeader(
                      amIWinner: amIWinner,
                      winner: winner,
                      gameName: game.name,
                    ),
                  ),

                  // Leaderboard title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Row(
                        children: [
                          const Text('🏆', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text('Rangliste', style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ),
                    ).animate().fadeIn(delay: 700.ms),
                  ),

                  // Leaderboard
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _LeaderboardTile(
                        rank: i + 1,
                        player: sorted[i],
                        isMe: sorted[i].playerId == userId,
                      ).animate(delay: Duration(milliseconds: 750 + i * 80))
                          .fadeIn()
                          .slideX(begin: -0.08),
                      childCount: sorted.length,
                    ),
                  ),

                  // Action buttons
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  context.pushReplacement('/game/${widget.gameId}/history'),
                              icon: const Icon(Icons.history),
                              label: const Text('Kill-Historie'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => context.go('/home'),
                              icon: const Icon(Icons.home_outlined),
                              label: const Text('Zurück zur Startseite'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 1200.ms),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),

              // Confetti overlay (winner only)
              if (amIWinner)
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confetti,
                    blastDirection: math.pi / 2,
                    blastDirectionality: BlastDirectionality.explosive,
                    particleDrag: 0.05,
                    emissionFrequency: 0.08,
                    numberOfParticles: 20,
                    gravity: 0.2,
                    shouldLoop: false,
                    colors: const [
                      Color(0xFFB71C1C),
                      Color(0xFFFFD700),
                      Color(0xFFFF6F00),
                      Colors.white,
                      Color(0xFF1565C0),
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
      ),
    );
  }
}

// ── Hero Header ────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final bool amIWinner;
  final GamePlayer? winner;
  final String gameName;

  const _HeroHeader({required this.amIWinner, required this.winner, required this.gameName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: amIWinner
              ? const [Color(0xFFFFD700), Color(0xFFFFA000), Color(0xFF6D3A00)]
              : const [Color(0xFF0F0F0F), Color(0xFF1E1E1E), Color(0xFF161616)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                amIWinner ? '🏆' : '☠️',
                style: const TextStyle(fontSize: 72),
              ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
              const SizedBox(height: 10),
              Text(
                amIWinner ? 'DU HAST GEWONNEN!' : 'SPIEL VORBEI',
                style: GoogleFonts.rajdhani(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: amIWinner ? Colors.black87 : Colors.white,
                  letterSpacing: 3,
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
              const SizedBox(height: 4),
              Text(
                gameName,
                style: TextStyle(
                  color: amIWinner
                      ? Colors.black.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 28),
              if (winner != null) ...[
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: amIWinner
                        ? const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                          )
                        : null,
                    border: amIWinner
                        ? null
                        : Border.all(color: Colors.amber.withValues(alpha: 0.7), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: amIWinner ? 0.5 : 0.25),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: AvatarWidget(
                    imageUrl: winner!.avatarUrl,
                    name: winner!.displayName,
                    radius: 52,
                  ),
                ).animate().scale(delay: 500.ms, duration: 600.ms, curve: Curves.elasticOut),
                const SizedBox(height: 10),
                Text(
                  winner!.displayName,
                  style: GoogleFonts.rajdhani(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: amIWinner ? Colors.black87 : Colors.amber,
                    letterSpacing: 1,
                  ),
                ).animate().fadeIn(delay: 800.ms),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Leaderboard Tile ───────────────────────────────────────

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final GamePlayer player;
  final bool isMe;

  const _LeaderboardTile({required this.rank, required this.player, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final rankEmoji = rank == 1 ? '🥇' : rank == 2 ? '🥈' : rank == 3 ? '🥉' : '#$rank';
    final theme = Theme.of(context);
    final isTop3 = rank <= 3;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: isMe
            ? LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.2),
                  theme.colorScheme.primary.withValues(alpha: 0.05),
                ],
              )
            : null,
        color: isMe ? null : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: isMe ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.7)) : null,
        boxShadow: isTop3
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: rank == 1 ? 0.2 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              rankEmoji,
              style: TextStyle(fontSize: isTop3 ? 24 : 15),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          AvatarWidget(
            imageUrl: player.avatarUrl,
            name: player.displayName,
            isAlive: player.isAlive,
            radius: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isMe ? theme.colorScheme.primary : null,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: player.isAlive ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      player.isAlive ? 'Überlebt' : 'Eliminiert',
                      style: TextStyle(
                        fontSize: 12,
                        color: player.isAlive ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${player.kills}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: player.kills > 0 ? theme.colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('🗡️', style: TextStyle(fontSize: 14)),
                ],
              ),
              Text(
                player.survivalTime != null
                    ? '${player.survivalTime!.inHours}h ${player.survivalTime!.inMinutes % 60}min'
                    : 'Gewonnen',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
