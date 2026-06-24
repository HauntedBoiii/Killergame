import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moerderspiel/data/models/kniffel_game.dart';
import 'package:moerderspiel/data/repositories/kniffel_repository.dart';

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
    FutureProvider.family<List<KniffelDailyEntry>, String?>(
  (ref, gameId) =>
      ref.read(kniffelRepositoryProvider).dailyLeaderboard(gameId: gameId),
);

final kniffelAlltimeLeaderboardProvider =
    FutureProvider.family<List<KniffelAlltimeEntry>, String?>(
  (ref, gameId) =>
      ref.read(kniffelRepositoryProvider).alltimeLeaderboard(gameId: gameId),
);

final dailyKniffelWinnerIdProvider = FutureProvider<String?>(
  (ref) => ref.read(kniffelRepositoryProvider).getDailyWinnerId(),
);

/// Rank of the current user in today's global leaderboard (after completing).
final todayKniffelRankProvider = FutureProvider<int?>((ref) async {
  final game = await ref.watch(kniffelGameProvider.future);
  if (game == null || !game.isCompleted || game.finalScore == null) {
    return null;
  }
  return ref.read(kniffelRepositoryProvider).getTodayRank(game.finalScore!);
});
