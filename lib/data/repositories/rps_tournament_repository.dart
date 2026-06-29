import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moerderspiel/data/models/rps_tournament.dart';

class RpsTournamentRepository {
  const RpsTournamentRepository(this._client);
  final SupabaseClient _client;

  String get _today =>
      DateTime.now().toUtc().toIso8601String().split('T').first;

  Future<String> startTournament() async {
    final data = await _client.rpc('rps_start_tournament');
    return data as String;
  }

  Future<void> submitChoice(String matchId, RpsChoice choice) async {
    await _client.rpc('rps_submit_choice', params: {
      'p_match_id': matchId,
      'p_choice':   choice.name,
    });
  }

  Future<RpsTournament?> getTodayTournament() async {
    final tournament = await _client
        .from('rps_tournaments')
        .select()
        .gte('created_at', '${_today}T00:00:00Z')
        .lt('created_at', '${_nextDay}T00:00:00Z')
        .maybeSingle();

    if (tournament == null) return null;

    final matchRows = await _client
        .from('rps_matches')
        .select()
        .eq('tournament_id', tournament['id'] as String)
        .order('round')
        .order('match_slot');

    final matches = (matchRows as List)
        .map((m) => RpsMatch.fromJson(m as Map<String, dynamic>))
        .toList();

    return RpsTournament.fromJson(tournament, matches);
  }

  Stream<List<RpsMatch>> watchMatches(String tournamentId) {
    return _client
        .from('rps_matches')
        .stream(primaryKey: ['id'])
        .eq('tournament_id', tournamentId)
        .map((rows) => rows.map((r) => RpsMatch.fromJson(r)).toList());
  }

  String get _nextDay {
    final d = DateTime.now().toUtc();
    return DateTime.utc(d.year, d.month, d.day + 1)
        .toIso8601String()
        .split('T')
        .first;
  }
}
