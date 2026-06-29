class Profile {
  final String id;
  final String username;
  final String? avatarUrl;
  final int totalKills;
  final int totalGames;
  final int totalWins;
  final bool rpsBonusAvailable;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.totalKills = 0,
    this.totalGames = 0,
    this.totalWins = 0,
    this.rpsBonusAvailable = false,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
        totalKills: (json['total_kills'] as int?) ?? 0,
        totalGames: (json['total_games'] as int?) ?? 0,
        totalWins: (json['total_wins'] as int?) ?? 0,
        rpsBonusAvailable: (json['rps_bonus_available'] as bool?) ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'avatar_url': avatarUrl,
        'total_kills': totalKills,
        'total_games': totalGames,
        'total_wins': totalWins,
      };
}
