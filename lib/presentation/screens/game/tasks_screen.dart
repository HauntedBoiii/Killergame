import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/data/models/task.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';
import 'package:moerderspiel/presentation/providers/game_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/app_button.dart';

class TasksScreen extends ConsumerWidget {
  final String gameId;
  const TasksScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myTasksAsync = ref.watch(myTasksProvider(gameId));
    final game = ref.watch(gameProvider(gameId)).value;
    final singleUse = game?.settings.tasksAreSingleUse ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Aufgaben'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTaskDialog(context, ref),
            tooltip: 'Aufgabe hinzufügen',
          ),
        ],
      ),
      body: myTasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📋', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 16),
                  Text('Keine Aufgaben', style: theme.textTheme.titleLarge),
                  Text('Du hast noch keine Aufgaben.', style: theme.textTheme.bodyMedium),
                ],
              ),
            );
          }

          final available = tasks.where((t) => !t.isUsed).toList();
          final used = tasks.where((t) => t.isUsed).toList();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myTasksProvider(gameId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (singleUse) ...[
                  Text('Verfügbar (${available.length})', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Jede Aufgabe kann nur einmal eingesetzt werden.',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  ...available.asMap().entries.map(
                        (e) => _TaskCard(playerTask: e.value, singleUse: true, consumed: false)
                            .animate(delay: Duration(milliseconds: e.key * 80))
                            .fadeIn()
                            .slideX(begin: -0.1),
                      ),
                  if (used.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Verbraucht (${used.length})', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ...used.asMap().entries.map(
                          (e) => _TaskCard(playerTask: e.value, singleUse: true, consumed: true)
                              .animate(delay: Duration(milliseconds: e.key * 80))
                              .fadeIn(),
                        ),
                  ],
                ] else ...[
                  Text('Meine Aufgaben (${tasks.length})', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Alle Aufgaben können unbegrenzt oft eingesetzt werden.',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  ...tasks.asMap().entries.map(
                        (e) => _TaskCard(playerTask: e.value, singleUse: false, consumed: false)
                            .animate(delay: Duration(milliseconds: e.key * 80))
                            .fadeIn()
                            .slideX(begin: -0.1),
                      ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
      ),
    );
  }

  Future<void> _showAddTaskDialog(BuildContext context, WidgetRef ref) async {
    final descCtrl = TextEditingController();
    String category = 'social';
    int difficulty = 1;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Eigene Aufgabe erstellen', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: descCtrl,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Aufgabenbeschreibung',
                  hintText: 'Bringe dein Ziel dazu...',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Kategorie'),
                items: const [
                  DropdownMenuItem(value: 'social', child: Text('Sozial')),
                  DropdownMenuItem(value: 'physical', child: Text('Körperlich')),
                  DropdownMenuItem(value: 'object', child: Text('Gegenstand')),
                  DropdownMenuItem(value: 'custom', child: Text('Sonstige')),
                ],
                onChanged: (v) => setState(() => category = v!),
              ),
              const SizedBox(height: 16),
              Text('Schwierigkeit: ${'⭐' * difficulty}'),
              Slider(
                value: difficulty.toDouble(),
                min: 1,
                max: 3,
                divisions: 2,
                label: difficulty.toString(),
                onChanged: (v) => setState(() => difficulty = v.round()),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Aufgabe erstellen',
                onPressed: () async {
                  if (descCtrl.text.trim().isEmpty) return;
                  try {
                    final userId = ref.read(currentUserIdProvider) ?? '';
                    await ref.read(taskRepositoryProvider).createCustomTask(
                          description: descCtrl.text.trim(),
                          category: category,
                          difficulty: difficulty,
                          gameId: gameId,
                          playerId: userId,
                        );
                    ref.invalidate(myTasksProvider(gameId));
                    if (ctx.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (ctx.mounted) showSnack(ctx, 'Fehler: $e', isError: true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final PlayerTask playerTask;
  final bool singleUse;
  final bool consumed;

  const _TaskCard({
    required this.playerTask,
    required this.singleUse,
    required this.consumed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = playerTask.task;
    final isInherited = playerTask.isInherited;

    final diffStars = '⭐' * (task?.difficulty ?? 1);
    final categoryIcons = {'social': '💬', 'physical': '💪', 'object': '🎁', 'custom': '✨'};
    final catIcon = categoryIcons[task?.category] ?? '📋';

    Color borderColor;
    if (consumed) {
      borderColor = Colors.grey.withOpacity(0.3);
    } else if (isInherited) {
      borderColor = Colors.purple.withOpacity(0.6);
    } else {
      borderColor = Colors.orange.withOpacity(0.4);
    }

    return Opacity(
      opacity: consumed ? 0.45 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(catIcon, style: TextStyle(fontSize: 20, color: consumed ? Colors.grey : null)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    task?.description ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: consumed ? Colors.grey : null,
                      decoration: consumed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(diffStars, style: const TextStyle(fontSize: 12)),
                const Spacer(),
                if (isInherited && !consumed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Erbschaft 🩸', style: TextStyle(fontSize: 10, color: Colors.purple)),
                  ),
                if (consumed) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Verbraucht 🚫', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                ] else if (!singleUse && playerTask.isUsed) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('🗡️ eingesetzt', style: TextStyle(fontSize: 10, color: Colors.green)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
