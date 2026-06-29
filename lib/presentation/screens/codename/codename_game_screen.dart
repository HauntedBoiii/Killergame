import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/data/models/codename_session.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';
import 'package:moerderspiel/presentation/providers/codename_provider.dart';
import 'package:moerderspiel/presentation/providers/rps_tournament_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/app_button.dart';

class CodenameGameScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const CodenameGameScreen({super.key, required this.sessionId});

  @override
  ConsumerState<CodenameGameScreen> createState() => _CodenameGameScreenState();
}

class _CodenameGameScreenState extends ConsumerState<CodenameGameScreen> {
  final _clueCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _clueCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────

  List<CodenamePlayer> _activePlayers(List<CodenamePlayer> players) =>
      players.where((p) => !p.isEliminated).toList()
        ..sort((a, b) => (a.turnOrder ?? 0).compareTo(b.turnOrder ?? 0));

  CodenamePlayer? _currentTurnPlayer(
      CodenameSession session, List<CodenamePlayer> players, List<CodenameClue> clues) {
    final active = _activePlayers(players);
    final cluesThisRound = clues.where((c) => c.round == session.currentRound).length;
    if (cluesThisRound >= active.length) return null;
    return active[cluesThisRound];
  }

  // ── Actions ────────────────────────────────────────────────

  Future<void> _submitClue() async {
    final session = ref.read(codenameSessionStreamProvider(widget.sessionId)).value;
    final isHybrid = session?.mode == CodenameMode.hybrid;
    final clue = isHybrid ? '🎙️' : _clueCtrl.text.trim();
    if (clue.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(codenameRepositoryProvider).submitClue(widget.sessionId, clue);
      _clueCtrl.clear();
    } catch (e) {
      if (mounted) showSnack(context, 'Fehler: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitVote(String votedForId) async {
    try {
      await ref.read(codenameRepositoryProvider).submitVote(widget.sessionId, votedForId);
    } catch (e) {
      if (mounted) showSnack(context, 'Fehler: $e', isError: true);
    }
  }

  Future<void> _showGuessDialog() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Codewort raten'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Deine Vermutung',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Raten')),
        ],
      ),
    );
    if (confirmed != true || ctrl.text.trim().isEmpty) return;
    try {
      final correct = await ref
          .read(codenameRepositoryProvider)
          .impostorGuess(widget.sessionId, ctrl.text.trim());
      if (mounted) {
        showSnack(context, correct ? '✅ Richtig! Du hast gewonnen!' : '❌ Falsch!');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Fehler: $e', isError: true);
    }
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(codenameSessionStreamProvider(widget.sessionId));
    final playersAsync = ref.watch(codenamePlayersStreamProvider(widget.sessionId));
    final cluesAsync   = ref.watch(codenameCluesStreamProvider(widget.sessionId));
    final votesAsync   = ref.watch(codenameVotesStreamProvider(widget.sessionId));
    final userId       = ref.watch(currentUserIdProvider);
    final theme        = Theme.of(context);

    final session = sessionAsync.value;
    final players = playersAsync.value ?? [];
    final clues   = cluesAsync.value ?? [];
    final votes   = votesAsync.value ?? [];

    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final myPlayer = players.firstWhereOrNull((p) => p.playerId == userId);
    final isImpostor = myPlayer?.isImpostor ?? false;
    final turnPlayer = _currentTurnPlayer(session, players, clues);
    final isMyTurn   = turnPlayer?.playerId == userId;

    return Scaffold(
      appBar: AppBar(
        title: Text('Runde ${session.currentRound}'),
        actions: [
          if (isImpostor && session.isActive)
            TextButton.icon(
              onPressed: _showGuessDialog,
              icon: const Icon(Icons.help_outline, size: 18),
              label: const Text('Raten', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
      body: session.isCompleted
          ? _GameOverView(session: session, players: players, userId: userId)
          : session.isVotePhase
              ? _VotePhaseView(
                  session:    session,
                  players:    players,
                  clues:      clues,
                  votes:      votes,
                  userId:     userId,
                  onVote:     _submitVote,
                  theme:      theme,
                )
              : _CluePhaseView(
                  session:     session,
                  players:     players,
                  clues:       clues,
                  isImpostor:  isImpostor,
                  isMyTurn:    isMyTurn,
                  turnPlayer:  turnPlayer,
                  clueCtrl:    _clueCtrl,
                  submitting:  _submitting,
                  onSubmit:    _submitClue,
                  theme:       theme,
                ),
    );
  }
}

// ── Clue Phase ─────────────────────────────────────────────

class _CluePhaseView extends ConsumerWidget {
  final CodenameSession session;
  final List<CodenamePlayer> players;
  final List<CodenameClue> clues;
  final bool isImpostor;
  final bool isMyTurn;
  final CodenamePlayer? turnPlayer;
  final TextEditingController clueCtrl;
  final bool submitting;
  final VoidCallback onSubmit;
  final ThemeData theme;

  const _CluePhaseView({
    required this.session,
    required this.players,
    required this.clues,
    required this.isImpostor,
    required this.isMyTurn,
    required this.turnPlayer,
    required this.clueCtrl,
    required this.submitting,
    required this.onSubmit,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cluesThisRound = clues.where((c) => c.round == session.currentRound).toList();
    final prevClues = clues.where((c) => c.round < session.currentRound).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Codewort-Banner ─────────────────────────────
        _CodenameBanner(
          codename: isImpostor ? null : session.codename,
          isImpostor: isImpostor,
          theme: theme,
        ).animate().fadeIn(),

        const SizedBox(height: 16),

        // ── Dran-Indicator ──────────────────────────────
        _TurnIndicator(
          turnPlayer: turnPlayer,
          isMyTurn: isMyTurn,
          theme: theme,
        ).animate().fadeIn(delay: 50.ms),

        const SizedBox(height: 16),

        // ── Hinweise diese Runde ─────────────────────────
        if (cluesThisRound.isNotEmpty) ...[
          _SectionLabel(label: 'Runde ${session.currentRound}'),
          ...cluesThisRound.map((c) => _ClueTile(clue: c, players: players)
              .animate().fadeIn().slideY(begin: 0.05)),
          const SizedBox(height: 16),
        ],

        // ── Vorherige Runden ─────────────────────────────
        if (prevClues.isNotEmpty) ...[
          for (var r = session.currentRound - 1; r >= 1; r--) ...[
            _SectionLabel(label: 'Runde $r', muted: true),
            ...prevClues
                .where((c) => c.round == r)
                .map((c) => _ClueTile(clue: c, players: players, muted: true)),
            const SizedBox(height: 8),
          ],
        ],

        // ── Eingabe ──────────────────────────────────────
        if (isMyTurn) ...[
          const SizedBox(height: 8),
          if (session.mode == CodenameMode.online) ...[
            TextField(
              controller: clueCtrl,
              autofocus: true,
              onSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: 'Dein Hinweis',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: onSubmit,
                ),
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 12),
            AppButton(
              label: 'Hinweis abschicken',
              onPressed: onSubmit,
              isLoading: submitting,
              icon: Icons.send,
            ),
          ] else ...[
            AppButton(
              label: 'Hinweis gesagt ✓',
              onPressed: onSubmit,
              isLoading: submitting,
              icon: Icons.record_voice_over_outlined,
            ).animate().fadeIn(delay: 100.ms),
          ],
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Warte auf den nächsten Hinweis …',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Vote Phase ─────────────────────────────────────────────

class _VotePhaseView extends ConsumerWidget {
  final CodenameSession session;
  final List<CodenamePlayer> players;
  final List<CodenameClue> clues;
  final List<CodenameVote> votes;
  final String? userId;
  final Future<void> Function(String) onVote;
  final ThemeData theme;

  const _VotePhaseView({
    required this.session,
    required this.players,
    required this.clues,
    required this.votes,
    required this.userId,
    required this.onVote,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final round = session.currentRound;
    final cluesThisRound = clues.where((c) => c.round == round).toList();
    final myVote = votes.firstWhereOrNull(
        (v) => v.voterId == userId && v.round == round);
    final activePlayers =
        players.where((p) => !p.isEliminated && p.playerId != userId).toList()
          ..sort((a, b) => (a.turnOrder ?? 0).compareTo(b.turnOrder ?? 0));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.how_to_vote_outlined, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Abstimmung · Runde $round',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Text('Wer ist der Doppelagent?',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Text(
                '${votes.where((v) => v.round == round).length} / ${players.where((p) => !p.isEliminated).length}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.amber),
              ),
            ],
          ),
        ).animate().fadeIn(),

        const SizedBox(height: 16),

        // Hinweise dieser Runde
        _SectionLabel(label: 'Hinweise Runde $round'),
        ...cluesThisRound.map((c) => _ClueTile(clue: c, players: players)),

        const SizedBox(height: 16),
        const _SectionLabel(label: 'Verdächtige'),
        const SizedBox(height: 4),

        if (myVote != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text('Stimme abgegeben. Warte auf andere …',
                    style: TextStyle(fontSize: 12, color: Colors.green)),
              ],
            ),
          ),

        // Spieler-Liste zum Wählen
        ...activePlayers.map((p) => _VoteTile(
              player:  p,
              hasVote: myVote?.votedForId == p.playerId,
              onTap:   myVote == null ? () => onVote(p.playerId) : null,
            ).animate().fadeIn().slideX(begin: -0.06)),
      ],
    );
  }
}

// ── Game Over ──────────────────────────────────────────────

class _GameOverView extends ConsumerWidget {
  final CodenameSession session;
  final List<CodenamePlayer> players;
  final String? userId;

  const _GameOverView({
    required this.session,
    required this.players,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersWon  = session.winner == CodenameWinner.players;
    final impostor    = players.firstWhereOrNull((p) => p.isImpostor);
    final accent      = playersWon ? Colors.green : Colors.red;
    final theme       = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              playersWon ? '🕵️ Doppelagent entlarvt!' : '🦹 Doppelagent entkommen!',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ).animate().fadeIn().scale(begin: const Offset(0.85, 0.85)),
            const SizedBox(height: 8),
            Text(
              playersWon ? 'Die Spieler haben gewonnen!' : 'Der Doppelagent hat gewonnen!',
              style: TextStyle(fontSize: 16, color: accent, fontWeight: FontWeight.w600),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 32),

            // Codewort
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.5), width: 2),
              ),
              child: Column(
                children: [
                  const Text('Das Codewort war',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Text(
                    session.codename ?? '?',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: accent,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).scale(
                begin: const Offset(0.9, 0.9), delay: 200.ms),

            const SizedBox(height: 24),

            // Impostor-Reveal
            if (impostor != null)
              _ImpostorReveal(impostor: impostor, isMe: impostor.playerId == userId)
                  .animate().fadeIn(delay: 400.ms),

            const SizedBox(height: 32),
            AppButton(
              label: 'Zurück zur Startseite',
              onPressed: () => context.go('/home'),
              outlined: true,
              icon: Icons.home_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImpostorReveal extends ConsumerWidget {
  final CodenamePlayer impostor;
  final bool isMe;
  const _ImpostorReveal({required this.impostor, required this.isMe});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usernameAsync = ref.watch(usernameByIdProvider(impostor.playerId));
    final name = usernameAsync.value ?? impostor.playerId.substring(0, 8);
    return Column(
      children: [
        const Text('Der Doppelagent war:', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          isMe ? '$name (Du!)' : name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isMe ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────

class _CodenameBanner extends StatelessWidget {
  final String? codename;
  final bool isImpostor;
  final ThemeData theme;
  const _CodenameBanner({this.codename, required this.isImpostor, required this.theme});

  @override
  Widget build(BuildContext context) {
    final color = isImpostor ? Colors.red : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isImpostor ? Icons.visibility_off_outlined : Icons.key_outlined,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isImpostor ? 'Du bist der Doppelagent' : 'Das Codewort',
                  style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 2),
                Text(
                  isImpostor ? 'Niemand weiß, dass du das Wort nicht kennst.' : (codename ?? '…'),
                  style: TextStyle(
                    fontSize: isImpostor ? 12 : 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: isImpostor ? 0 : 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnIndicator extends ConsumerWidget {
  final CodenamePlayer? turnPlayer;
  final bool isMyTurn;
  final ThemeData theme;
  const _TurnIndicator({this.turnPlayer, required this.isMyTurn, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (turnPlayer == null) return const SizedBox.shrink();
    final usernameAsync = ref.watch(usernameByIdProvider(turnPlayer!.playerId));
    final name = usernameAsync.value ?? turnPlayer!.playerId.substring(0, 8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMyTurn
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(10),
        border: isMyTurn
            ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.arrow_right_rounded,
            color: isMyTurn ? theme.colorScheme.primary : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            isMyTurn ? 'Du bist dran!' : '$name ist dran …',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isMyTurn ? FontWeight.w700 : FontWeight.w500,
              color: isMyTurn ? theme.colorScheme.primary : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final bool muted;
  const _SectionLabel({required this.label, this.muted = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: muted ? Colors.grey.withValues(alpha: 0.5) : Colors.grey,
          ),
        ),
      );
}

class _ClueTile extends ConsumerWidget {
  final CodenameClue clue;
  final List<CodenamePlayer> players;
  final bool muted;
  const _ClueTile({required this.clue, required this.players, this.muted = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usernameAsync = ref.watch(usernameByIdProvider(clue.playerId));
    final name = usernameAsync.value ?? clue.playerId.substring(0, 8);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: muted
            ? theme.cardTheme.color?.withValues(alpha: 0.5)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              clue.clueText,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: muted ? Colors.grey : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _VoteTile extends ConsumerWidget {
  final CodenamePlayer player;
  final bool hasVote;
  final VoidCallback? onTap;
  const _VoteTile({required this.player, required this.hasVote, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usernameAsync = ref.watch(usernameByIdProvider(player.playerId));
    final name = usernameAsync.value ?? player.playerId.substring(0, 8);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Ink(
        decoration: BoxDecoration(
          color: hasVote
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: hasVote
              ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5))
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  if (hasVote)
                    Icon(Icons.how_to_vote, color: theme.colorScheme.primary, size: 20)
                  else if (onTap != null)
                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Utility ────────────────────────────────────────────────

extension _ListX<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
