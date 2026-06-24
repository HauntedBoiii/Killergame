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

  Future<List<Task>> getAdminOwnedTasks() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('tasks')
        .select()
        .eq('created_by', userId)
        .eq('is_builtin', false)
        .order('created_at');
    return (data as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Set<String>> getDisabledTaskIds(String gameId) async {
    final data = await _client
        .from('game_task_disabled')
        .select('task_id')
        .eq('game_id', gameId);
    return {for (final row in data as List) row['task_id'] as String};
  }

  Future<void> setTaskDisabled(String gameId, String taskId, {required bool disabled}) async {
    if (disabled) {
      await _client.from('game_task_disabled').insert({'game_id': gameId, 'task_id': taskId});
    } else {
      await _client.from('game_task_disabled').delete()
          .eq('game_id', gameId).eq('task_id', taskId);
    }
  }

  Future<Task> createAdminTask({
    required String description,
    required int difficulty,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client.from('tasks').insert({
      'description': description,
      'category': 'custom',
      'difficulty': difficulty,
      'is_builtin': false,
      'created_by': userId,
    }).select().single();
    return Task.fromJson(data);
  }

  Future<void> deleteAdminTask(String taskId) async {
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
