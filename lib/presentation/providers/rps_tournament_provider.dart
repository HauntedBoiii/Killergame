import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moerderspiel/data/models/rps_tournament.dart';
import 'package:moerderspiel/data/repositories/rps_tournament_repository.dart';

/// Liefert den Anzeigenamen eines Users per ID (für globalen Turnier-Kontext).
final usernameByIdProvider =
    FutureProvider.autoDispose.family<String, String>((ref, userId) async {
  final data = await Supabase.instance.client
      .from('profiles')
      .select('username')
      .eq('id', userId)
      .maybeSingle();
  return (data?['username'] as String?) ?? userId.substring(0, 8);
});

/// Liefert Avatar-URL eines Users per ID (null wenn keiner gesetzt).
final avatarUrlByIdProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, userId) async {
  final data = await Supabase.instance.client
      .from('profiles')
      .select('avatar_url')
      .eq('id', userId)
      .maybeSingle();
  return data?['avatar_url'] as String?;
});

final rpsTournamentRepositoryProvider = Provider<RpsTournamentRepository>((ref) {
  return RpsTournamentRepository(Supabase.instance.client);
});

final rpsMatchesStreamProvider =
    StreamProvider.autoDispose.family<List<RpsMatch>, String>((ref, tournamentId) {
  return ref.read(rpsTournamentRepositoryProvider).watchMatches(tournamentId);
});

class RpsTournamentNotifier extends AutoDisposeAsyncNotifier<RpsTournament?> {
  @override
  Future<RpsTournament?> build() =>
      ref.read(rpsTournamentRepositoryProvider).getTodayTournament();

  Future<void> startTournament() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(rpsTournamentRepositoryProvider).startTournament();
      return ref.read(rpsTournamentRepositoryProvider).getTodayTournament();
    });
  }

  Future<void> submitChoice(String matchId, RpsChoice choice) async {
    state = await AsyncValue.guard(() async {
      await ref.read(rpsTournamentRepositoryProvider).submitChoice(matchId, choice);
      return ref.read(rpsTournamentRepositoryProvider).getTodayTournament();
    });
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(
      () => ref.read(rpsTournamentRepositoryProvider).getTodayTournament(),
    );
  }
}

final rpsTournamentNotifierProvider =
    AsyncNotifierProvider.autoDispose<RpsTournamentNotifier, RpsTournament?>(
  RpsTournamentNotifier.new,
);
