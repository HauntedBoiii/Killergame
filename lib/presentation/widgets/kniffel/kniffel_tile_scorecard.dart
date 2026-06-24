import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moerderspiel/core/utils/kniffel_rules.dart';
import 'package:moerderspiel/data/models/kniffel_game.dart';

// ── Display data ──────────────────────────────────────────────

const _icons = {
  'ones': '⚀', 'twos': '⚁', 'threes': '⚂',
  'fours': '⚃', 'fives': '⚄', 'sixes': '⚅',
  'three_of_a_kind': '3✕', 'four_of_a_kind': '4✕',
  'full_house': '3·2',
  'small_straight': '≡', 'large_straight': '≣',
  'yahtzee': '⭐', 'chance': '∑',
};

const _shortNames = {
  'ones': 'Einser', 'twos': 'Zweier', 'threes': 'Dreier',
  'fours': 'Vierer', 'fives': 'Fünfer', 'sixes': 'Sechser',
  'three_of_a_kind': '3er Pasch', 'four_of_a_kind': '4er Pasch',
  'full_house': 'Full House',
  'small_straight': 'Kl. Straße', 'large_straight': 'Gr. Straße',
  'yahtzee': 'Kniffel', 'chance': 'Chance',
};

// Multi-character icons that need a badge container for legibility
const _textIconCategories = {
  'three_of_a_kind', 'four_of_a_kind', 'full_house',
};

// ── Main widget ───────────────────────────────────────────────

class KniffelTileScorecard extends StatelessWidget {
  final Map<String, KniffelScoreEntry> scorecard;
  final List<int>? currentDice;
  final bool canSelect;
  final void Function(String category, int score)? onSelect;

  const KniffelTileScorecard({
    super.key,
    required this.scorecard,
    this.currentDice,
    this.canSelect = false,
    this.onSelect,
  });

  int? _suggestion(String cat) {
    if (!canSelect || scorecard.containsKey(cat) || currentDice == null) {
      return null;
    }
    return computeCategoryScore(cat, currentDice!);
  }

  bool _canSelectTile(String cat) => canSelect && !scorecard.containsKey(cat);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Upper section: 2 rows of 3
        Expanded(
          child: _TileRow(
            categories: const ['ones', 'twos', 'threes'],
            scorecard: scorecard,
            suggestion: _suggestion,
            canSelect: _canSelectTile,
            onSelect: onSelect,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _TileRow(
            categories: const ['fours', 'fives', 'sixes'],
            scorecard: scorecard,
            suggestion: _suggestion,
            canSelect: _canSelectTile,
            onSelect: onSelect,
          ),
        ),

        // Bonus separator
        _BonusSeparator(scorecard: scorecard),

        // Lower section: 2 regular rows + Kniffel hero
        Expanded(
          child: _TileRow(
            categories: const ['three_of_a_kind', 'four_of_a_kind', 'full_house'],
            scorecard: scorecard,
            suggestion: _suggestion,
            canSelect: _canSelectTile,
            onSelect: onSelect,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _TileRow(
            categories: const ['small_straight', 'large_straight', 'chance'],
            scorecard: scorecard,
            suggestion: _suggestion,
            canSelect: _canSelectTile,
            onSelect: onSelect,
          ),
        ),
        const SizedBox(height: 6),

        // Kniffel hero tile spans full width
        Expanded(
          child: _YahtzeeHeroTile(
            entry: scorecard['yahtzee'],
            suggestion: _suggestion('yahtzee'),
            canSelect: _canSelectTile('yahtzee'),
            onTap: (score) => onSelect?.call('yahtzee', score),
          ),
        ),
      ],
    );
  }
}

// ── Tile row ──────────────────────────────────────────────────

class _TileRow extends StatelessWidget {
  final List<String> categories;
  final Map<String, KniffelScoreEntry> scorecard;
  final int? Function(String) suggestion;
  final bool Function(String) canSelect;
  final void Function(String, int)? onSelect;

  const _TileRow({
    required this.categories,
    required this.scorecard,
    required this.suggestion,
    required this.canSelect,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < categories.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _CategoryTile(
              category: categories[i],
              entry: scorecard[categories[i]],
              suggestion: suggestion(categories[i]),
              canSelect: canSelect(categories[i]),
              onTap: (score) => onSelect?.call(categories[i], score),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Category tile ─────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final String category;
  final KniffelScoreEntry? entry;
  final int? suggestion;
  final bool canSelect;
  final void Function(int score) onTap;

  const _CategoryTile({
    required this.category,
    required this.entry,
    required this.suggestion,
    required this.canSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = entry != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    const amber = Color(0xFFFFB300);

    final hasScore = canSelect && suggestion != null && suggestion! > 0;
    final hasZero = canSelect && suggestion != null && suggestion! == 0;
    final filledPositive = isFilled && entry!.score > 0;

    final Color bg;
    final Color border;
    final double bWidth;
    List<BoxShadow>? shadows;

    if (isFilled) {
      bg = filledPositive
          ? (isDark ? primary.withValues(alpha: 0.13) : primary.withValues(alpha: 0.07))
          : (isDark ? const Color(0xFF181818) : const Color(0xFFF0F0F0));
      border = filledPositive
          ? primary.withValues(alpha: 0.25)
          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.06));
      bWidth = 1.0;
    } else if (hasScore) {
      bg = isDark ? amber.withValues(alpha: 0.10) : amber.withValues(alpha: 0.06);
      border = amber.withValues(alpha: 0.55);
      bWidth = 1.5;
      shadows = [BoxShadow(color: amber.withValues(alpha: 0.18), blurRadius: 8)];
    } else if (hasZero) {
      bg = isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5);
      border = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.09);
      bWidth = 1.0;
    } else {
      bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F7);
      border = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.07);
      bWidth = 1.0;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: canSelect && !isFilled ? () => onTap(suggestion ?? 0) : null,
        borderRadius: BorderRadius.circular(12),
        splashColor: (hasScore ? amber : primary).withValues(alpha: 0.14),
        highlightColor: (hasScore ? amber : primary).withValues(alpha: 0.07),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: bWidth),
            boxShadow: shadows,
          ),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Icon(
                    category: category,
                    isFilled: isFilled,
                    isDark: isDark,
                    primary: primary,
                  ),
                  _Badge(
                    entry: entry,
                    suggestion: canSelect ? suggestion : null,
                    primary: primary,
                    isDark: isDark,
                  ),
                ],
              ),
              Text(
                _shortNames[category] ?? category,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: filledPositive ? FontWeight.w600 : FontWeight.w400,
                  color: isFilled
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.black.withValues(alpha: 0.75))
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.38)
                          : Colors.black.withValues(alpha: 0.38)),
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category icon ─────────────────────────────────────────────

class _Icon extends StatelessWidget {
  final String category;
  final bool isFilled;
  final bool isDark;
  final Color primary;

  const _Icon({
    required this.category,
    required this.isFilled,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _icons[category] ?? '?';
    final needsBadge = _textIconCategories.contains(category);

    return SizedBox(
      width: 28,
      height: 28,
      child: Center(
        child: needsBadge
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isFilled
                      ? primary.withValues(alpha: 0.14)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.07)),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isFilled
                        ? primary
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.black.withValues(alpha: 0.55)),
                  ),
                ),
              )
            : Text(
                icon,
                style: const TextStyle(fontSize: 20, height: 1.0),
              ),
      ),
    );
  }
}

// ── Score / suggestion badge ──────────────────────────────────

class _Badge extends StatelessWidget {
  final KniffelScoreEntry? entry;
  final int? suggestion;
  final Color primary;
  final bool isDark;

  const _Badge({
    required this.entry,
    required this.suggestion,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFFB300);

    if (entry != null) {
      final s = entry!.score;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: s > 0
              ? primary.withValues(alpha: 0.18)
              : Colors.grey.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(6),
          border: s > 0
              ? Border.all(color: primary.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Text(
          '$s',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: s > 0 ? primary : Colors.grey,
          ),
        ),
      );
    }

    if (suggestion == null) return const SizedBox.shrink();

    final isZero = suggestion! == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isZero
            ? Colors.grey.withValues(alpha: 0.10)
            : amber.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isZero
              ? Colors.grey.withValues(alpha: 0.25)
              : amber.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: Text(
        isZero ? '0' : '+${suggestion!}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: isZero ? Colors.grey : amber,
        ),
      ),
    );
  }
}

// ── Bonus separator ───────────────────────────────────────────

class _BonusSeparator extends StatelessWidget {
  final Map<String, KniffelScoreEntry> scorecard;
  const _BonusSeparator({required this.scorecard});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final upperSum = kKniffelUpperCategories.fold<int>(
        0, (s, cat) => s + (scorecard[cat]?.score ?? 0));
    final reached = upperSum >= 63;
    final progress = (upperSum / 63).clamp(0.0, 1.0);
    final color = reached
        ? const Color(0xFFFFB300)
        : (isDark
            ? Colors.white.withValues(alpha: 0.28)
            : Colors.black.withValues(alpha: 0.28));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            reached ? 'BONUS ✓' : 'BONUS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.07),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            reached ? '+35' : '$upperSum / 63',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kniffel hero tile (full-width) ────────────────────────────

class _YahtzeeHeroTile extends StatelessWidget {
  final KniffelScoreEntry? entry;
  final int? suggestion;
  final bool canSelect;
  final void Function(int score) onTap;

  const _YahtzeeHeroTile({
    required this.entry,
    required this.suggestion,
    required this.canSelect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = entry != null;
    final isHit = isFilled && entry!.score == 50;
    final canScore = canSelect && suggestion == 50;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    const amber = Color(0xFFFFB300);

    Color? bg;
    Gradient? gradient;
    final Color border;
    final double bWidth;
    List<BoxShadow>? shadows;

    if (isHit) {
      gradient = LinearGradient(
        colors: isDark
            ? [const Color(0xFF3A2A00), const Color(0xFF251B00)]
            : [const Color(0xFFFFFDE7), const Color(0xFFFFF0A0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      border = amber.withValues(alpha: 0.55);
      bWidth = 2.0;
      shadows = [BoxShadow(color: amber.withValues(alpha: 0.22), blurRadius: 16)];
    } else if (canScore) {
      bg = isDark ? amber.withValues(alpha: 0.11) : amber.withValues(alpha: 0.06);
      border = amber.withValues(alpha: 0.6);
      bWidth = 1.5;
      shadows = [BoxShadow(color: amber.withValues(alpha: 0.18), blurRadius: 10)];
    } else if (isFilled) {
      bg = isDark ? const Color(0xFF181818) : const Color(0xFFF0F0F0);
      border = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.06);
      bWidth = 1.0;
    } else {
      bg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F7);
      border = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.07);
      bWidth = 1.0;
    }

    final String subtitle;
    if (isHit) {
      subtitle = '50 Punkte erreicht!';
    } else if (canScore) {
      subtitle = 'Antippen zum Eintragen';
    } else if (isFilled) {
      subtitle = 'Gestrichen · 0 Punkte';
    } else if (canSelect) {
      subtitle = 'Kein Kniffel – antippen zum Streichen';
    } else {
      subtitle = 'Alle 5 Würfel gleich · 50 Punkte';
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: canSelect && !isFilled ? () => onTap(suggestion ?? 0) : null,
        borderRadius: BorderRadius.circular(12),
        splashColor: amber.withValues(alpha: 0.18),
        highlightColor: amber.withValues(alpha: 0.09),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: bg,
            gradient: gradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: bWidth),
            boxShadow: shadows,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Star pulses when a Kniffel is available or just hit
              Text(
                '⭐',
                style: TextStyle(fontSize: isHit ? 30 : 24, height: 1),
              )
                  .animate(
                    key: ValueKey('yahtzee_${canScore}_$isHit'),
                    onPlay: (canScore || isHit) ? (c) => c.repeat(reverse: true) : null,
                  )
                  .scaleXY(
                    begin: 1.0,
                    end: canScore || isHit ? 1.18 : 1.0,
                    duration: 700.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KNIFFEL',
                      style: GoogleFonts.rajdhani(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        height: 1.1,
                        color: isHit
                            ? amber
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.82)
                                : Colors.black.withValues(alpha: 0.78)),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: isHit
                            ? amber.withValues(alpha: 0.75)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.38)
                                : Colors.black.withValues(alpha: 0.38)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _Badge(
                entry: entry,
                suggestion: canSelect ? suggestion : null,
                primary: primary,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
