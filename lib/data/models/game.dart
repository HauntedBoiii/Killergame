enum GameStatus { lobby, active, finished }

enum GameMode { task, object }

class GameSettings {
  final bool teamMode;
  final List<String> safeZones;
  final List<ProtectionTime> protectionTimes;
  final bool requireAdminConfirmation;
  final int initialTasksPerPlayer;
  final bool tasksAreSingleUse;

  const GameSettings({
    this.teamMode = false,
    this.safeZones = const [],
    this.protectionTimes = const [],
    this.requireAdminConfirmation = false,
    this.initialTasksPerPlayer = 1,
    this.tasksAreSingleUse = false,
  });

  factory GameSettings.fromJson(Map<String, dynamic> json) => GameSettings(
        teamMode: (json['team_mode'] as bool?) ?? false,
        safeZones: List<String>.from(json['safe_zones'] ?? []),
        protectionTimes: ((json['protection_times'] as List?) ?? [])
            .map((e) => ProtectionTime.fromJson(e as Map<String, dynamic>))
            .toList(),
        requireAdminConfirmation: (json['require_admin_confirmation'] as bool?) ?? false,
        initialTasksPerPlayer: (json['initial_tasks_per_player'] as int?) ?? 1,
        tasksAreSingleUse: (json['tasks_are_single_use'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'team_mode': teamMode,
        'safe_zones': safeZones,
        'protection_times': protectionTimes.map((e) => e.toJson()).toList(),
        'require_admin_confirmation': requireAdminConfirmation,
        'initial_tasks_per_player': initialTasksPerPlayer,
        'tasks_are_single_use': tasksAreSingleUse,
      };
}

class ProtectionTime {
  final String startTime; // HH:mm
  final String endTime;
  final String? label;

  const ProtectionTime({required this.startTime, required this.endTime, this.label});

  factory ProtectionTime.fromJson(Map<String, dynamic> json) => ProtectionTime(
        startTime: json['start'] as String,
        endTime: json['end'] as String,
        label: json['label'] as String?,
      );

  Map<String, dynamic> toJson() => {'start': startTime, 'end': endTime, 'label': label};
}

class Game {
  final String id;
  final String code;
  final String name;
  final String creatorId;
  final GameStatus status;
  final GameMode mode;
  final GameSettings settings;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? winnerId;
  final DateTime createdAt;

  const Game({
    required this.id,
    required this.code,
    required this.name,
    required this.creatorId,
    required this.status,
    required this.mode,
    required this.settings,
    this.startedAt,
    this.endedAt,
    this.winnerId,
    required this.createdAt,
  });

  factory Game.fromJson(Map<String, dynamic> json) => Game(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        creatorId: json['creator_id'] as String,
        status: GameStatus.values.firstWhere((s) => s.name == json['status'], orElse: () => GameStatus.lobby),
        mode: GameMode.values.firstWhere((m) => m.name == json['mode'], orElse: () => GameMode.task),
        settings: GameSettings.fromJson((json['settings'] as Map<String, dynamic>?) ?? {}),
        startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
        endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : null,
        winnerId: json['winner_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  bool get isLobby => status == GameStatus.lobby;
  bool get isActive => status == GameStatus.active;
  bool get isFinished => status == GameStatus.finished;
}
