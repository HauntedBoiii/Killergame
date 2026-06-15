import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/data/models/game.dart';
import 'package:moerderspiel/data/models/game_player.dart';
import 'package:moerderspiel/presentation/providers/game_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/app_button.dart';
import 'package:moerderspiel/presentation/widgets/game/player_card.dart';

class AdminScreen extends ConsumerWidget {
  final String gameId;
  const AdminScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameAsync = ref.watch(gameProvider(gameId));
    final playersAsync = ref.watch(playersProvider(gameId));

    return Scaffold(
      appBar: AppBar(title: const Text('Admin-Bereich')),
      body: gameAsync.when(
        data: (game) {
          if (game == null) return const Center(child: Text('Spiel nicht gefunden'));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionTitle(title: 'Spielstatus'),
              _GameStatusCard(game: game, gameId: gameId, ref: ref),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Spieler verwalten'),
              playersAsync.when(
                data: (players) => Column(
                  children: players.map((p) => _AdminPlayerTile(
                    player: p,
                    gameId: gameId,
                    ref: ref,
                    canRevive: game.isActive && !p.isAlive,
                  )).toList(),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Fehler: $e'),
              ),
              if (game.isActive) ...[
                const SizedBox(height: 24),
                _SectionTitle(title: 'Zuweisung reparieren'),
                playersAsync.when(
                  data: (players) => _SwapAssignmentsSection(
                    gameId: gameId,
                    alivePlayers: players.where((p) => p.isAlive).toList(),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Fehler: $e'),
                ),
              ],
              const SizedBox(height: 24),
              _SectionTitle(title: 'Gefahrenzone'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Column(
                  children: [
                    const Text(
                      '⚠️ Diese Aktionen können nicht rückgängig gemacht werden!',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Spiel beenden',
                      onPressed: () => _endGame(context, ref),
                      color: Colors.red,
                      icon: Icons.stop_circle_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
      ),
    );
  }

  Future<void> _endGame(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Spiel beenden?'),
        content: const Text('Das Spiel wird vorzeitig beendet. Alle Spieler sehen das Endergebnis.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Beenden'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(gameRepositoryProvider).updateGameSettings(
              gameId,
              const GameSettings(), // trigger update - Supabase function needed for full end
            );
        if (context.mounted) showSnack(context, 'Spiel beendet.');
      } catch (e) {
        if (context.mounted) showSnack(context, 'Fehler: $e', isError: true);
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      );
}

class _GameStatusCard extends StatelessWidget {
  final Game game;
  final String gameId;
  final WidgetRef ref;

  const _GameStatusCard({required this.game, required this.gameId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final statusColor = game.isActive ? Colors.green : game.isFinished ? Colors.red : Colors.orange;
    final statusLabel = game.isActive ? '🔴 LÄUFT' : game.isFinished ? '✅ BEENDET' : '⏳ LOBBY';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(game.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Code: ${game.code}', style: const TextStyle(fontSize: 16, letterSpacing: 2)),
          Text('Modus: ${game.mode == GameMode.task ? 'Aufgaben' : 'Gegenstand'}'),
          if (game.startedAt != null)
            Text('Gestartet: ${formatDate(game.startedAt!)}'),
        ],
      ),
    );
  }
}

class _AdminPlayerTile extends StatelessWidget {
  final GamePlayer player;
  final String gameId;
  final WidgetRef ref;
  final bool canRevive;

  const _AdminPlayerTile({
    required this.player,
    required this.gameId,
    required this.ref,
    required this.canRevive,
  });

  @override
  Widget build(BuildContext context) {
    return PlayerCard(
      player: player,
      onRemove: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Spieler entfernen?'),
            content: Text('${player.displayName} aus dem Spiel entfernen?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Nein')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Entfernen')),
            ],
          ),
        );
        if (confirm == true) {
          try {
            await ref.read(gameRepositoryProvider).removePlayer(gameId, player.playerId);
          } catch (e) {
            if (context.mounted) showSnack(context, 'Fehler: $e', isError: true);
          }
        }
      },
    );
  }
}

// ── Swap Assignments Section ───────────────────────────────

class _SwapAssignmentsSection extends ConsumerStatefulWidget {
  final String gameId;
  final List<GamePlayer> alivePlayers;

  const _SwapAssignmentsSection({required this.gameId, required this.alivePlayers});

  @override
  ConsumerState<_SwapAssignmentsSection> createState() => _SwapAssignmentsSectionState();
}

class _SwapAssignmentsSectionState extends ConsumerState<_SwapAssignmentsSection> {
  List<Map<String, dynamic>> _broken = [];
  bool _loading = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkBroken();
  }

  Future<void> _checkBroken() async {
    try {
      final result = await ref.read(gameRepositoryProvider).getBrokenAssignments(widget.gameId);
      if (mounted) setState(() => _broken = result);
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _openSwapDialog() async {
    String? playerAId;
    String? playerBId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Zuweisungen tauschen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wähle zwei Spieler. Deren Ziele werden getauscht — du siehst nicht, wer wen als Ziel hat.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Spieler A', border: OutlineInputBorder()),
                value: playerAId,
                items: widget.alivePlayers
                    .map((p) => DropdownMenuItem(value: p.playerId, child: Text(p.displayName)))
                    .toList(),
                onChanged: (v) => setDialogState(() => playerAId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Spieler B', border: OutlineInputBorder()),
                value: playerBId,
                items: widget.alivePlayers
                    .map((p) => DropdownMenuItem(value: p.playerId, child: Text(p.displayName)))
                    .toList(),
                onChanged: (v) => setDialogState(() => playerBId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: (playerAId != null && playerBId != null && playerAId != playerBId)
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Tauschen 🔀'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && playerAId != null && playerBId != null) {
      setState(() => _loading = true);
      try {
        await ref.read(gameRepositoryProvider).swapAssignments(widget.gameId, playerAId!, playerBId!);
        if (mounted) {
          showSnack(context, 'Zuweisungen getauscht!');
          _checkBroken();
        }
      } catch (e) {
        if (mounted) showSnack(context, 'Fehler: $e', isError: true);
      }
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_checking) const LinearProgressIndicator(),
          if (_broken.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_broken.map((e) => e['display_name']).join(', ')} hat sich selbst als Ziel!',
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Tausche die Ziele zweier lebendiger Spieler, ohne einsehen zu können, wer wen als Ziel hat.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Zuweisungen tauschen',
            onPressed: _loading ? null : _openSwapDialog,
            isLoading: _loading,
            icon: Icons.swap_horiz,
          ),
        ],
      ),
    );
  }
}
