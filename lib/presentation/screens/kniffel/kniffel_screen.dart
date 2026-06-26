import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moerderspiel/core/models/loot_item.dart';
import 'package:moerderspiel/data/models/kniffel_game.dart';
import 'package:moerderspiel/presentation/providers/kniffel_provider.dart';
import 'package:moerderspiel/presentation/providers/lootbox_provider.dart';
import 'package:moerderspiel/presentation/widgets/kniffel/dice_widget.dart';
import 'package:moerderspiel/presentation/widgets/kniffel/kniffel_tile_scorecard.dart';
import 'package:moerderspiel/presentation/widgets/kniffel/scorecard_widget.dart';

class KniffelScreen extends ConsumerStatefulWidget {
  const KniffelScreen({super.key});

  @override
  ConsumerState<KniffelScreen> createState() => _KniffelScreenState();
}

class _KniffelScreenState extends ConsumerState<KniffelScreen> {
  List<int> _displayDice = [1, 2, 3, 4, 5];
  List<bool> _heldDice = List.filled(5, false);
  bool _isRolling = false;
  Timer? _rollTimer;
  final _random = math.Random();
  int _lastTurn = -1;

  @override
  void initState() {
    super.initState();
    // Sync dice immediately so the first build already has the correct values
    // (covers the "navigate away and back" case where provider is already loaded)
    final existing = ref.read(kniffelGameProvider).value;
    if (existing != null) _syncFromGame(existing);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final current = ref.read(kniffelGameProvider).value;
      if (current == null && !ref.read(kniffelGameProvider).isLoading) {
        ref.read(kniffelGameProvider.notifier).startOrResume();
      }
    });
  }

  @override
  void dispose() {
    _rollTimer?.cancel();
    super.dispose();
  }

  void _syncFromGame(KniffelGame game) {
    if (game.currentDice != null) {
      _displayDice = List<int>.from(game.currentDice!);
    }
    if (game.currentTurn != _lastTurn) {
      _heldDice = game.heldDice != null
          ? List<bool>.from(game.heldDice!)
          : List.filled(5, false);
      _lastTurn = game.currentTurn;
    }
  }

  Future<void> _roll() async {
    final game = ref.read(kniffelGameProvider).value;
    if (game == null || !game.canRoll || _isRolling) return;

    final heldSnapshot = List<bool>.from(_heldDice);
    final wasFirstRoll = game.rollCount == 0;

    setState(() => _isRolling = true);

    _rollTimer?.cancel();
    _rollTimer = Timer.periodic(const Duration(milliseconds: 65), (_) {
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < 5; i++) {
          if (wasFirstRoll || !heldSnapshot[i]) {
            _displayDice[i] = _random.nextInt(6) + 1;
          }
        }
      });
    });

    // Run animation and server call concurrently; wait for both
    await Future.wait([
      ref.read(kniffelGameProvider.notifier).roll(heldSnapshot),
      Future.delayed(const Duration(milliseconds: 520)),
    ]);

    _rollTimer?.cancel();
    if (!mounted) return;

    final updated = ref.read(kniffelGameProvider).value;
    setState(() {
      _isRolling = false;
      if (updated?.currentDice != null) {
        _displayDice = List<int>.from(updated!.currentDice!);
      }
      if (wasFirstRoll) _heldDice = List.filled(5, false);
      _lastTurn = updated?.currentTurn ?? _lastTurn;
    });
  }

  Future<void> _selectCategory(String category, int score) async {
    if (_isRolling) return;
    await ref
        .read(kniffelGameProvider.notifier)
        .selectCategory(category, score);
    if (!mounted) return;
    setState(() {
      _heldDice = List.filled(5, false);
      _displayDice = [1, 2, 3, 4, 5];
    });
  }

  void _toggleHold(int index) {
    final game = ref.read(kniffelGameProvider).value;
    if (game == null || game.rollCount == 0 || _isRolling || game.crownBonusAvailable) return;
    setState(() => _heldDice[index] = !_heldDice[index]);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<KniffelGame?>>(kniffelGameProvider, (_, next) {
      final game = next.value;
      if (game != null && !_isRolling) {
        setState(() => _syncFromGame(game));
      }
    });

    final gameAsync = ref.watch(kniffelGameProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'KNIFFEL',
          style:
              GoogleFonts.rajdhani(letterSpacing: 4, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () => context.push('/kniffel/leaderboard'),
            tooltip: 'Rangliste',
          ),
        ],
      ),
      body: gameAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(error: e.toString()),
        data: (game) {
          if (game == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (game.isCompleted) return _CompletedView(game: game);
          final diceDesign = ref.watch(lootStateProvider).maybeWhen(
            data: (s) => s.activeDiceDesign,
            orElse: () => DiceDesign.current,
          );
          return _GameView(
            game: game,
            displayDice: _displayDice,
            heldDice: _heldDice,
            isRolling: _isRolling,
            onRoll: _roll,
            onToggleHold: _toggleHold,
            onSelectCategory: _selectCategory,
            diceDesign: diceDesign,
          );
        },
      ),
    );
  }
}

// ── In-progress game view ──────────────────────────────────

class _GameView extends StatelessWidget {
  final KniffelGame game;
  final List<int> displayDice;
  final List<bool> heldDice;
  final DiceDesign diceDesign;
  final bool isRolling;
  final VoidCallback onRoll;
  final void Function(int) onToggleHold;
  final void Function(String, int) onSelectCategory;

  const _GameView({
    required this.game,
    required this.displayDice,
    required this.heldDice,
    required this.isRolling,
    required this.onRoll,
    required this.onToggleHold,
    required this.onSelectCategory,
    required this.diceDesign,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasRolled = game.rollCount > 0;

    return Column(
      children: [
        // ── Score strip ────────────────────────────────
        _ScoreStrip(game: game, isDark: isDark),

        // ── Tile scorecard (fills remaining space) ─────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: KniffelTileScorecard(
              scorecard: game.scorecard,
              currentDice: hasRolled ? displayDice : null,
              canSelect: game.canSelectCategory && !isRolling,
              onSelect: onSelectCategory,
            ),
          ),
        ),

        // ── Dice + roll button (pinned bottom) ─────────
        _DiceBar(
          game: game,
          displayDice: displayDice,
          heldDice: heldDice,
          isRolling: isRolling,
          onToggleHold: onToggleHold,
          onRoll: onRoll,
          isDark: isDark,
          diceDesign: diceDesign,
        ),
      ],
    );
  }
}

// ── Score strip (turn · total · bonus) ────────────────────

class _ScoreStrip extends StatelessWidget {
  final KniffelGame game;
  final bool isDark;
  const _ScoreStrip({required this.game, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bonusReached = game.hasBonus;
    final total = game.runningTotal;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.07),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Zug ${game.currentTurn + 1}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.65)
                  : Colors.black.withValues(alpha: 0.55),
            ),
          ),
          Text(
            ' / 13',
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.28)
                  : Colors.black.withValues(alpha: 0.28),
            ),
          ),
          const Spacer(),
          Text(
            '$total',
            style: GoogleFonts.rajdhani(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
              height: 1,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            'Pkt',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.35)
                  : Colors.black.withValues(alpha: 0.35),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: bonusReached
                  ? const Color(0xFFFFB300).withValues(alpha: 0.14)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              bonusReached ? '+35 Bonus ✓' : '${game.upperSum} / 63',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: bonusReached
                    ? const Color(0xFFFFB300)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.42)
                        : Colors.black.withValues(alpha: 0.4)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dice bar (pinned to bottom) ────────────────────────────

class _DiceBar extends StatelessWidget {
  final KniffelGame game;
  final List<int> displayDice;
  final List<bool> heldDice;
  final bool isRolling;
  final void Function(int) onToggleHold;
  final VoidCallback onRoll;
  final bool isDark;
  final DiceDesign diceDesign;

  const _DiceBar({
    required this.game,
    required this.displayDice,
    required this.heldDice,
    required this.isRolling,
    required this.onToggleHold,
    required this.onRoll,
    required this.isDark,
    required this.diceDesign,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRolled = game.rollCount > 0;
    final mustSelect = game.mustSelectCategory;
    final canRoll = game.canRoll && !isRolling;
    final crownBonus = game.crownBonusAvailable;
    final remaining = crownBonus ? 1 : math.max(0, 3 - game.rollCount);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomPad + 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dice row – always visible, dimmed before first roll
          AnimatedOpacity(
            opacity: hasRolled || isRolling ? 1.0 : 0.35,
            duration: const Duration(milliseconds: 250),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (i) {
                return DiceWidget(
                  value: displayDice[i],
                  isHeld: hasRolled && heldDice[i],
                  enabled: hasRolled && !mustSelect && !isRolling,
                  onTap: () => onToggleHold(i),
                  size: 62,
                  design: diceDesign,
                )
                    .animate(
                      key: ValueKey('die_$i'),
                      onPlay: isRolling && !heldDice[i]
                          ? (c) => c.repeat(reverse: true)
                          : null,
                    )
                    .then(delay: Duration(milliseconds: i * 25))
                    .scaleXY(
                      begin: isRolling && !heldDice[i] ? 0.93 : 1.0,
                      end: 1.0,
                      duration: 120.ms,
                    );
              }),
            ),
          ),

          // Hold hint – only when dice can be held
          AnimatedOpacity(
            opacity: hasRolled && !mustSelect && !isRolling && !crownBonus ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Würfel antippen zum Halten',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.28)
                      : Colors.black.withValues(alpha: 0.28),
                ),
              ),
            ),
          ),

          // Crown bonus banner
          if (crownBonus)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.40),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withValues(alpha: 0.14),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('✦', style: TextStyle(color: Color(0xFF9BE4FF), fontSize: 17)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Kronenmesser-Superkraft!',
                            style: GoogleFonts.rajdhani(
                              color: const Color(0xFF9BE4FF),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Dein Vierling ist gesichert — würfle den letzten Würfel nochmal!',
                            style: TextStyle(
                              color: const Color(0xFF9BE4FF).withValues(alpha: 0.72),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .slideY(begin: 0.3, end: 0, duration: 350.ms, curve: Curves.easeOut),
            ),

          const SizedBox(height: 10),

          // Roll / hint button
          Container(
            decoration: crownBonus
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00D4FF).withValues(alpha: 0.40),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  )
                : null,
            child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canRoll && !mustSelect ? onRoll : null,
              icon: isRolling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      mustSelect
                          ? Icons.touch_app_rounded
                          : crownBonus
                              ? Icons.auto_awesome_rounded
                              : Icons.casino_rounded,
                      size: 20,
                    ),
              label: Text(
                isRolling
                    ? 'Würfeln...'
                    : mustSelect
                        ? 'Kategorie antippen!'
                        : crownBonus
                            ? 'KRONENMESSER · BONUS-WURF'
                            : game.rollCount == 0
                                ? 'WÜRFELN'
                                : 'NOCHMAL  ·  $remaining ${remaining == 1 ? 'Wurf' : 'Würfe'} übrig',
                style: GoogleFonts.rajdhani(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: mustSelect
                    ? Colors.amber.shade700
                    : crownBonus
                        ? const Color(0xFF003D5C)
                        : theme.colorScheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.07),
                disabledForegroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.25),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
          ), // Container glow wrapper
        ],
      ),
    );
  }
}

// ── Completed game view ────────────────────────────────────

class _CompletedView extends ConsumerWidget {
  final KniffelGame game;
  const _CompletedView({required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankAsync = ref.watch(todayKniffelRankProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final score = game.finalScore ?? game.runningTotal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Result card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1A1A00), const Color(0xFF2C2000)]
                    : [const Color(0xFFFFFDE7), const Color(0xFFFFF8E1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFFB300).withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB300).withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text('🎲', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(
                  'Heutige Partie abgeschlossen',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.black.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$score',
                  style: GoogleFonts.rajdhani(
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFFFB300),
                    height: 1,
                  ),
                ),
                Text(
                  'Punkte',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 16),
                rankAsync.when(
                  data: (rank) => rank == null
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: rank == 1
                                ? const Color(0xFFFFB300).withValues(alpha: 0.18)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            rank == 1
                                ? '👑 Würfelgottheit des Tages!'
                                : 'Platz $rank heute',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: rank == 1
                                  ? const Color(0xFFFFB300)
                                  : (isDark ? Colors.white70 : Colors.black54),
                            ),
                          ),
                        ),
                  loading: () =>
                      const SizedBox(height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),

          const SizedBox(height: 16),

          // Leaderboard button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/kniffel/leaderboard'),
              icon: const Icon(Icons.leaderboard_outlined),
              label: Text(
                'RANGLISTE ANZEIGEN',
                style: GoogleFonts.rajdhani(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 24),
          Text(
            'Deine heutige Scorecard',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 10),
          ScorecardWidget(
            scorecard: game.scorecard,
            canSelect: false,
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Fehler beim Laden', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
