import 'dart:async';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moerderspiel/data/models/rps_tournament.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';
import 'package:moerderspiel/presentation/providers/rps_tournament_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/app_button.dart';

class RpsTournamentScreen extends ConsumerStatefulWidget {
  const RpsTournamentScreen({super.key});

  @override
  ConsumerState<RpsTournamentScreen> createState() => _RpsTournamentScreenState();
}

class _RpsTournamentScreenState extends ConsumerState<RpsTournamentScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        ref.read(rpsTournamentNotifierProvider.notifier).reload();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final tAsync = ref.watch(rpsTournamentNotifierProvider);
    final theme  = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'RPS-TURNIER',
          style: GoogleFonts.rajdhani(letterSpacing: 4, fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.read(rpsTournamentNotifierProvider.notifier).reload(),
        child: tAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText('Fehler: $e',
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          ),
          data: (tournament) {
            if (tournament == null) {
              return _NoTournamentView(userId: userId);
            }
            return _TournamentView(
              tournament: tournament,
              userId: userId,
              theme: theme,
            );
          },
        ),
      ),
    );
  }
}

// ── Noch kein Turnier ─────────────────────────────────────────

class _NoTournamentView extends ConsumerWidget {
  final String userId;
  const _NoTournamentView({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier  = ref.watch(rpsTournamentNotifierProvider.notifier);
    final isLoading = ref.watch(rpsTournamentNotifierProvider).isLoading;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Center(
          child: const Text('✊🖐✌️', style: TextStyle(fontSize: 64))
              .animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        ),
        const SizedBox(height: 24),
        Text(
          'Schnick-Schnack-Schnuck',
          textAlign: TextAlign.center,
          style: GoogleFonts.rajdhani(fontSize: 26, fontWeight: FontWeight.w900),
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: 8),
        Text(
          'Tägliches globales KO-Turnier · Sieger bekommt\neine zweite Kniffel-Chance',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.withValues(alpha: 0.8),
            height: 1.5,
          ),
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: 40),
        AppButton(
          label: 'Turnier starten',
          icon: Icons.sports_mma,
          isLoading: isLoading,
          onPressed: isLoading ? null : () => notifier.startTournament(),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
      ],
    );
  }
}

// ── Laufendes / abgeschlossenes Turnier ──────────────────────

class _TournamentView extends ConsumerWidget {
  final RpsTournament tournament;
  final String userId;
  final ThemeData theme;

  const _TournamentView({
    required this.tournament,
    required this.userId,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeMatch = tournament.activeMatchFor(userId);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusHeader(tournament: tournament, userId: userId)
            .animate().fadeIn(),

        if (tournament.isCompleted) ...[
          const SizedBox(height: 16),
          _WinnerBanner(tournament: tournament, userId: userId)
              .animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.95, 0.95)),
        ],

        if (!tournament.isCompleted && activeMatch != null) ...[
          const SizedBox(height: 16),
          _ActiveMatchCard(
            match: activeMatch,
            userId: userId,
          ).animate().fadeIn(delay: 100.ms),
        ],

        if (!tournament.isCompleted && activeMatch == null) ...[
          const SizedBox(height: 12),
          _WaitingCard(tournament: tournament, userId: userId)
              .animate().fadeIn(delay: 100.ms),
        ],

        const SizedBox(height: 24),
        Text(
          'Bracket',
          style: GoogleFonts.rajdhani(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),

        for (int r = 1; r <= tournament.totalRounds; r++) ...[
          _RoundSection(
            round: r,
            totalRounds: tournament.totalRounds,
            matches: tournament.matchesForRound(r),
            userId: userId,
          ).animate(delay: Duration(milliseconds: 80 * r)).fadeIn(),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ── Status-Header ─────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  final RpsTournament tournament;
  final String userId;
  const _StatusHeader({required this.tournament, required this.userId});

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final isCompleted = tournament.isCompleted;
    final statusColor = isCompleted ? Colors.green : Colors.amber.shade600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
          ),
          const SizedBox(width: 10),
          Text(
            isCompleted ? 'Abgeschlossen' : 'Runde ${tournament.totalRounds} läuft',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: statusColor),
          ),
          const Spacer(),
          Text(
            '${tournament.matches.where((m) => !m.isBye).length} Duelle',
            style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

// ── Gewinner-Banner ───────────────────────────────────────────

class _WinnerBanner extends ConsumerWidget {
  final RpsTournament tournament;
  final String userId;
  const _WinnerBanner({required this.tournament, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWinner  = tournament.winnerId == userId;
    final winnerId  = tournament.winnerId ?? '';
    final nameAsync = ref.watch(usernameByIdProvider(winnerId));
    final name      = nameAsync.value ?? '???';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isWinner
              ? [Colors.amber.shade700, Colors.amber.shade400]
              : [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(isWinner ? '🏆' : '🎉', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(
            isWinner ? 'Du hast gewonnen!' : '$name hat gewonnen!',
            style: GoogleFonts.rajdhani(
              fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          if (isWinner) ...[
            const SizedBox(height: 6),
            const Text(
              'Bonus-Kniffel freigeschaltet!',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Warte-Card ────────────────────────────────────────────────

class _WaitingCard extends StatelessWidget {
  final RpsTournament tournament;
  final String userId;
  const _WaitingCard({required this.tournament, required this.userId});

  @override
  Widget build(BuildContext context) {
    final stillIn = tournament.matches.any(
      (m) => m.playerAId == userId || m.playerBId == userId,
    );
    final alreadyLost = !stillIn ||
        tournament.matches.any(
          (m) => m.isComplete && m.winnerId != userId &&
              (m.playerAId == userId || m.playerBId == userId),
        );

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text(alreadyLost ? '😔' : '⏳', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alreadyLost ? 'Ausgeschieden' : 'Warte auf nächste Runde',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  alreadyLost
                      ? 'Du hast das Turnier leider verlassen.'
                      : 'Dein Duell beginnt sobald alle Matches der aktuellen Runde entschieden sind.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Aktives Match ─────────────────────────────────────────────

class _ActiveMatchCard extends ConsumerWidget {
  final RpsMatch match;
  final String userId;
  const _ActiveMatchCard({required this.match, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme      = Theme.of(context);
    final isA        = match.playerAId == userId;
    final myChoice   = isA ? match.choiceA : match.choiceB;
    final hasChosen  = myChoice != null;
    final opponentId = isA ? (match.playerBId ?? '') : match.playerAId;
    final opponentName = ref.watch(usernameByIdProvider(opponentId)).value ?? '???';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.6),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'DEIN DUELL',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary, letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'vs $opponentName',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ],
          ),
          if (match.deadline != null) ...[
            const SizedBox(height: 10),
            _DeadlineTimer(deadline: match.deadline!),
          ],
          const SizedBox(height: 16),

          if (match.isTie) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh, size: 14, color: Colors.amber.shade600),
                  const SizedBox(width: 6),
                  Text('Unentschieden — wähle erneut!',
                      style: TextStyle(fontSize: 13, color: Colors.amber.shade600,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ] else if (hasChosen) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_top, size: 14,
                      color: Colors.grey.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Text('Warte auf $opponentName...',
                      style: TextStyle(fontSize: 13,
                          color: Colors.grey.withValues(alpha: 0.6))),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Wähle jetzt:',
                  style: TextStyle(fontSize: 13,
                      color: Colors.grey.withValues(alpha: 0.7))),
            ),
          ],
          _ChoiceButtons(match: match, userId: userId, selectedChoice: myChoice),
        ],
      ),
    );
  }
}

class _ChoiceButtons extends ConsumerWidget {
  final RpsMatch match;
  final String userId;
  final RpsChoice? selectedChoice;
  const _ChoiceButtons({required this.match, required this.userId, this.selectedChoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubmitting = ref.watch(rpsTournamentNotifierProvider).isLoading;
    final hasChosen = selectedChoice != null;

    return Row(
      children: RpsChoice.values.map((choice) {
        final isSelected = selectedChoice == choice;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: choice != RpsChoice.scissors ? 8 : 0),
            child: _ChoiceButton(
              choice: choice,
              isSelected: isSelected,
              enabled: !isSubmitting && !hasChosen,
              onTap: () => ref
                  .read(rpsTournamentNotifierProvider.notifier)
                  .submitChoice(match.id, choice),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final RpsChoice choice;
  final bool enabled;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.choice,
    required this.enabled,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Ink(
      decoration: BoxDecoration(
        color: isSelected
            ? primary.withValues(alpha: 0.12)
            : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? primary
              : primary.withValues(alpha: enabled ? 0.25 : 0.1),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RpsIcon(
                  choice: choice,
                  size: 36,
                  color: isSelected
                      ? primary
                      : enabled
                          ? primary.withValues(alpha: 0.6)
                          : Colors.grey.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 6),
                Text(
                  choice.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? primary
                        : enabled
                            ? primary.withValues(alpha: 0.6)
                            : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  size: 12,
                  color: isSelected
                      ? primary
                      : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Deadline-Timer ────────────────────────────────────────────

class _DeadlineTimer extends StatefulWidget {
  final DateTime deadline;
  final bool compact;
  const _DeadlineTimer({required this.deadline, this.compact = false});

  @override
  State<_DeadlineTimer> createState() => _DeadlineTimerState();
}

class _DeadlineTimerState extends State<_DeadlineTimer> {
  late Timer _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _update();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(_update);
    });
  }

  void _update() {
    final r = widget.deadline.difference(DateTime.now());
    _remaining = r.isNegative ? Duration.zero : r;
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining == Duration.zero;
    final critical = _remaining.inMinutes < 15;
    final warning  = _remaining.inMinutes < 60;

    final color = expired
        ? Colors.grey
        : critical
            ? Colors.red.shade400
            : warning
                ? Colors.amber.shade600
                : Colors.grey.withValues(alpha: 0.7);

    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final clockLabel = expired
        ? '--:--:--'
        : '${h.toString().padLeft(2, '0')}:$m:$s';

    final icon = expired
        ? Icons.timer_off
        : critical
            ? Icons.timer
            : Icons.timer_outlined;

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            expired ? 'Zeit abgelaufen' : clockLabel,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: color.withValues(alpha: 0.7)),
              const SizedBox(width: 5),
              Text(
                expired ? 'ZEIT ABGELAUFEN' : 'VERBLEIBENDE ZEIT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            expired ? '--:--:--' : clockLabel,
            style: GoogleFonts.rajdhani(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 4,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bracket ───────────────────────────────────────────────────

class _RoundSection extends ConsumerWidget {
  final int round;
  final int totalRounds;
  final List<RpsMatch> matches;
  final String userId;

  const _RoundSection({
    required this.round,
    required this.totalRounds,
    required this.matches,
    required this.userId,
  });

  String _roundLabel() {
    if (totalRounds == round) return 'Finale';
    if (totalRounds == round + 1) return 'Halbfinale';
    return 'Runde $round';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            _roundLabel().toUpperCase(),
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              letterSpacing: 1.5, color: Colors.grey.withValues(alpha: 0.6),
            ),
          ),
        ),
        ...matches.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _MatchTile(match: m, userId: userId),
            )),
      ],
    );
  }
}

class _MatchTile extends ConsumerWidget {
  final RpsMatch match;
  final String userId;
  const _MatchTile({required this.match, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme  = Theme.of(context);
    final nameA  = ref.watch(usernameByIdProvider(match.playerAId)).value
        ?? match.playerAId.substring(0, 8);
    final nameB  = match.isBye
        ? 'Freilos'
        : (ref.watch(usernameByIdProvider(match.playerBId ?? '')).value
            ?? match.playerBId?.substring(0, 8) ?? '–');

    final isDone    = match.isComplete;
    final aWon      = isDone && match.winnerId == match.playerAId;
    final bWon      = isDone && match.winnerId == match.playerBId;
    final isMyMatch = match.playerAId == userId || match.playerBId == userId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyMatch
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _MatchPlayer(
                name: nameA, isWinner: aWon, isLoser: bWon,
                choice: isDone ? match.choiceA : null,
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('vs',
                    style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.5))),
              ),
              Expanded(child: _MatchPlayer(
                name: nameB, isWinner: bWon, isLoser: aWon,
                choice: isDone ? match.choiceB : null,
                isBye: match.isBye, alignRight: true,
              )),
            ],
          ),
          if (!isDone && match.deadline != null) ...[
            const SizedBox(height: 6),
            _DeadlineTimer(deadline: match.deadline!, compact: true),
          ],
        ],
      ),
    );
  }
}

class _MatchPlayer extends StatelessWidget {
  final String name;
  final bool isWinner;
  final bool isLoser;
  final RpsChoice? choice;
  final bool isBye;
  final bool alignRight;

  const _MatchPlayer({
    required this.name,
    required this.isWinner,
    required this.isLoser,
    this.choice,
    this.isBye = false,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWinner
        ? Colors.green
        : isLoser
            ? Colors.grey.withValues(alpha: 0.4)
            : null;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!alignRight && choice != null) ...[
          _RpsIcon(choice: choice!, size: 16, color: isLoser ? Colors.grey.withValues(alpha: 0.4) : Colors.grey),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
              color: isBye ? Colors.grey.withValues(alpha: 0.4) : color,
              decoration: isLoser ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        if (alignRight && choice != null) ...[
          const SizedBox(width: 4),
          _RpsIcon(choice: choice!, size: 16, color: isLoser ? Colors.grey.withValues(alpha: 0.4) : Colors.grey),
        ],
        if (isWinner) ...[
          const SizedBox(width: 4),
          const Icon(Icons.check_circle, size: 14, color: Colors.green),
        ],
      ],
    );

    return alignRight ? Align(alignment: Alignment.centerRight, child: row) : row;
  }
}

// ── RPS-Icons (FontAwesome) ───────────────────────────────────

class _RpsIcon extends StatelessWidget {
  final RpsChoice choice;
  final double size;
  final Color color;
  const _RpsIcon({required this.choice, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    final icon = switch (choice) {
      RpsChoice.rock     => FontAwesomeIcons.handFist,
      RpsChoice.paper    => FontAwesomeIcons.hand,
      RpsChoice.scissors => FontAwesomeIcons.handScissors,
    };
    return FaIcon(icon, size: size, color: color);
  }
}
