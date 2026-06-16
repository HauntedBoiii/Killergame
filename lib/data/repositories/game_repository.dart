import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moerderspiel/data/models/assignment.dart';
import 'package:moerderspiel/data/models/elimination.dart';
import 'package:moerderspiel/data/models/game.dart';
import 'package:moerderspiel/data/models/game_player.dart';

class GameRepository {
  final _client = Supabase.instance.client;

  // ── Create / Join ──────────────────────────────────────────

  Future<Game> createGame({
    required String name,
    required GameMode mode,
    required GameSettings settings,
  }) async {
    final code = await _client.rpc('generate_game_code') as String;
    final userId = _client.auth.currentUser!.id;

    final gameData = await _client.from('games').insert({
      'code': code,
      'name': name,
      'creator_id': userId,
      'mode': mode.name,
      'settings': settings.toJson(),
    }).select().single();

    final game = Game.fromJson(gameData);

    await _client.from('game_players').insert({
      'game_id': game.id,
      'player_id': userId,
      'is_admin': true,
      'is_ready': true,
    });

    return game;
  }

  Future<Game> joinGame(String code) async {
    // Uses SECURITY DEFINER function to bypass RLS — non-members can't SELECT games directly
    final result = await _client
        .rpc('join_game_by_code', params: {'p_code': code.toUpperCase()});
    return Game.fromJson(Map<String, dynamic>.from(result as Map));
  }

  Future<Map<String, dynamic>> leaveGame(String gameId) async {
    final result = await _client.rpc('leave_game', params: {'game_id_param': gameId});
    return Map<String, dynamic>.from(result as Map);
  }

  // ── Game State ─────────────────────────────────────────────

  Future<Game?> getGame(String gameId) async {
    final data = await _client.from('games').select().eq('id', gameId).maybeSingle();
    return data != null ? Game.fromJson(data) : null;
  }

  Future<List<Game>> getActiveGamesForUser() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('game_players')
        .select('game_id, games(*)')
        .eq('player_id', userId)
        .inFilter('games.status', ['lobby', 'active'])
        .order('joined_at', ascending: false);

    return (data as List)
        .where((e) => e['games'] != null)
        .map((e) => Game.fromJson(e['games'] as Map<String, dynamic>))
        .toList();
  }

  Future<List<Game>> getFinishedGamesForUser() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('game_players')
        .select('game_id, games(*)')
        .eq('player_id', userId)
        .eq('games.status', 'finished')
        .order('joined_at', ascending: false);

    return (data as List)
        .where((e) => e['games'] != null)
        .map((e) => Game.fromJson(e['games'] as Map<String, dynamic>))
        .toList();
  }

  // ── Players ────────────────────────────────────────────────

  Future<List<GamePlayer>> getPlayers(String gameId) async {
    final data = await _client
        .from('game_players')
        .select('*, profiles(*)')
        .eq('game_id', gameId)
        .order('joined_at');

    return (data as List).map((e) => GamePlayer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<GamePlayer?> getMyPlayerEntry(String gameId) async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('game_players')
        .select('*, profiles(*)')
        .eq('game_id', gameId)
        .eq('player_id', userId)
        .maybeSingle();

    return data != null ? GamePlayer.fromJson(data) : null;
  }

  Future<void> setReady(String gameId, bool ready) async {
    final userId = _client.auth.currentUser!.id;
    await _client
        .from('game_players')
        .update({'is_ready': ready})
        .eq('game_id', gameId)
        .eq('player_id', userId);
  }

  Future<void> removePlayer(String gameId, String playerId) async {
    await _client
        .from('game_players')
        .delete()
        .eq('game_id', gameId)
        .eq('player_id', playerId);
  }

  // ── Admin Controls ─────────────────────────────────────────

  Future<void> startGame(String gameId) async {
    await _client.rpc('start_game', params: {'game_id_param': gameId});
  }

  Future<void> updateGameSettings(String gameId, GameSettings settings) async {
    await _client.from('games').update({'settings': settings.toJson()}).eq('id', gameId);
  }

  Future<List<Map<String, dynamic>>> getBrokenAssignments(String gameId) async {
    final result = await _client.rpc('get_broken_assignments', params: {'game_id_param': gameId});
    if (result == null) return [];
    return (result as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> swapAssignments(String gameId, String playerAId, String playerBId) async {
    await _client.rpc('admin_swap_assignments', params: {
      'game_id_param': gameId,
      'player_a_id': playerAId,
      'player_b_id': playerBId,
    });
  }

  // ── Assignments ────────────────────────────────────────────

  Future<Assignment?> getMyAssignment(String gameId) async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('assignments')
        .select()
        .eq('game_id', gameId)
        .eq('killer_id', userId)
        .eq('is_active', true)
        .order('assigned_at', ascending: false)
        .limit(1);

    if ((rows as List).isEmpty) return null;

    final map = Map<String, dynamic>.from(rows.first as Map);

    // Fetch target profile separately — avoids FK-name dependency
    final targetId = map['target_id'] as String?;
    if (targetId != null) {
      final profileData = await _client
          .from('profiles')
          .select()
          .eq('id', targetId)
          .maybeSingle();
      map['profiles'] = profileData;
    }

    return Assignment.fromJson(map);
  }

  // ── Eliminations ───────────────────────────────────────────

  Future<void> reportKill({
    required String gameId,
    required String victimId,
    String? taskId,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('eliminations').insert({
      'game_id': gameId,
      'killer_id': userId,
      'victim_id': victimId,
      'task_id': taskId,
      'status': 'pending',
    });
  }

  Future<Map<String, dynamic>> confirmKill(String eliminationId) async {
    final result = await _client.rpc('confirm_kill', params: {'elimination_id_param': eliminationId});
    return result as Map<String, dynamic>;
  }

  Future<void> rejectKill(String eliminationId) async {
    await _client
        .from('eliminations')
        .update({'status': 'rejected'})
        .eq('id', eliminationId);
  }

  Future<List<Elimination>> getEliminations(String gameId) async {
    final data = await _client
        .from('eliminations')
        .select('*, tasks(*)')
        .eq('game_id', gameId)
        .order('created_at', ascending: false);

    if ((data as List).isEmpty) return [];

    final profileIds = <String>{};
    for (final e in data) {
      profileIds.add(e['killer_id'] as String);
      profileIds.add(e['victim_id'] as String);
    }

    final profiles = await _client
        .from('profiles')
        .select()
        .inFilter('id', profileIds.toList());
    final profileMap = {
      for (final p in profiles as List)
        p['id'] as String: Map<String, dynamic>.from(p as Map<String, dynamic>),
    };

    return data.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      map['killer_profile'] = profileMap[map['killer_id'] as String];
      map['victim_profile'] = profileMap[map['victim_id'] as String];
      return Elimination.fromJson(map);
    }).toList();
  }

  Future<Elimination?> getPendingKillForMe(String gameId) async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('eliminations')
        .select('*, tasks(*)')
        .eq('game_id', gameId)
        .eq('victim_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(1);

    if ((rows as List).isEmpty) return null;
    final map = Map<String, dynamic>.from(rows.first as Map);
    final killerData = await _client
        .from('profiles')
        .select()
        .eq('id', map['killer_id'] as String)
        .maybeSingle();
    map['killer_profile'] = killerData;
    map['victim_profile'] = null;
    return Elimination.fromJson(map);
  }

  // ── Realtime Streams ───────────────────────────────────────

  Stream<List<GamePlayer>> watchPlayers(String gameId) {
    return _client
        .from('game_players')
        .stream(primaryKey: ['id'])
        .eq('game_id', gameId)
        .asyncMap((_) => getPlayers(gameId));
  }

  Stream<Game?> watchGame(String gameId) {
    return _client
        .from('games')
        .stream(primaryKey: ['id'])
        .eq('id', gameId)
        .map((rows) => rows.isNotEmpty ? Game.fromJson(rows.first) : null);
  }

  Stream<List<Elimination>> watchEliminations(String gameId) {
    return _client
        .from('eliminations')
        .stream(primaryKey: ['id'])
        .eq('game_id', gameId)
        .asyncMap((_) => getEliminations(gameId));
  }

  Stream<List<Map<String, dynamic>>> watchAssignments(String gameId) {
    final userId = _client.auth.currentUser!.id;
    return _client
        .from('assignments')
        .stream(primaryKey: ['id'])
        .eq('game_id', gameId)
        .map((rows) => rows.where((r) => r['killer_id'] == userId && r['is_active'] == true).toList());
  }
}
