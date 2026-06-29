import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moerderspiel/data/models/kniffel_game.dart';

class KniffelRepository {
  const KniffelRepository(this._client);
  final SupabaseClient _client;

  String get _today =>
      DateTime.now().toUtc().toIso8601String().split('T').first;

  Future<KniffelGame> startOrResume() async {
    final data = await _client.rpc('kniffel_start_or_resume', params: {'p_is_bonus': false});
    return KniffelGame.fromJson(data as Map<String, dynamic>);
  }

  Future<KniffelGame> startOrResumeBonus() async {
    final data = await _client.rpc('kniffel_start_or_resume', params: {'p_is_bonus': true});
    return KniffelGame.fromJson(data as Map<String, dynamic>);
  }

  Future<KniffelGame?> getTodayGame() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    // Prefer in-progress bonus game so players can continue it after navigating away
    final bonus = await _client
        .from('kniffel_games')
        .select()
        .eq('user_id', userId)
        .eq('game_date', _today)
        .eq('is_bonus', true)
        .eq('status', 'in_progress')
        .maybeSingle();
    if (bonus != null) return KniffelGame.fromJson(bonus);

    final normal = await _client
        .from('kniffel_games')
        .select()
        .eq('user_id', userId)
        .eq('game_date', _today)
        .eq('is_bonus', false)
        .maybeSingle();
    return normal == null ? null : KniffelGame.fromJson(normal);
  }

  Future<KniffelGame> roll(String gameId, List<bool> held) async {
    final data = await _client.rpc('kniffel_roll', params: {
      'p_game_id': gameId,
      'p_held': held,
    });
    return KniffelGame.fromJson(data as Map<String, dynamic>);
  }

  Future<KniffelGame> selectCategory(
    String gameId,
    String category,
    int score,
  ) async {
    final data = await _client.rpc('kniffel_select_category', params: {
      'p_game_id': gameId,
      'p_category': category,
      'p_score': score,
    });
    return KniffelGame.fromJson(data as Map<String, dynamic>);
  }

  Future<List<KniffelDailyEntry>> dailyLeaderboard({String? gameId}) async {
    final data = await _client.rpc(
      'kniffel_daily_leaderboard',
      params: {'p_game_id': gameId},
    );
    return (data as List)
        .map((e) => KniffelDailyEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<KniffelAlltimeEntry>> alltimeLeaderboard({String? gameId}) async {
    final data = await _client.rpc(
      'kniffel_alltime_leaderboard',
      params: {'p_game_id': gameId},
    );
    return (data as List)
        .map((e) => KniffelAlltimeEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String?> getDailyWinnerId() async {
    final data = await _client
        .from('kniffel_games')
        .select('user_id')
        .eq('game_date', _today)
        .eq('status', 'completed')
        .order('final_score', ascending: false)
        .limit(1)
        .maybeSingle();
    return data?['user_id'] as String?;
  }

  Future<KniffelGame> getGameById(String gameId) async {
    final data = await _client
        .from('kniffel_games')
        .select()
        .eq('id', gameId)
        .single();
    return KniffelGame.fromJson(data);
  }

  /// Returns rank of myScore in today's leaderboard (counting distinct users
  /// whose BEST score today strictly exceeds myScore).
  Future<int?> getTodayRank(int myScore) async {
    final data = await _client
        .from('kniffel_games')
        .select('user_id, final_score')
        .eq('game_date', _today)
        .eq('status', 'completed');
    final rows = data as List;
    // Group by user_id, take max score, count how many beat myScore
    final Map<String, int> bestPerUser = {};
    for (final row in rows) {
      final uid = row['user_id'] as String;
      final score = (row['final_score'] as num).toInt();
      if ((bestPerUser[uid] ?? 0) < score) bestPerUser[uid] = score;
    }
    final ahead = bestPerUser.values.where((s) => s > myScore).length;
    return ahead + 1;
  }
}
