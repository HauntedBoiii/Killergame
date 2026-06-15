import 'package:moerderspiel/data/models/profile.dart';

class GamePlayer {
  final String id;
  final String gameId;
  final String playerId;
  final bool isAdmin;
  final bool isReady;
  final bool isAlive;
  final int kills;
  final DateTime joinedAt;
  final DateTime? eliminatedAt;

  // Joined from profiles table
  final Profile? profile;

  const GamePlayer({
    required this.id,
    required this.gameId,
    required this.playerId,
    required this.isAdmin,
    required this.isReady,
    required this.isAlive,
    required this.kills,
    required this.joinedAt,
    this.eliminatedAt,
    this.profile,
  });

  factory GamePlayer.fromJson(Map<String, dynamic> json) => GamePlayer(
        id: json['id'] as String,
        gameId: json['game_id'] as String,
        playerId: json['player_id'] as String,
        isAdmin: (json['is_admin'] as bool?) ?? false,
        isReady: (json['is_ready'] as bool?) ?? false,
        isAlive: (json['is_alive'] as bool?) ?? true,
        kills: (json['kills'] as int?) ?? 0,
        joinedAt: DateTime.parse(json['joined_at'] as String),
        eliminatedAt: json['eliminated_at'] != null
            ? DateTime.parse(json['eliminated_at'] as String)
            : null,
        profile: json['profiles'] != null
            ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
            : null,
      );

  String get displayName => profile?.username ?? playerId.substring(0, 8);
  String? get avatarUrl => profile?.avatarUrl;

  Duration? get survivalTime =>
      eliminatedAt != null ? eliminatedAt!.difference(joinedAt) : null;
}
