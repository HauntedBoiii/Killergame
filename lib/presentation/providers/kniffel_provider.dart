import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moerderspiel/data/models/kniffel_game.dart';
import 'package:moerderspiel/data/repositories/kniffel_repository.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';

final kniffelRepositoryProvider = Provider<KniffelRepository>((ref) {
  return KniffelRepository(Supabase.instance.client);
});

class KniffelNotifier extends AsyncNotifier<KniffelGame?> {
  @override
  Future<KniffelGame?> build() =>
      ref.read(kniffelRepositoryProvider).getTodayGame();

  Future<void> startOrResume() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(kniffelRepositoryProvider).startOrResume(),
    );
  }

  Future<void> startOrResumeBonus() async {
    if (state.isLoading) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(kniffelRepositoryProvider).startOrResumeBonus(),
    );
    ref.invalidate(profileProvider);
  }

  Future<void> roll(List<bool> held) async {
    final id = state.value?.id;
    if (id == null) return;
    final next = await AsyncValue.guard(
      () => ref.read(kniffelRepositoryProvider).roll(id, held),
    );
    state = next;
  }

  Future<void> selectCategory(String category, int score) async {
    final id = state.value?.id;
    if (id == null) return;
    final next = await AsyncValue.guard(
      () => ref
          .read(kniffelRepositoryProvider)
          .selectCategory(id, category, score),
    );
    state = next;
    if (next.value?.isCompleted == true) {
      ref.invalidate(dailyKniffelWinnerIdProvider);
      ref.invalidate(kniffelDailyLeaderboardProvider);
      ref.invalidate(todayKniffelRankProvider);
    }
  }
}

final kniffelGameProvider =
    AsyncNotifierProvider<KniffelNotifier, KniffelGame?>(KniffelNotifier.new);

final kniffelDailyLeaderboardProvider =
    FutureProvider.autoDispose.family<List<KniffelDailyEntry>, String?>(
  (ref, gameId) =>
      ref.read(kniffelRepositoryProvider).dailyLeaderboard(gameId: gameId),
);

final kniffelAlltimeLeaderboardProvider =
    FutureProvider.autoDispose.family<List<KniffelAlltimeEntry>, String?>(
  (ref, gameId) =>
      ref.read(kniffelRepositoryProvider).alltimeLeaderboard(gameId: gameId),
);

final dailyKniffelWinnerIdProvider = FutureProvider.autoDispose<String?>(
  (ref) => ref.read(kniffelRepositoryProvider).getDailyWinnerId(),
);

/// User ID of the global alltime leader (highest total score ever).
final alltimeLeaderIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  final entries = await ref
      .read(kniffelRepositoryProvider)
      .alltimeLeaderboard(gameId: null);
  return entries.isEmpty ? null : entries.first.userId;
});

/// Winners (rank 1) and last-place user IDs for today – used for crown/clown badges.
final dailyKniffelBadgesProvider = FutureProvider.autoDispose<
    ({Set<String> winners, Set<String> lastPlace})>((ref) async {
  final entries = await ref
      .read(kniffelRepositoryProvider)
      .dailyLeaderboard(gameId: null);
  if (entries.isEmpty) return (winners: <String>{}, lastPlace: <String>{});
  final maxRank =
      entries.map((e) => e.rank).reduce((a, b) => a > b ? a : b);
  final winners =
      entries.where((e) => e.rank == 1).map((e) => e.userId).toSet();
  final lastPlace = entries.length > 1
      ? entries.where((e) => e.rank == maxRank).map((e) => e.userId).toSet()
      : <String>{};
  return (winners: winners, lastPlace: lastPlace);
});

final kniffelScorecardProvider =
    FutureProvider.autoDispose.family<KniffelGame, String>(
  (ref, gameId) =>
      ref.read(kniffelRepositoryProvider).getGameById(gameId),
);

/// Rank of the current user in today's global leaderboard (after completing).
final todayKniffelRankProvider = FutureProvider.autoDispose<int?>((ref) async {
  final game = await ref.watch(kniffelGameProvider.future);
  if (game == null || !game.isCompleted || game.finalScore == null) {
    return null;
  }
  return ref.read(kniffelRepositoryProvider).getTodayRank(game.finalScore!);
});
