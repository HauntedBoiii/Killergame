class Task {
  final String id;
  final String description;
  final String category;
  final int difficulty;
  final bool isBuiltin;
  final String? createdBy;
  final DateTime createdAt;

  const Task({
    required this.id,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.isBuiltin,
    this.createdBy,
    required this.createdAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        description: json['description'] as String,
        category: (json['category'] as String?) ?? 'custom',
        difficulty: (json['difficulty'] as int?) ?? 1,
        isBuiltin: (json['is_builtin'] as bool?) ?? false,
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class PlayerTask {
  final String id;
  final String gameId;
  final String playerId;
  final String taskId;
  final bool isUsed;
  final String? acquiredFrom;
  final DateTime createdAt;

  // Joined
  final Task? task;

  const PlayerTask({
    required this.id,
    required this.gameId,
    required this.playerId,
    required this.taskId,
    required this.isUsed,
    this.acquiredFrom,
    required this.createdAt,
    this.task,
  });

  factory PlayerTask.fromJson(Map<String, dynamic> json) => PlayerTask(
        id: json['id'] as String,
        gameId: json['game_id'] as String,
        playerId: json['player_id'] as String,
        taskId: json['task_id'] as String,
        isUsed: (json['is_used'] as bool?) ?? false,
        acquiredFrom: json['acquired_from'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        task: json['tasks'] != null
            ? Task.fromJson(json['tasks'] as Map<String, dynamic>)
            : null,
      );

  bool get isInherited => acquiredFrom != null;
}
