import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/data/models/game.dart';
import 'package:moerderspiel/data/models/game_player.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';
import 'package:moerderspiel/presentation/providers/game_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/app_button.dart';
import 'package:moerderspiel/presentation/widgets/game/player_card.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String gameId;
  const LobbyScreen({super.key, required this.gameId});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _startLoading = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(gameProvider(widget.gameId), (_, next) {
      if (next.value?.isActive == true && mounted) {
        context.pushReplacement('/game/${widget.gameId}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gameAsync = ref.watch(gameProvider(widget.gameId));
    final playersAsync = ref.watch(playersProvider(widget.gameId));
    final myPlayer = ref.watch(myPlayerProvider(widget.gameId));
    final userId = ref.watch(currentUserIdProvider);

    return gameAsync.when(
      data: (game) {
        if (game == null) return const Scaffold(body: Center(child: Text('Spiel nicht gefunden')));

        return Scaffold(
          appBar: AppBar(
            title: Text(game.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code),
                onPressed: () => _showQrDialog(context, game.code),
                tooltip: 'QR-Code anzeigen',
              ),
            ],
          ),
          body: playersAsync.when(
            data: (players) => _buildLobby(context, game, players, myPlayer, userId, theme),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Fehler: $e')),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Fehler: $e'))),
    );
  }

  Widget _buildLobby(BuildContext context, Game game, List<GamePlayer> players,
      GamePlayer? myPlayer, String? userId, ThemeData theme) {
    final isAdmin = myPlayer?.isAdmin ?? false;
    final isReady = myPlayer?.isReady ?? false;
    final allReady = players.isNotEmpty && players.every((p) => p.isReady);
    final aliveCount = players.where((p) => p.isAlive).length;

    return Column(
      children: [
        // Game code banner
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              theme.colorScheme.primary.withOpacity(0.3),
              theme.colorScheme.primary.withOpacity(0.1),
            ]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Spielcode', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    game.code,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 6,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  GestureDetector(
                    onTap: () => _copyCode(context, game.code, theme),
                    child: Icon(Icons.copy, color: theme.colorScheme.primary),
                  ),
                  Text('${aliveCount} / ${players.length} Spieler',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(),

        // Status banner
        if (allReady && isAdmin)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Alle bereit! Du kannst das Spiel starten.'),
                ),
              ],
            ),
          ).animate().fadeIn().scale(),

        // Players list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: players.length,
            itemBuilder: (_, i) => PlayerCard(
              player: players[i],
              isMe: players[i].playerId == userId,
              onRemove: isAdmin && players[i].playerId != userId
                  ? () => _removePlayer(players[i])
                  : null,
            ).animate(delay: Duration(milliseconds: i * 50)).fadeIn().slideX(begin: -0.1),
          ),
        ),

        // Bottom actions
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (!isAdmin)
                AppButton(
                  label: isReady ? 'Ich bin bereit ✓' : 'Bereit melden',
                  onPressed: () => _toggleReady(isReady),
                  color: isReady ? Colors.green : null,
                  outlined: isReady,
                ),
              if (isAdmin) ...[
                AppButton(
                  label: 'Spiel STARTEN',
                  onPressed: (allReady && players.length >= 2) ? _startGame : null,
                  isLoading: _startLoading,
                  icon: Icons.play_arrow,
                ),
                const SizedBox(height: 8),
                AppButton(
                  label: 'Admin-Bereich',
                  onPressed: () => context.push('/game/${widget.gameId}/admin'),
                  outlined: true,
                  icon: Icons.settings,
                ),
              ],
              const SizedBox(height: 8),
              AppButton(
                label: 'Spiel verlassen',
                onPressed: _leaveGame,
                outlined: true,
                color: Colors.red,
                icon: Icons.exit_to_app,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _copyCode(BuildContext context, String code, ThemeData theme) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (mounted) showSnack(context, 'Code kopiert!');
    } catch (_) {
      // Clipboard API unavailable on HTTP (iOS Safari) — show selectable dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Code manuell kopieren'),
            content: SelectableText(
              code,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: 10,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  Future<void> _toggleReady(bool currentlyReady) async {
    try {
      await ref.read(gameRepositoryProvider).setReady(widget.gameId, !currentlyReady);
    } catch (e) {
      if (mounted) showSnack(context, 'Fehler: $e', isError: true);
    }
  }

  Future<void> _startGame() async {
    setState(() => _startLoading = true);
    try {
      await ref.read(gameRepositoryProvider).startGame(widget.gameId);
    } catch (e) {
      if (mounted) showSnack(context, 'Fehler beim Starten: $e', isError: true);
    } finally {
      if (mounted) setState(() => _startLoading = false);
    }
  }

  Future<void> _removePlayer(GamePlayer player) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Spieler entfernen?'),
        content: Text('${player.displayName} aus dem Spiel entfernen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Entfernen')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(gameRepositoryProvider).removePlayer(widget.gameId, player.playerId);
      } catch (e) {
        if (mounted) showSnack(context, 'Fehler: $e', isError: true);
      }
    }
  }

  Future<void> _leaveGame() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Spiel verlassen?'),
        content: const Text('Du verlässt die Lobby. Du kannst wieder beitreten.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Verlassen')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(gameRepositoryProvider).leaveGame(widget.gameId);
        ref.invalidate(activeGamesProvider);
        if (mounted) context.go('/home');
      } catch (e) {
        if (mounted) showSnack(context, 'Fehler beim Verlassen: $e', isError: true);
      }
    }
  }

  void _showQrDialog(BuildContext context, String code) {
    final joinUrl = '${Uri.base.origin}/game/join?code=$code';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('QR-Code teilen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: QrImageView(
                data: joinUrl,
                size: 200,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              code,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 6),
            ),
            const SizedBox(height: 4),
            Text(
              'Scan öffnet die Beitrittsseite direkt',
              style: TextStyle(fontSize: 12, color: Colors.grey.withOpacity(0.7)),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen'))],
      ),
    );
  }
}
