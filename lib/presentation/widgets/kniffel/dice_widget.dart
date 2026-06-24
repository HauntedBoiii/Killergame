import 'package:flutter/material.dart';

/// A single Kniffel die showing a value from 1–6.
/// Animates between values using AnimatedSwitcher (pop effect during rolling).
class DiceWidget extends StatelessWidget {
  final int value;
  final bool isHeld;
  final bool enabled;
  final VoidCallback? onTap;
  final double size;

  const DiceWidget({
    super.key,
    required this.value,
    this.isHeld = false,
    this.enabled = true,
    this.onTap,
    this.size = 62,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isHeld
        ? (isDark ? const Color(0xFF2E2100) : const Color(0xFFFFF8E1))
        : (isDark ? const Color(0xFF242424) : Colors.white);
    final borderColor = isHeld
        ? const Color(0xFFFFB300)
        : (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.14));
    final pipColor = isHeld
        ? const Color(0xFFFFB300)
        : (isDark ? Colors.white : const Color(0xFF1A1A1A));

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: isHeld ? 2.5 : 1.5,
          ),
          boxShadow: isHeld
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.45),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 70),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          ),
          child: Padding(
            key: ValueKey('$value${isHeld ? 'h' : ''}'),
            padding: EdgeInsets.all(size * 0.14),
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _PipPainter(value: value, color: pipColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PipPainter extends CustomPainter {
  final int value;
  final Color color;

  const _PipPainter({required this.value, required this.color});

  // Pip positions as fractions of drawable area [0,1]×[0,1]
  static const Map<int, List<Offset>> _pips = {
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.25, 0.25), Offset(0.75, 0.75)],
    3: [Offset(0.75, 0.25), Offset(0.5, 0.5), Offset(0.25, 0.75)],
    4: [
      Offset(0.25, 0.25),
      Offset(0.75, 0.25),
      Offset(0.25, 0.75),
      Offset(0.75, 0.75)
    ],
    5: [
      Offset(0.25, 0.25),
      Offset(0.75, 0.25),
      Offset(0.5, 0.5),
      Offset(0.25, 0.75),
      Offset(0.75, 0.75)
    ],
    6: [
      Offset(0.25, 0.18),
      Offset(0.75, 0.18),
      Offset(0.25, 0.5),
      Offset(0.75, 0.5),
      Offset(0.25, 0.82),
      Offset(0.75, 0.82)
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final r = size.width * 0.13;
    for (final pip in _pips[value] ?? const <Offset>[]) {
      canvas.drawCircle(
          Offset(pip.dx * size.width, pip.dy * size.height), r, paint);
    }
  }

  @override
  bool shouldRepaint(_PipPainter old) =>
      old.value != value || old.color != color;
}
