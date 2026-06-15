import 'package:moerderspiel/data/models/profile.dart';

class Assignment {
  final String id;
  final String gameId;
  final String killerId;
  final String targetId;
  final bool isActive;
  final DateTime assignedAt;

  // Joined
  final Profile? targetProfile;

  const Assignment({
    required this.id,
    required this.gameId,
    required this.killerId,
    required this.targetId,
    required this.isActive,
    required this.assignedAt,
    this.targetProfile,
  });

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        id: json['id'] as String,
        gameId: json['game_id'] as String,
        killerId: json['killer_id'] as String,
        targetId: json['target_id'] as String,
        isActive: (json['is_active'] as bool?) ?? true,
        assignedAt: DateTime.parse(json['assigned_at'] as String),
        targetProfile: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
      );
}
