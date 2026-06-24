import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moerderspiel/data/models/assignment.dart';
import 'package:moerderspiel/data/models/elimination.dart';
import 'package:moerderspiel/data/models/game.dart';
import 'package:moerderspiel/data/models/game_player.dart';
import 'package:moerderspiel/data/models/task.dart';
import 'package:moerderspiel/data/repositories/game_repository.dart';
import 'package:moerderspiel/data/repositories/task_repository.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';

extension _StreamReconnect<T> on Stream<T> {
  Stream<T> ignoreRealtimeErrors() =>
      handleError((e) {}, test: (e) => e is RealtimeSubscribeException);
}

final gameRepositoryProvider = Provider<GameRepository>((_) => GameRepository());
final taskRepositoryProvider = Provider<TaskRepository>((_) => TaskRepository());

// ── All active/lobby games the user is in ─────────────────

final activeGamesProvider = FutureProvider.autoDispose<List<Game>>((ref) {
  return ref.watch(gameRepositoryProvider).getActiveGamesForUser();
});

// ── Game by ID ─────────────────────────────────────────────

final gameProvider = StreamProvider.autoDispose.family<Game?, String>((ref, gameId) {
  return ref.watch(gameRepositoryProvider).watchGame(gameId).ignoreRealtimeErrors();
});

// ── Players in game (real-time with profile join) ──────────

final playersProvider = StreamProvider.autoDispose.family<List<GamePlayer>, String>((ref, gameId) {
  return ref.watch(gameRepositoryProvider).watchPlayers(gameId).ignoreRealtimeErrors();
});

// ── Current user's player entry (derived from stream) ──────

final myPlayerProvider = Provider.autoDispose.family<GamePlayer?, String>((ref, gameId) {
  final userId = ref.watch(currentUserIdProvider);
  final players = ref.watch(playersProvider(gameId)).value ?? [];
  return players.where((p) => p.playerId == userId).firstOrNull;
});

// ── Current assignment (real-time stream) ─────────────────

final assignmentProvider = StreamProvider.autoDispose.family<Assignment?, String>((ref, gameId) {
  final repo = ref.watch(gameRepositoryProvider);
  return repo.watchAssignments(gameId).asyncMap((_) => repo.getMyAssignment(gameId)).ignoreRealtimeErrors();
});

// ── Kill history (real-time with profile join) ────────────

final eliminationsProvider = StreamProvider.autoDispose.family<List<Elimination>, String>((ref, gameId) {
  return ref.watch(gameRepositoryProvider).watchEliminations(gameId).ignoreRealtimeErrors();
});

// ── Pending kill (derived from kill stream) ───────────────

final pendingKillProvider = Provider.autoDispose.family<Elimination?, String>((ref, gameId) {
  final userId = ref.watch(currentUserIdProvider);
  final eliminations = ref.watch(eliminationsProvider(gameId)).value ?? [];
  return eliminations.where((e) => e.victimId == userId && e.isPending).firstOrNull;
});

// ── My tasks (real-time stream mit Task-Join) ──────────────

final myTasksProvider = StreamProvider.autoDispose.family<List<PlayerTask>, String>((ref, gameId) {
  return ref.watch(taskRepositoryProvider).watchMyTasks(gameId).ignoreRealtimeErrors();
});

// ── Admin task pool with per-game enabled state ────────────

typedef AdminTaskEntry = ({Task task, bool isEnabled});

final adminTaskPoolProvider = FutureProvider.autoDispose.family<List<AdminTaskEntry>, String>((ref, gameId) async {
  final repo = ref.read(taskRepositoryProvider);
  final tasks = await repo.getAdminOwnedTasks();
  final disabled = await repo.getDisabledTaskIds(gameId);
  return tasks.map((t) => (task: t, isEnabled: !disabled.contains(t.id))).toList();
});

// ── Finished games ─────────────────────────────────────────

final finishedGamesProvider = FutureProvider.autoDispose<List<Game>>((ref) {
  return ref.watch(gameRepositoryProvider).getFinishedGamesForUser();
});
