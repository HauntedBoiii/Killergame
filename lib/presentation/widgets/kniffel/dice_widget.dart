import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:moerderspiel/core/models/loot_item.dart';

// Pip-Positionen als Bruchteile der Zeichenfläche
const _kPips = <int, List<Offset>>{
  1: [Offset(0.5, 0.5)],
  2: [Offset(0.25, 0.25), Offset(0.75, 0.75)],
  3: [Offset(0.75, 0.25), Offset(0.5, 0.5), Offset(0.25, 0.75)],
  4: [Offset(0.25, 0.25), Offset(0.75, 0.25), Offset(0.25, 0.75), Offset(0.75, 0.75)],
  5: [Offset(0.25, 0.25), Offset(0.75, 0.25), Offset(0.5, 0.5), Offset(0.25, 0.75), Offset(0.75, 0.75)],
  6: [Offset(0.25, 0.18), Offset(0.75, 0.18), Offset(0.25, 0.5), Offset(0.75, 0.5), Offset(0.25, 0.82), Offset(0.75, 0.82)],
};

/// Einzelner Kniffel-Würfel.
/// [design] wählt das aktive Design (Standard: DiceDesign.current).
class DiceWidget extends StatelessWidget {
  final int value;
  final bool isHeld;
  final bool enabled;
  final VoidCallback? onTap;
  final double size;
  final DiceDesign design;

  const DiceWidget({
    super.key,
    required this.value,
    this.isHeld  = false,
    this.enabled = true,
    this.onTap,
    this.size   = 62,
    this.design = DiceDesign.current,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 70),
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
        child: KeyedSubtree(
          key: ValueKey('$design$value${isHeld ? 'h' : ''}'),
          child: _buildDesign(isDark),
        ),
      ),
    );
  }

  Widget _buildDesign(bool isDark) => switch (design) {
    DiceDesign.wood    => _DiceWood(value: value, isHeld: isHeld, size: size),
    DiceDesign.neon    => _DiceNeon(value: value, isHeld: isHeld, size: size),
    DiceDesign.vegas   => _DiceVegas(value: value, isHeld: isHeld, size: size),
    DiceDesign.blood   => _DiceBlood(value: value, isHeld: isHeld, size: size),
    DiceDesign.appRed  => _DiceAppRed(value: value, isHeld: isHeld, size: size),
    DiceDesign.digital => _DiceDigital(value: value, isHeld: isHeld, size: size),
    DiceDesign.crystal => _DiceCrystal(value: value, isHeld: isHeld, size: size),
    DiceDesign.crown   => _DiceCrown(value: value, isHeld: isHeld, size: size),
    DiceDesign.current => _DiceCurrent(value: value, isHeld: isHeld, size: size, isDark: isDark),
  };
}

// ═══════════════════════════════════════════════════════════
// DESIGN IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════

class _DiceCurrent extends StatelessWidget {
  const _DiceCurrent({required this.value, required this.isHeld, required this.size, required this.isDark});
  final int value; final bool isHeld, isDark; final double size;
  @override
  Widget build(BuildContext context) {
    final bg       = isHeld ? (isDark ? const Color(0xFF2E2100) : const Color(0xFFFFF8E1)) : (isDark ? const Color(0xFF242424) : Colors.white);
    final border   = isHeld ? const Color(0xFFFFB300) : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.14));
    final pipColor = isHeld ? const Color(0xFFFFB300) : (isDark ? Colors.white : const Color(0xFF1A1A1A));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size, height: size,
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: isHeld ? 2.5 : 1.5),
        boxShadow: isHeld
            ? [BoxShadow(color: const Color(0xFFFFB300).withValues(alpha: 0.45), blurRadius: 10, spreadRadius: 1)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      padding: EdgeInsets.all(size * 0.14),
      child: SizedBox.expand(child: CustomPaint(painter: _PipPainter(value, pipColor))),
    );
  }
}

class _DiceWood extends StatelessWidget {
  const _DiceWood({required this.value, required this.isHeld, required this.size});
  final int value; final bool isHeld; final double size;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size, height: size,
        decoration: BoxDecoration(
          color: isHeld ? const Color(0xFFBB7A40) : const Color(0xFF7A4E28),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isHeld ? const Color(0xFFFFD580) : const Color(0xFF3D1800), width: isHeld ? 2.5 : 2),
          boxShadow: isHeld
              ? [BoxShadow(color: const Color(0xFFFFD580).withOpacity(.4), blurRadius: 10)]
              : [BoxShadow(color: Colors.black.withOpacity(.45), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(fit: StackFit.expand, children: [
            CustomPaint(painter: const _WoodPainter()),
            Padding(padding: EdgeInsets.all(size * 0.14), child: CustomPaint(painter: _PipPainter(value, const Color(0xFF2C1000), pipScale: .14))),
          ]),
        ),
      );
}

class _DiceNeon extends StatelessWidget {
  const _DiceNeon({required this.value, required this.isHeld, required this.size});
  final int value; final bool isHeld; final double size;
  @override
  Widget build(BuildContext context) {
    final c = isHeld ? const Color(0xFFFFD700) : const Color(0xFFFF3B3B);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size, height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isHeld ? const Color(0xFFFFD700) : Colors.white.withOpacity(.06), width: isHeld ? 2 : 1),
        boxShadow: [BoxShadow(color: c.withOpacity(.45), blurRadius: isHeld ? 18 : 10)],
      ),
      padding: EdgeInsets.all(size * 0.14),
      child: CustomPaint(painter: _NeonPipPainter(value, c, c)),
    );
  }
}

class _DiceVegas extends StatelessWidget {
  const _DiceVegas({required this.value, required this.isHeld, required this.size});
  final int value; final bool isHeld; final double size;
  @override
  Widget build(BuildContext context) {
    final gold = isHeld ? const Color(0xFFFFE066) : const Color(0xFFFFB300);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size, height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gold, width: isHeld ? 2.5 : 1.5),
        boxShadow: [BoxShadow(color: gold.withOpacity(isHeld ? .55 : .25), blurRadius: isHeld ? 14 : 6)],
      ),
      padding: EdgeInsets.all(size * 0.14),
      child: CustomPaint(painter: _DiamondPipPainter(value, gold)),
    );
  }
}

class _DiceBlood extends StatelessWidget {
  const _DiceBlood({required this.value, required this.isHeld, required this.size});
  final int value; final bool isHeld; final double size;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size, height: size,
        decoration: BoxDecoration(
          color: isHeld ? const Color(0xFF1A0000) : const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isHeld ? const Color(0xFFFF4444) : const Color(0xFF660000), width: isHeld ? 2 : 1.5),
          boxShadow: [BoxShadow(color: const Color(0xFFCC0000).withOpacity(isHeld ? .45 : .2), blurRadius: isHeld ? 14 : 6)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(fit: StackFit.expand, children: [
            CustomPaint(painter: const _BloodPainter()),
            Padding(padding: EdgeInsets.all(size * 0.14), child: CustomPaint(painter: _PipPainter(value, Colors.white.withOpacity(.92)))),
          ]),
        ),
      );
}

class _DiceAppRed extends StatelessWidget {
  const _DiceAppRed({required this.value, required this.isHeld, required this.size});
  final int value; final bool isHeld; final double size;
  @override
  Widget build(BuildContext context) {
    final bg     = isHeld ? const Color(0xFF6D0000) : const Color(0xFF3A0000);
    final border = isHeld ? const Color(0xFFFFB300) : const Color(0xFFB71C1C);
    final pip    = isHeld ? const Color(0xFFFFB300) : Colors.white.withOpacity(.9);
    final glow   = isHeld ? const Color(0xFFFFB300) : const Color(0xFFB71C1C);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size, height: size,
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: isHeld ? 2.5 : 1.5),
        boxShadow: [BoxShadow(color: glow.withOpacity(.48), blurRadius: isHeld ? 14 : 5, spreadRadius: 1)],
      ),
      padding: EdgeInsets.all(size * 0.14),
      child: CustomPaint(painter: _PipPainter(value, pip)),
    );
  }
}

class _DiceDigital extends StatelessWidget {
  const _DiceDigital({required this.value, required this.isHeld, required this.size});
  final int value; final bool isHeld; final double size;
  @override
  Widget build(BuildContext context) {
    final accent = isHeld ? const Color(0xFFFFB300) : const Color(0xFF00E5FF);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size, height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(.6), width: isHeld ? 2 : 1),
        boxShadow: [BoxShadow(color: accent.withOpacity(.3), blurRadius: 12)],
      ),
      padding: EdgeInsets.all(size * 0.16),
      child: CustomPaint(painter: _SegmentPainter(value, accent)),
    );
  }
}

class _DiceCrystal extends StatelessWidget {
  const _DiceCrystal({required this.value, required this.isHeld, required this.size});
  final int value; final bool isHeld; final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size, height: size,
            decoration: BoxDecoration(
              color: isHeld ? const Color(0xFF3D2B00).withOpacity(.5) : Colors.white.withOpacity(.09),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isHeld ? const Color(0xFFFFD580) : Colors.white.withOpacity(.28), width: isHeld ? 2 : 1),
              boxShadow: isHeld ? [BoxShadow(color: const Color(0xFFFFB300).withOpacity(.4), blurRadius: 12)] : [],
            ),
            child: Stack(fit: StackFit.expand, children: [
              Padding(padding: EdgeInsets.all(size * 0.14), child: CustomPaint(painter: _PipPainter(value, isHeld ? const Color(0xFFFFD580) : Colors.white.withOpacity(.85)))),
              const CustomPaint(painter: _CrackPainter()),
            ]),
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
// PAINTERS
// ═══════════════════════════════════════════════════════════

class _PipPainter extends CustomPainter {
  final int value; final Color color; final double pipScale;
  const _PipPainter(this.value, this.color, {this.pipScale = .13});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final r = size.width * pipScale;
    for (final pip in _kPips[value] ?? const <Offset>[]) {
      canvas.drawCircle(Offset(pip.dx * size.width, pip.dy * size.height), r, p);
    }
  }
  @override
  bool shouldRepaint(_PipPainter old) => old.value != value || old.color != color;
}

class _NeonPipPainter extends CustomPainter {
  final int value; final Color color, glowColor;
  const _NeonPipPainter(this.value, this.color, this.glowColor);
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * .13;
    for (final pip in _kPips[value] ?? const <Offset>[]) {
      final o = Offset(pip.dx * size.width, pip.dy * size.height);
      canvas.drawCircle(o, r, Paint()..color = glowColor.withOpacity(.65)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 2.8));
      canvas.drawCircle(o, r * .62, Paint()..color = color);
    }
  }
  @override
  bool shouldRepaint(_NeonPipPainter old) => old.value != value;
}

class _DiamondPipPainter extends CustomPainter {
  final int value; final Color color;
  const _DiamondPipPainter(this.value, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * .145;
    for (final pip in _kPips[value] ?? const <Offset>[]) {
      final x = pip.dx * size.width, y = pip.dy * size.height;
      canvas.drawPath(Path()..moveTo(x, y - r)..lineTo(x + r * .7, y)..lineTo(x, y + r)..lineTo(x - r * .7, y)..close(), Paint()..color = color);
    }
  }
  @override
  bool shouldRepaint(_DiamondPipPainter old) => old.value != value;
}

class _WoodPainter extends CustomPainter {
  const _WoodPainter();
  static const _barkR = [1.0, .96, .98, .93, 1.0, .97, .95, .98, .94, 1.0, .97, .95, .98, .93, 1.0, .96, .97, .94, 1.0, .95, .98, .96, .93, 1.0];
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    for (int i = 0; i < 14; i++) {
      final y    = size.height * (i + .4) / 14;
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 3) {
        path.lineTo(x, y + 1.6 * math.sin(x * .35 + i * 1.1));
      }
      canvas.drawPath(path, Paint()..color = const Color(0xFF3D1800).withOpacity(.18)..strokeWidth = .5..style = PaintingStyle.stroke);
    }
    final steps  = _barkR.length;
    final baseR  = math.min(cx, cy);
    for (int ring = 0; ring < 4; ring++) {
      final frac = 0.72 + ring * 0.07;
      final path = Path();
      for (int i = 0; i <= steps; i++) {
        final angle = i * 2 * math.pi / steps;
        final rr    = baseR * frac * _barkR[i % steps];
        final x = cx + rr * math.cos(angle), y = cy + rr * math.sin(angle);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      final isOuter = ring == 3;
      canvas.drawPath(path, Paint()..color = const Color(0xFF1A0500).withOpacity(isOuter ? .85 : (.22 + ring * .10))..strokeWidth = isOuter ? 2.5 : .85..style = PaintingStyle.stroke);
    }
  }
  @override
  bool shouldRepaint(_WoodPainter _) => false;
}

class _BloodPainter extends CustomPainter {
  const _BloodPainter();
  static const _spots = [[.22,.15,.07],[.68,.10,.05],[.78,.38,.08],[.12,.52,.06],[.55,.72,.07],[.38,.88,.05],[.85,.68,.06],[.48,.28,.04],[.08,.78,.05],[.62,.48,.04]];
  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = const Color(0xFFCC0000);
    final dark = Paint()..color = const Color(0xFF880000);
    for (int i = 0; i < _spots.length; i++) {
      final x = _spots[i][0] * size.width, y = _spots[i][1] * size.height, r = _spots[i][2] * size.width;
      canvas.drawCircle(Offset(x, y), r, i.isEven ? base : dark);
      final angle = 1.2 + i * 0.65, len = r * (1.8 + (i % 3) * 0.6);
      canvas.drawLine(Offset(x, y), Offset(x + len * math.cos(angle), y + len * math.sin(angle)),
        Paint()..color = const Color(0xFFAA0000)..strokeWidth = r * 1.1..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    }
    for (int i = 0; i < 7; i++) {
      canvas.drawCircle(Offset(size.width * ((i * 0.317 + 0.15) % 1.0), size.height * ((i * 0.573 + 0.09) % 1.0)), size.width * .022, dark);
    }
  }
  @override
  bool shouldRepaint(_BloodPainter _) => false;
}

class _SegmentPainter extends CustomPainter {
  final int value; final Color color;
  const _SegmentPainter(this.value, this.color);
  static const _segs = <int, List<bool>>{
    1: [false, true,  true,  false, false, false, false],
    2: [true,  true,  false, true,  true,  false, true ],
    3: [true,  true,  true,  true,  false, false, true ],
    4: [false, true,  true,  false, false, true,  true ],
    5: [true,  false, true,  true,  false, true,  true ],
    6: [true,  false, true,  true,  true,  true,  true ],
  };
  @override
  void paint(Canvas canvas, Size size) {
    final s = _segs[value] ?? List.filled(7, false);
    final w = size.width, h = size.height, t = w * .17, g = t * .22;
    final onP  = Paint()..color = color;
    final offP = Paint()..color = color.withOpacity(.09);
    final glow = Paint()..color = color.withOpacity(.38)..maskFilter = MaskFilter.blur(BlurStyle.normal, t * .9);
    final rr   = Radius.circular(t / 2);
    void dH(bool on, double x1, double x2, double y) {
      final rc = RRect.fromRectAndRadius(Rect.fromLTRB(x1 + g, y - t / 2, x2 - g, y + t / 2), rr);
      if (on) canvas.drawRRect(rc, glow);
      canvas.drawRRect(rc, on ? onP : offP);
    }
    void dV(bool on, double x, double y1, double y2) {
      final rc = RRect.fromRectAndRadius(Rect.fromLTRB(x - t / 2, y1 + g, x + t / 2, y2 - g), rr);
      if (on) canvas.drawRRect(rc, glow);
      canvas.drawRRect(rc, on ? onP : offP);
    }
    final l = t / 2, r = w - t / 2, top = t / 2, mid = h / 2, bot = h - t / 2;
    if (value == 1) { dV(true, w / 2, top, mid); dV(true, w / 2, mid, bot); return; }
    dH(s[0], l, r, top); dV(s[1], r, top, mid); dV(s[2], r, mid, bot);
    dH(s[3], l, r, bot); dV(s[4], l, mid, bot); dV(s[5], l, top, mid); dH(s[6], l, r, mid);
  }
  @override
  bool shouldRepaint(_SegmentPainter old) => old.value != value || old.color != color;
}

class _CrackPainter extends CustomPainter {
  const _CrackPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()..color = Colors.white.withOpacity(.22)..strokeWidth = 2.5..style = PaintingStyle.stroke..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final line = Paint()..color = Colors.white.withOpacity(.6)..strokeWidth = .7..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final thin = Paint()..color = Colors.white.withOpacity(.45)..strokeWidth = .45..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final ix = size.width * .63, iy = size.height * .3;
    final impact = Offset(ix, iy);
    final ends = [Offset(size.width * .05, size.height * .85), Offset(size.width * .96, size.height * .9), Offset(size.width * .12, size.height * .04), Offset(size.width * .98, size.height * .2), Offset(size.width * .45, size.height * .98), Offset(size.width * .78, size.height * .1)];
    for (final end in ends) {
      canvas.drawLine(impact, end, glow);
      canvas.drawLine(impact, end, line);
      final mid = Offset((impact.dx + end.dx) / 2, (impact.dy + end.dy) / 2);
      final dx = end.dx - impact.dx, dy = end.dy - impact.dy;
      canvas.drawLine(mid, Offset(mid.dx - dy * .25 + dx * .18, mid.dy + dx * .25 + dy * .18), thin);
    }
    canvas.drawCircle(impact, 2.8, Paint()..color = Colors.white.withOpacity(.75)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawCircle(impact, 1.2, Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(_CrackPainter _) => false;
}

// ═══════════════════════════════════════════════════════════
// KRONENMESSER – Diamond-Rarity Animated Dice
// ═══════════════════════════════════════════════════════════

class _DiceCrown extends StatefulWidget {
  const _DiceCrown({required this.value, required this.isHeld, required this.size});
  final int value; final bool isHeld; final double size;

  @override
  State<_DiceCrown> createState() => _DiceCrownState();
}

class _DiceCrownState extends State<_DiceCrown> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final held = widget.isHeld;
        final sz = widget.size;

        final pulse = math.sin(t * 2 * math.pi);
        final glowBlur = held ? 26.0 : (13.0 + 5.0 * pulse);
        final glowAlpha = held ? 0.90 : (0.38 + 0.14 * pulse);
        final glowColor = held ? const Color(0xFFFFD700) : const Color(0xFF00C8FF);

        final borderColor = held
            ? const Color(0xFFFFD700)
            : Color.lerp(
                const Color(0xFF00D4FF),
                const Color(0xFF7B68EE),
                pulse * 0.5 + 0.5,
              )!;

        return Container(
          width: sz, height: sz,
          decoration: BoxDecoration(
            color: const Color(0xFF030912),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: held ? 2.0 : 1.5),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: glowAlpha),
                blurRadius: glowBlur,
                spreadRadius: held ? 3 : 0,
              ),
              if (held)
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.22),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.5),
            child: RepaintBoundary(
              child: Stack(fit: StackFit.expand, children: [
                CustomPaint(painter: _CrownAmbientPainter(t: t, isHeld: held)),
                CustomPaint(painter: _CrownShimmerPainter(t: t, isHeld: held)),
                Padding(
                  padding: EdgeInsets.all(sz * 0.13),
                  child: CustomPaint(
                    painter: _CrownGlowPipPainter(widget.value, t, held),
                  ),
                ),
                CustomPaint(painter: _SparkPainter(isHeld: held)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// Soft breathing radial glow at the die center.
class _CrownAmbientPainter extends CustomPainter {
  final double t;
  final bool isHeld;
  const _CrownAmbientPainter({required this.t, required this.isHeld});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final pulse = math.sin(t * 2 * math.pi);
    final color = isHeld ? const Color(0xFFFF7700) : const Color(0xFF0055BB);
    final alpha = isHeld ? 0.25 : (0.08 + 0.05 * pulse);
    final radius = size.width * (isHeld ? 0.70 : (0.55 + 0.08 * pulse));

    canvas.drawCircle(
      Offset(cx, cy), radius,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.38),
    );
    if (isHeld) {
      canvas.drawCircle(
        Offset(cx, cy), size.width * 0.32,
        Paint()
          ..color = const Color(0xFFFFAA00).withValues(alpha: 0.14)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.22),
      );
    }
  }

  @override
  bool shouldRepaint(_CrownAmbientPainter old) => old.t != t || old.isHeld != isHeld;
}

// Diagonal shimmer band that sweeps across the die face each cycle.
class _CrownShimmerPainter extends CustomPainter {
  final double t;
  final bool isHeld;
  const _CrownShimmerPainter({required this.t, required this.isHeld});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-math.pi / 4);

    final bandCenter = diagonal * (t - 0.5);
    final bandWidth = diagonal * 0.18;
    final shimmerColor = isHeld ? const Color(0xFFFFD700) : const Color(0xFF7FEFFF);
    final peakAlpha = isHeld ? 0.20 : 0.13;

    final rect = Rect.fromCenter(
      center: Offset(bandCenter, 0),
      width: bandWidth,
      height: diagonal,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            shimmerColor.withValues(alpha: peakAlpha * 0.3),
            shimmerColor.withValues(alpha: peakAlpha),
            shimmerColor.withValues(alpha: peakAlpha * 0.3),
            Colors.transparent,
          ],
          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CrownShimmerPainter old) => old.t != t || old.isHeld != isHeld;
}

// Triple-layer glowing orb pips that pulse with the animation.
class _CrownGlowPipPainter extends CustomPainter {
  final int value;
  final double t;
  final bool isHeld;
  const _CrownGlowPipPainter(this.value, this.t, this.isHeld);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * 0.12;
    final pulse = isHeld ? 1.0 : (0.90 + 0.10 * math.sin(t * 2 * math.pi + 0.9));

    for (final pip in _kPips[value] ?? const <Offset>[]) {
      final cx = pip.dx * size.width;
      final cy = pip.dy * size.height;

      canvas.drawCircle(Offset(cx, cy), r * 3.4 * pulse,
          Paint()
            ..color = (isHeld ? const Color(0xFFFFAA00) : const Color(0xFF00D4FF))
                .withValues(alpha: 0.09)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 3.2));
      canvas.drawCircle(Offset(cx, cy), r * 1.8 * pulse,
          Paint()
            ..color = (isHeld ? const Color(0xFFFFCC00) : const Color(0xFF38D4F5))
                .withValues(alpha: 0.40)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.3));
      canvas.drawCircle(Offset(cx, cy), r * pulse,
          Paint()..color = isHeld ? const Color(0xFFFFD700) : const Color(0xFF9BE4FF));
      canvas.drawCircle(Offset(cx, cy), r * 0.38,
          Paint()..color = Colors.white.withValues(alpha: 0.95));
    }
  }

  @override
  bool shouldRepaint(_CrownGlowPipPainter old) =>
      old.value != value || old.t != t || old.isHeld != isHeld;
}

// 4-pointed sparkle (✦) in the top-right corner of the die.
class _SparkPainter extends CustomPainter {
  final bool isHeld;
  const _SparkPainter({required this.isHeld});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width  * .820;
    final sy = size.height * .175;
    final lenV = size.width * (isHeld ? .115 : .075);  // vertical arm length
    final lenH = lenV * .55;                            // horizontal arm (shorter)
    final lenD = lenV * .40;                            // diagonal arm (shortest)
    final baseColor = isHeld ? const Color(0xFFFFE566) : const Color(0xFFBEEFFF);
    final alpha     = isHeld ? .98 : .62;

    final glow = Paint()
      ..color = baseColor.withValues(alpha: isHeld ? .38 : .20)
      ..strokeWidth = isHeld ? 5.0 : 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    final line = Paint()
      ..color = baseColor.withValues(alpha: alpha)
      ..strokeWidth = isHeld ? 1.3 : .85
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Main cross
    final arms = [
      [Offset(sx, sy - lenV), Offset(sx, sy + lenV)],
      [Offset(sx - lenH, sy), Offset(sx + lenH, sy)],
      // Diagonal arms
      [Offset(sx - lenD, sy - lenD), Offset(sx + lenD, sy + lenD)],
      [Offset(sx + lenD, sy - lenD), Offset(sx - lenD, sy + lenD)],
    ];
    for (final arm in arms) {
      canvas.drawLine(arm[0], arm[1], glow);
      canvas.drawLine(arm[0], arm[1], line);
    }
    // Bright center dot
    canvas.drawCircle(Offset(sx, sy), isHeld ? 1.7 : 1.1,
        Paint()..color = Colors.white.withValues(alpha: alpha));
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.isHeld != isHeld;
}
