import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moerderspiel/data/models/task.dart';

class TaskRepository {
  final _client = Supabase.instance.client;

  Future<List<PlayerTask>> getMyTasks(String gameId) async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('player_tasks')
        .select('*, tasks(*)')
        .eq('game_id', gameId)
        .eq('player_id', userId)
        .order('created_at');

    return (data as List).map((e) => PlayerTask.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> markTaskUsed(String playerTaskId) async {
    await _client.from('player_tasks').update({'is_used': true}).eq('id', playerTaskId);
  }

  Future<List<Task>> getAllTasks() async {
    final data = await _client.from('tasks').select().order('category').order('difficulty');
    return (data as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Task> createCustomTask({
    required String description,
    required String category,
    required int difficulty,
    required String gameId,
    required String playerId,
  }) async {
    final userId = _client.auth.currentUser!.id;

    final taskData = await _client.from('tasks').insert({
      'description': description,
      'category': category,
      'difficulty': difficulty,
      'is_builtin': false,
      'created_by': userId,
    }).select().single();

    final task = Task.fromJson(taskData);

    // Assign to player
    await _client.from('player_tasks').insert({
      'game_id': gameId,
      'player_id': playerId,
      'task_id': task.id,
    });

    return task;
  }

  Future<List<PlayerTask>> getGameCustomTasks(String gameId) async {
    final data = await _client
        .from('player_tasks')
        .select('*, tasks(*)')
        .eq('game_id', gameId)
        .order('created_at');
    final all = (data as List)
        .map((e) => PlayerTask.fromJson(e as Map<String, dynamic>))
        .toList();
    return all.where((pt) => pt.task != null && !pt.task!.isBuiltin).toList();
  }

  Future<void> deleteCustomTask(String playerTaskId, String taskId) async {
    await _client.from('player_tasks').delete().eq('id', playerTaskId);
    await _client.from('tasks').delete().eq('id', taskId);
  }

  Stream<List<PlayerTask>> watchMyTasks(String gameId) {
    return _client
        .from('player_tasks')
        .stream(primaryKey: ['id'])
        .eq('game_id', gameId)
        .asyncMap((_) => getMyTasks(gameId));
  }
}
