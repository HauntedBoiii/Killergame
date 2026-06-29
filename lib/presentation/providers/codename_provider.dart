import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moerderspiel/data/models/codename_session.dart';
import 'package:moerderspiel/data/repositories/codename_repository.dart';

final codenameRepositoryProvider = Provider<CodenameRepository>((ref) {
  return CodenameRepository(Supabase.instance.client);
});

// ── Aktive Sessions des Users (Home-Screen) ────────────────

final activeCodenameSessionsProvider =
    FutureProvider.autoDispose<List<CodenameSession>>((ref) {
  return ref.read(codenameRepositoryProvider).getActiveSessions();
});

// ── Session-Realtime ───────────────────────────────────────

final codenameSessionStreamProvider =
    StreamProvider.autoDispose.family<CodenameSession, String>((ref, id) {
  return ref.read(codenameRepositoryProvider).watchSession(id);
});

final codenamePlayersStreamProvider =
    StreamProvider.autoDispose.family<List<CodenamePlayer>, String>((ref, id) {
  return ref.read(codenameRepositoryProvider).watchPlayers(id);
});

final codenameCluesStreamProvider =
    StreamProvider.autoDispose.family<List<CodenameClue>, String>((ref, id) {
  return ref.read(codenameRepositoryProvider).watchClues(id);
});

final codenameVotesStreamProvider =
    StreamProvider.autoDispose.family<List<CodenameVote>, String>((ref, id) {
  return ref.read(codenameRepositoryProvider).watchVotes(id);
});

// ── Notifier für Create / Join ─────────────────────────────

class CodenameSessionNotifier
    extends AutoDisposeFamilyAsyncNotifier<CodenameSession?, String> {
  @override
  Future<CodenameSession?> build(String sessionId) {
    return ref.read(codenameRepositoryProvider).getSession(sessionId);
  }

  Future<void> start() async {
    final id = arg;
    state = await AsyncValue.guard(() async {
      await ref.read(codenameRepositoryProvider).startSession(id);
      return ref.read(codenameRepositoryProvider).getSession(id);
    });
  }

  Future<void> leave() async {
    await ref.read(codenameRepositoryProvider).leaveSession(arg);
  }

  Future<void> submitClue(String clue) async {
    final id = arg;
    await ref.read(codenameRepositoryProvider).submitClue(id, clue);
  }

  Future<void> submitVote(String votedForId) async {
    await ref.read(codenameRepositoryProvider).submitVote(arg, votedForId);
  }

  Future<bool> impostorGuess(String guess) async {
    return ref.read(codenameRepositoryProvider).impostorGuess(arg, guess);
  }

  Future<void> reload() async {
    final id = arg;
    state = await AsyncValue.guard(
        () => ref.read(codenameRepositoryProvider).getSession(id));
  }
}

final codenameSessionNotifierProvider = AsyncNotifierProvider.autoDispose
    .family<CodenameSessionNotifier, CodenameSession?, String>(
  CodenameSessionNotifier.new,
);
