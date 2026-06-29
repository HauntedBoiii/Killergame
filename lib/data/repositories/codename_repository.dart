import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moerderspiel/data/models/codename_session.dart';

class CodenameRepository {
  const CodenameRepository(this._client);
  final SupabaseClient _client;

  // ── Write (via SECURITY DEFINER RPCs) ─────────────────────

  Future<CodenameSession> createSession({
    required String name,
    String category = 'all',
    String mode = 'online',
  }) async {
    final data = await _client.rpc('codename_create_session', params: {
      'p_name':     name,
      'p_category': category,
      'p_mode':     mode,
    });
    return CodenameSession.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<CodenameSession> joinSession(String code) async {
    final data = await _client.rpc('codename_join', params: {'p_code': code});
    return CodenameSession.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> leaveSession(String sessionId) async {
    await _client.rpc('codename_leave', params: {'p_session_id': sessionId});
  }

  Future<void> startSession(String sessionId) async {
    await _client.rpc('codename_start', params: {'p_session_id': sessionId});
  }

  Future<void> submitClue(String sessionId, String clue) async {
    await _client.rpc('codename_submit_clue', params: {
      'p_session_id': sessionId,
      'p_clue':       clue,
    });
  }

  Future<void> submitVote(String sessionId, String votedForId) async {
    await _client.rpc('codename_submit_vote', params: {
      'p_session_id':    sessionId,
      'p_voted_for_id':  votedForId,
    });
  }

  Future<bool> impostorGuess(String sessionId, String guess) async {
    final result = await _client.rpc('codename_impostor_guess', params: {
      'p_session_id': sessionId,
      'p_guess':      guess,
    });
    return result as bool;
  }

  // ── Read ───────────────────────────────────────────────────

  Future<List<CodenameSession>> getActiveSessions() async {
    final rows = await _client
        .from('codename_sessions')
        .select()
        .inFilter('status', ['lobby', 'active'])
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => CodenameSession.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<CodenameSession?> getSession(String sessionId) async {
    final row = await _client
        .from('codename_sessions')
        .select()
        .eq('id', sessionId)
        .maybeSingle();
    return row == null ? null : CodenameSession.fromJson(row);
  }

  // ── Realtime Streams ───────────────────────────────────────

  Stream<CodenameSession> watchSession(String sessionId) {
    return _client
        .from('codename_sessions')
        .stream(primaryKey: ['id'])
        .eq('id', sessionId)
        .map((rows) => rows.isEmpty
            ? null
            : CodenameSession.fromJson(rows.first))
        .where((s) => s != null)
        .cast<CodenameSession>();
  }

  Stream<List<CodenamePlayer>> watchPlayers(String sessionId) {
    return _client
        .from('codename_players')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('turn_order')
        .map((rows) => rows
            .map((r) => CodenamePlayer.fromJson(r))
            .toList());
  }

  Stream<List<CodenameClue>> watchClues(String sessionId) {
    return _client
        .from('codename_clues')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('round')
        .map((rows) => rows
            .map((r) => CodenameClue.fromJson(r))
            .toList());
  }

  Stream<List<CodenameVote>> watchVotes(String sessionId) {
    return _client
        .from('codename_votes')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .map((rows) => rows
            .map((r) => CodenameVote.fromJson(r))
            .toList());
  }
}
