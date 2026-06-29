enum KniffelStatus { inProgress, completed }

const List<String> kKniffelUpperCategories = [
  'ones', 'twos', 'threes', 'fours', 'fives', 'sixes',
];

const List<String> kKniffelLowerCategories = [
  'three_of_a_kind', 'four_of_a_kind', 'full_house',
  'small_straight', 'large_straight', 'yahtzee', 'chance',
];

const List<String> kKniffelAllCategories = [
  ...kKniffelUpperCategories,
  ...kKniffelLowerCategories,
];

const Map<String, String> kCategoryNames = {
  'ones': 'Einser',
  'twos': 'Zweier',
  'threes': 'Dreier',
  'fours': 'Vierer',
  'fives': 'Fünfer',
  'sixes': 'Sechser',
  'three_of_a_kind': 'Dreierpasch',
  'four_of_a_kind': 'Viererpasch',
  'full_house': 'Full House',
  'small_straight': 'Kleine Straße',
  'large_straight': 'Große Straße',
  'yahtzee': 'Kniffel',
  'chance': 'Chance',
};

const Map<String, String> kCategoryHints = {
  'ones': 'Nur Einser',
  'twos': 'Nur Zweier',
  'threes': 'Nur Dreier',
  'fours': 'Nur Vierer',
  'fives': 'Nur Fünfer',
  'sixes': 'Nur Sechser',
  'three_of_a_kind': 'Dreierpasch · alle Augen',
  'four_of_a_kind': 'Viererpasch · alle Augen',
  'full_house': '3 + 2 Gleiche = 25',
  'small_straight': '4 in Folge = 30',
  'large_straight': '5 in Folge = 40',
  'yahtzee': 'Alle gleich = 50',
  'chance': 'Alle Augen',
};

class KniffelScoreEntry {
  final int score;
  final List<int> dice;

  const KniffelScoreEntry({required this.score, required this.dice});

  factory KniffelScoreEntry.fromJson(Map<String, dynamic> json) =>
      KniffelScoreEntry(
        score: (json['score'] as num).toInt(),
        dice: (json['dice'] as List).map((d) => (d as num).toInt()).toList(),
      );
}

class KniffelGame {
  final String id;
  final String userId;
  final DateTime gameDate;
  final KniffelStatus status;
  final int? finalScore;
  final List<int>? currentDice;
  final List<bool>? heldDice;
  final int rollCount;
  final int currentTurn;
  final Map<String, KniffelScoreEntry> scorecard;
  final DateTime? submittedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool crownBonusAvailable;
  final bool crownBonusUsed;
  final bool isBonus;

  const KniffelGame({
    required this.id,
    required this.userId,
    required this.gameDate,
    required this.status,
    this.finalScore,
    this.currentDice,
    this.heldDice,
    required this.rollCount,
    required this.currentTurn,
    required this.scorecard,
    this.submittedAt,
    required this.createdAt,
    required this.updatedAt,
    this.crownBonusAvailable = false,
    this.crownBonusUsed = false,
    this.isBonus = false,
  });

  bool get isCompleted => status == KniffelStatus.completed;
  bool get canRoll => !isCompleted && (rollCount < 3 || crownBonusAvailable);
  bool get mustSelectCategory => !isCompleted && rollCount >= 3 && !crownBonusAvailable;
  bool get canSelectCategory => !isCompleted && rollCount >= 1;

  int get upperSum {
    int sum = 0;
    for (final cat in kKniffelUpperCategories) {
      if (scorecard.containsKey(cat)) { sum += scorecard[cat]!.score; }
    }
    return sum;
  }

  bool get hasBonus => upperSum >= 63;
  int get bonus => hasBonus ? 35 : 0;

  int get runningTotal {
    if (finalScore != null) return finalScore!;
    int sum = bonus;
    for (final entry in scorecard.values) { sum += entry.score; }
    return sum;
  }

  factory KniffelGame.fromJson(Map<String, dynamic> json) {
    final raw = json['scorecard'];
    final scorecardJson =
        (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
    final scorecard = scorecardJson.map(
      (k, v) =>
          MapEntry(k, KniffelScoreEntry.fromJson(v as Map<String, dynamic>)),
    );

    List<int>? parseDice(dynamic val) {
      if (val == null) return null;
      return (val as List).map((d) => (d as num).toInt()).toList();
    }

    List<bool>? parseHeld(dynamic val) {
      if (val == null) return null;
      return (val as List).map((d) => d as bool).toList();
    }

    return KniffelGame(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      gameDate: DateTime.parse(json['game_date'] as String),
      status: (json['status'] as String) == 'completed'
          ? KniffelStatus.completed
          : KniffelStatus.inProgress,
      finalScore: json['final_score'] as int?,
      currentDice: parseDice(json['current_dice']),
      heldDice: parseHeld(json['held_dice']),
      rollCount: (json['roll_count'] as num?)?.toInt() ?? 0,
      currentTurn: (json['current_turn'] as num?)?.toInt() ?? 0,
      scorecard: scorecard,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      crownBonusAvailable: json['crown_bonus_available'] as bool? ?? false,
      crownBonusUsed: json['crown_bonus_used'] as bool? ?? false,
      isBonus: json['is_bonus'] as bool? ?? false,
    );
  }
}

class KniffelDailyEntry {
  final String gameId;
  final String userId;
  final String username;
  final String? avatarUrl;
  final int finalScore;
  final DateTime? submittedAt;
  final int rank;

  const KniffelDailyEntry({
    required this.gameId,
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.finalScore,
    this.submittedAt,
    required this.rank,
  });

  factory KniffelDailyEntry.fromJson(Map<String, dynamic> json) =>
      KniffelDailyEntry(
        gameId: json['game_id'] as String,
        userId: json['user_id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
        finalScore: (json['final_score'] as num).toInt(),
        submittedAt: json['submitted_at'] != null
            ? DateTime.parse(json['submitted_at'] as String)
            : null,
        rank: (json['rank'] as num).toInt(),
      );
}

class KniffelAlltimeEntry {
  final String userId;
  final String username;
  final String? avatarUrl;
  final int totalScore;
  final double avgScore;
  final int daysPlayed;
  final int bestScore;
  final int dailyWins;
  final int dailyLosses;

  const KniffelAlltimeEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.totalScore,
    required this.avgScore,
    required this.daysPlayed,
    required this.bestScore,
    required this.dailyWins,
    required this.dailyLosses,
  });

  factory KniffelAlltimeEntry.fromJson(Map<String, dynamic> json) =>
      KniffelAlltimeEntry(
        userId: json['user_id'] as String,
        username: json['username'] as String,
        avatarUrl: json['avatar_url'] as String?,
        totalScore: (json['total_score'] as num).toInt(),
        avgScore: (json['avg_score'] as num).toDouble(),
        daysPlayed: (json['days_played'] as num).toInt(),
        bestScore: (json['best_score'] as num).toInt(),
        dailyWins: (json['daily_wins'] as num).toInt(),
        dailyLosses: (json['daily_losses'] as num?)?.toInt() ?? 0,
      );
}
