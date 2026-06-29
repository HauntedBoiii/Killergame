enum CodenameStatus { lobby, active, completed }

enum CodenamePhase { clue, vote }

enum CodenameWinner { players, impostor }

enum CodenameMode { online, hybrid }

class CodenameSession {
  final String id;
  final String code;
  final String name;
  final String hostId;
  final String? codename;
  final String wordCategory;
  final CodenameMode mode;
  final CodenameStatus status;
  final CodenamePhase phase;
  final int currentRound;
  final CodenameWinner? winner;
  final DateTime createdAt;

  const CodenameSession({
    required this.id,
    required this.code,
    required this.name,
    required this.hostId,
    this.codename,
    required this.wordCategory,
    required this.mode,
    required this.status,
    required this.phase,
    required this.currentRound,
    this.winner,
    required this.createdAt,
  });

  bool get isLobby     => status == CodenameStatus.lobby;
  bool get isActive    => status == CodenameStatus.active;
  bool get isCompleted => status == CodenameStatus.completed;
  bool get isCluePhase => phase == CodenamePhase.clue;
  bool get isVotePhase => phase == CodenamePhase.vote;

  factory CodenameSession.fromJson(Map<String, dynamic> j) => CodenameSession(
        id:           j['id']            as String,
        code:         j['code']          as String,
        name:         j['name']          as String,
        hostId:       j['host_id']       as String,
        codename:     j['codename']      as String?,
        wordCategory: j['word_category'] as String? ?? 'all',
        mode: (j['mode'] as String?) == 'hybrid'
            ? CodenameMode.hybrid
            : CodenameMode.online,
        status: switch (j['status'] as String) {
          'active'    => CodenameStatus.active,
          'completed' => CodenameStatus.completed,
          _           => CodenameStatus.lobby,
        },
        phase: (j['phase'] as String?) == 'vote'
            ? CodenamePhase.vote
            : CodenamePhase.clue,
        currentRound: (j['current_round'] as num?)?.toInt() ?? 1,
        winner: switch (j['winner'] as String?) {
          'players'  => CodenameWinner.players,
          'impostor' => CodenameWinner.impostor,
          _          => null,
        },
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class CodenamePlayer {
  final String id;
  final String sessionId;
  final String playerId;
  final bool isImpostor;
  final bool isEliminated;
  final int? turnOrder;
  final DateTime joinedAt;

  const CodenamePlayer({
    required this.id,
    required this.sessionId,
    required this.playerId,
    required this.isImpostor,
    required this.isEliminated,
    this.turnOrder,
    required this.joinedAt,
  });

  factory CodenamePlayer.fromJson(Map<String, dynamic> j) => CodenamePlayer(
        id:           j['id']           as String,
        sessionId:    j['session_id']   as String,
        playerId:     j['player_id']    as String,
        isImpostor:   j['is_impostor']  as bool? ?? false,
        isEliminated: j['is_eliminated'] as bool? ?? false,
        turnOrder:    (j['turn_order']  as num?)?.toInt(),
        joinedAt:     DateTime.parse(j['joined_at'] as String),
      );
}

class CodenameClue {
  final String id;
  final String sessionId;
  final String playerId;
  final int round;
  final String clueText;
  final DateTime submittedAt;

  const CodenameClue({
    required this.id,
    required this.sessionId,
    required this.playerId,
    required this.round,
    required this.clueText,
    required this.submittedAt,
  });

  factory CodenameClue.fromJson(Map<String, dynamic> j) => CodenameClue(
        id:          j['id']           as String,
        sessionId:   j['session_id']   as String,
        playerId:    j['player_id']    as String,
        round:       (j['round']       as num).toInt(),
        clueText:    j['clue_text']    as String,
        submittedAt: DateTime.parse(j['submitted_at'] as String),
      );
}

class CodenameVote {
  final String id;
  final String sessionId;
  final String voterId;
  final String votedForId;
  final int round;
  final DateTime createdAt;

  const CodenameVote({
    required this.id,
    required this.sessionId,
    required this.voterId,
    required this.votedForId,
    required this.round,
    required this.createdAt,
  });

  factory CodenameVote.fromJson(Map<String, dynamic> j) => CodenameVote(
        id:          j['id']            as String,
        sessionId:   j['session_id']    as String,
        voterId:     j['voter_id']      as String,
        votedForId:  j['voted_for_id']  as String,
        round:       (j['round']        as num).toInt(),
        createdAt:   DateTime.parse(j['created_at'] as String),
      );
}
