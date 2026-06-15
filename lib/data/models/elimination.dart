import 'package:moerderspiel/data/models/profile.dart';
import 'package:moerderspiel/data/models/task.dart';

enum EliminationStatus { pending, confirmed, rejected }

class Elimination {
  final String id;
  final String gameId;
  final String killerId;
  final String victimId;
  final String? taskId;
  final EliminationStatus status;
  final String? confirmedBy;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  // Joined
  final Profile? killerProfile;
  final Profile? victimProfile;
  final Task? task;

  const Elimination({
    required this.id,
    required this.gameId,
    required this.killerId,
    required this.victimId,
    this.taskId,
    required this.status,
    this.confirmedBy,
    required this.createdAt,
    this.confirmedAt,
    this.killerProfile,
    this.victimProfile,
    this.task,
  });

  factory Elimination.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'] as String? ?? 'pending';
    return Elimination(
      id: json['id'] as String,
      gameId: json['game_id'] as String,
      killerId: json['killer_id'] as String,
      victimId: json['victim_id'] as String,
      taskId: json['task_id'] as String?,
      status: EliminationStatus.values.firstWhere(
        (s) => s.name == rawStatus,
        orElse: () => EliminationStatus.pending,
      ),
      confirmedBy: json['confirmed_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.parse(json['confirmed_at'] as String)
          : null,
      killerProfile: json['killer_profile'] != null
          ? Profile.fromJson(json['killer_profile'] as Map<String, dynamic>)
          : null,
      victimProfile: json['victim_profile'] != null
          ? Profile.fromJson(json['victim_profile'] as Map<String, dynamic>)
          : null,
      task: json['tasks'] != null
          ? Task.fromJson(json['tasks'] as Map<String, dynamic>)
          : null,
    );
  }

  bool get isPending => status == EliminationStatus.pending;
  bool get isConfirmed => status == EliminationStatus.confirmed;
}
