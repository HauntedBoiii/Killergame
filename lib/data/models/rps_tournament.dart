enum RpsTournamentStatus { inProgress, completed }

enum RpsChoice { rock, paper, scissors }

extension RpsChoiceX on RpsChoice {
  String get name => switch (this) {
        RpsChoice.rock     => 'rock',
        RpsChoice.paper    => 'paper',
        RpsChoice.scissors => 'scissors',
      };

  String get emoji => switch (this) {
        RpsChoice.rock     => '✊',
        RpsChoice.paper    => '🖐',
        RpsChoice.scissors => '✌️',
      };

  String get label => switch (this) {
        RpsChoice.rock     => 'Stein',
        RpsChoice.paper    => 'Papier',
        RpsChoice.scissors => 'Schere',
      };

  static RpsChoice? fromString(String? s) => switch (s) {
        'rock'     => RpsChoice.rock,
        'paper'    => RpsChoice.paper,
        'scissors' => RpsChoice.scissors,
        _          => null,
      };
}

class RpsMatch {
  final String id;
  final String tournamentId;
  final int round;
  final int matchSlot;
  final String playerAId;
  final String? playerBId;
  final RpsChoice? choiceA;
  final RpsChoice? choiceB;
  final String? winnerId;
  final bool isBye;
  final DateTime? deadline;
  final DateTime createdAt;

  const RpsMatch({
    required this.id,
    required this.tournamentId,
    required this.round,
    required this.matchSlot,
    required this.playerAId,
    this.playerBId,
    this.choiceA,
    this.choiceB,
    this.winnerId,
    required this.isBye,
    this.deadline,
    required this.createdAt,
  });

  bool get isComplete  => winnerId != null;
  bool get isTie       => choiceA != null && choiceB != null && winnerId == null && !isBye;
  bool get bothChosen  => choiceA != null && choiceB != null;

  factory RpsMatch.fromJson(Map<String, dynamic> json) => RpsMatch(
        id:           json['id']            as String,
        tournamentId: json['tournament_id'] as String,
        round:        (json['round']        as num).toInt(),
        matchSlot:    (json['match_slot']   as num).toInt(),
        playerAId:    json['player_a_id']   as String,
        playerBId:    json['player_b_id']   as String?,
        choiceA:      RpsChoiceX.fromString(json['choice_a'] as String?),
        choiceB:      RpsChoiceX.fromString(json['choice_b'] as String?),
        winnerId:     json['winner_id']     as String?,
        isBye:        json['is_bye']        as bool? ?? false,
        deadline:     json['deadline'] != null
            ? DateTime.parse(json['deadline'] as String).toLocal()
            : null,
        createdAt:    DateTime.parse(json['created_at'] as String),
      );
}

class RpsTournament {
  final String id;
  final String createdBy;
  final RpsTournamentStatus status;
  final String? winnerId;
  final DateTime createdAt;
  final List<RpsMatch> matches;

  const RpsTournament({
    required this.id,
    required this.createdBy,
    required this.status,
    this.winnerId,
    required this.createdAt,
    required this.matches,
  });

  bool get isCompleted => status == RpsTournamentStatus.completed;
  int  get totalRounds => matches.isEmpty ? 0 : matches.map((m) => m.round).reduce((a, b) => a > b ? a : b);

  List<RpsMatch> matchesForRound(int round) =>
      matches.where((m) => m.round == round).toList()
        ..sort((a, b) => a.matchSlot.compareTo(b.matchSlot));

  /// Returns the active match for the given userId (not yet decided, not a bye).
  RpsMatch? activeMatchFor(String userId) {
    for (final m in matches) {
      if (m.isComplete || m.isBye) continue;
      if (m.playerAId == userId || m.playerBId == userId) return m;
    }
    return null;
  }

  factory RpsTournament.fromJson(Map<String, dynamic> json, List<RpsMatch> matches) =>
      RpsTournament(
        id:        json['id']         as String,
        createdBy: json['created_by'] as String,
        status: (json['status'] as String) == 'completed'
            ? RpsTournamentStatus.completed
            : RpsTournamentStatus.inProgress,
        winnerId:  json['winner_id']  as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        matches:   matches,
      );
}
