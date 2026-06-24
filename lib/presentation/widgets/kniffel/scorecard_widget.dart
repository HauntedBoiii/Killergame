import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moerderspiel/core/utils/kniffel_rules.dart';
import 'package:moerderspiel/data/models/kniffel_game.dart';

/// Displays the Kniffel scorecard with all 13 categories.
/// Filled rows show their locked score. Unfilled rows show a suggestion
/// (dimmed) when [canSelect] is true, and call [onSelect] on tap.
class ScorecardWidget extends StatelessWidget {
  final Map<String, KniffelScoreEntry> scorecard;
  final List<int>? currentDice;
  final bool canSelect;
  final void Function(String category, int score)? onSelect;

  const ScorecardWidget({
    super.key,
    required this.scorecard,
    this.currentDice,
    this.canSelect = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1C1C) : Colors.white;

    final upperSum =
        kKniffelUpperCategories.fold<int>(0, (s, cat) {
      return s + (scorecard[cat]?.score ?? 0);
    });
    final bonusReached = upperSum >= 63;
    final bonusProgress = (upperSum / 63).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Upper section ────────────────────────────
          _SectionHeader(label: 'OBEN', isDark: isDark),
          for (final cat in kKniffelUpperCategories)
            _CategoryRow(
              category: cat,
              entry: scorecard[cat],
              suggestion: (canSelect && currentDice != null && !scorecard.containsKey(cat))
                  ? computeCategoryScore(cat, currentDice!)
                  : null,
              canSelect: canSelect && !scorecard.containsKey(cat),
              onSelect: onSelect,
              isDark: isDark,
            ),

          // Bonus progress row
          _BonusRow(
            upperSum: upperSum,
            bonusProgress: bonusProgress,
            bonusReached: bonusReached,
            isDark: isDark,
          ),

          const Divider(height: 1, thickness: 1),

          // ── Lower section ────────────────────────────
          _SectionHeader(label: 'UNTEN', isDark: isDark),
          for (final cat in kKniffelLowerCategories)
            _CategoryRow(
              category: cat,
              entry: scorecard[cat],
              suggestion: (canSelect && currentDice != null && !scorecard.containsKey(cat))
                  ? computeCategoryScore(cat, currentDice!)
                  : null,
              canSelect: canSelect && !scorecard.containsKey(cat),
              onSelect: onSelect,
              isDark: isDark,
            ),

          const Divider(height: 1, thickness: 1),

          // ── Total ────────────────────────────────────
          _TotalRow(
            scorecard: scorecard,
            upperSum: upperSum,
            bonus: bonusReached ? 35 : 0,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label,
        style: GoogleFonts.rajdhani(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 3,
          color: isDark
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String category;
  final KniffelScoreEntry? entry;
  final int? suggestion;
  final bool canSelect;
  final void Function(String, int)? onSelect;
  final bool isDark;

  const _CategoryRow({
    required this.category,
    required this.entry,
    required this.suggestion,
    required this.canSelect,
    required this.onSelect,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = entry != null;
    final primary = Theme.of(context).colorScheme.primary;

    Color scoreColor;
    String scoreText;
    if (isFilled) {
      scoreColor = isDark ? Colors.white : Colors.black87;
      scoreText = '${entry!.score}';
    } else if (suggestion != null && canSelect) {
      scoreColor = suggestion! > 0
          ? primary.withValues(alpha: 0.85)
          : (isDark
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.2));
      scoreText = suggestion! > 0 ? '${suggestion!}' : '—';
    } else {
      scoreColor = isDark
          ? Colors.white.withValues(alpha: 0.18)
          : Colors.black.withValues(alpha: 0.15);
      scoreText = '·';
    }

    final tapEnabled = canSelect && !isFilled;

    return InkWell(
      onTap: tapEnabled
          ? () => onSelect?.call(category, suggestion ?? 0)
          : null,
      splashColor: primary.withValues(alpha: 0.12),
      highlightColor: primary.withValues(alpha: 0.06),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: (tapEnabled && suggestion != null && suggestion! > 0)
              ? primary.withValues(alpha: 0.04)
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kCategoryNames[category] ?? category,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isFilled ? FontWeight.w600 : FontWeight.normal,
                      color: isFilled
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.65)
                              : Colors.black.withValues(alpha: 0.6)),
                    ),
                  ),
                  if (!isFilled)
                    Text(
                      kCategoryHints[category] ?? '',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.28),
                      ),
                    ),
                ],
              ),
            ),
            // Score badge
            Container(
              width: 46,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isFilled
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06))
                    : (tapEnabled && suggestion != null && suggestion! > 0
                        ? primary.withValues(alpha: 0.12)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: isFilled
                    ? Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.1),
                        width: 1,
                      )
                    : null,
              ),
              child: Text(
                scoreText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: scoreColor,
                ),
              ),
            ),
            if (tapEnabled) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: suggestion != null && suggestion! > 0
                    ? primary.withValues(alpha: 0.7)
                    : Colors.grey.withValues(alpha: 0.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BonusRow extends StatelessWidget {
  final int upperSum;
  final double bonusProgress;
  final bool bonusReached;
  final bool isDark;

  const _BonusRow({
    required this.upperSum,
    required this.bonusProgress,
    required this.bonusReached,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bonusColor =
        bonusReached ? const Color(0xFFFFB300) : Colors.grey;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'BONUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: bonusColor,
                ),
              ),
              const Spacer(),
              Text(
                bonusReached ? '+35 ✓' : '$upperSum / 63',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: bonusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: bonusProgress,
              minHeight: 5,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(bonusColor),
            ),
          ),
          if (!bonusReached)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Noch ${63 - upperSum} Punkte bis +35 Bonus',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final Map<String, KniffelScoreEntry> scorecard;
  final int upperSum;
  final int bonus;
  final bool isDark;

  const _TotalRow({
    required this.scorecard,
    required this.upperSum,
    required this.bonus,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    int lowerSum = 0;
    for (final cat in kKniffelLowerCategories) {
      lowerSum += scorecard[cat]?.score ?? 0;
    }
    final total = upperSum + bonus + lowerSum;
    final filled = scorecard.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Text(
            'GESAMT',
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.4),
            ),
          ),
          if (bonus > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '+35 Bonus',
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFFFFB300),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$total',
                style: GoogleFonts.rajdhani(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                '$filled / 13 Felder',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.black.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
