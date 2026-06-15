import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moerderspiel/data/models/elimination.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';
import 'package:moerderspiel/presentation/providers/game_provider.dart';
import 'package:moerderspiel/presentation/widgets/game/kill_history_item.dart';

class KillHistoryScreen extends ConsumerWidget {
  final String gameId;
  const KillHistoryScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eliminationsAsync = ref.watch(eliminationsProvider(gameId));
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Kill-Historie')),
      body: eliminationsAsync.when(
        data: (eliminations) {
          if (eliminations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📜', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text('Noch keine Kills', style: theme.textTheme.titleLarge),
                  Text('Das Spiel hat gerade erst begonnen.', style: theme.textTheme.bodyMedium),
                ],
              ),
            );
          }

          // Group by status for tabs
          final confirmed = eliminations.where((e) => e.isConfirmed).toList();
          final pending = eliminations.where((e) => e.isPending).toList();

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(text: 'Bestätigt (${confirmed.length})'),
                    Tab(text: 'Ausstehend (${pending.length})'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _EliminationList(eliminations: confirmed, userId: userId),
                      _EliminationList(eliminations: pending, userId: userId),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
      ),
    );
  }
}

class _EliminationList extends StatelessWidget {
  final List<Elimination> eliminations;
  final String userId;

  const _EliminationList({required this.eliminations, required this.userId});

  @override
  Widget build(BuildContext context) {
    if (eliminations.isEmpty) {
      return Center(child: Text('Nichts hier.', style: Theme.of(context).textTheme.bodyMedium));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: eliminations.length,
      itemBuilder: (_, i) => KillHistoryItem(elimination: eliminations[i], currentUserId: userId),
    );
  }
}
