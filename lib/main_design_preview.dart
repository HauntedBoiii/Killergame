// Preview-only entry point. Run with: flutter run -t lib/main_design_preview.dart -d edge
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final _kPips = <int, List<Offset>>{
  1: [const Offset(.5, .5)],
  2: [const Offset(.25, .25), const Offset(.75, .75)],
  3: [const Offset(.75, .25), const Offset(.5, .5), const Offset(.25, .75)],
  4: [const Offset(.25, .25), const Offset(.75, .25), const Offset(.25, .75), const Offset(.75, .75)],
  5: [const Offset(.25, .25), const Offset(.75, .25), const Offset(.5, .5), const Offset(.25, .75), const Offset(.75, .75)],
  6: [const Offset(.25, .18), const Offset(.75, .18), const Offset(.25, .5), const Offset(.75, .5), const Offset(.25, .82), const Offset(.75, .82)],
};

void main() => runApp(const DesignPreviewApp());

class DesignPreviewApp extends StatelessWidget {
  const DesignPreviewApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Design Vorschau',
        debugShowCheckedModeBanner: false,
        darkTheme: ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: const Color(0xFF0E0E0E)),
        themeMode: ThemeMode.dark,
        home: const _PreviewScreen(),
      );
}

class _PreviewScreen extends StatelessWidget {
  const _PreviewScreen();
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF1A1A1A),
            title: Text('Design Vorschau', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700, fontSize: 20)),
            bottom: const TabBar(
              indicatorColor: Color(0xFFEF5350),
              labelColor: Color(0xFFEF5350),
              unselectedLabelColor: Colors.white54,
              tabs: [Tab(icon: Icon(Icons.person_outline), text: 'Profilkarte'), Tab(icon: Icon(Icons.casino_outlined), text: 'Würfel')],
            ),
          ),
          body: const TabBarView(children: [_ProfileCardTab(), _DiceTab()]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED HELPERS
// ═══════════════════════════════════════════════════════════════════════════

Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
    );

Widget _avatar({double r = 32, Color? bg}) => CircleAvatar(
      radius: r,
      backgroundColor: bg ?? Colors.white.withOpacity(.22),
      child: Text('M', style: TextStyle(fontSize: r * .85, fontWeight: FontWeight.bold, color: Colors.white)),
    );

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.value, required this.label});
  final String icon, value, label;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 3),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(.5), fontSize: 10)),
      ]);
}

// ═══════════════════════════════════════════════════════════════════════════
// PROFILE CARDS
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileCardTab extends StatelessWidget {
  const _ProfileCardTab();
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _label('CURRENT (Referenz)'), const _CardCurrent(), const SizedBox(height: 28),
          _label('#1 – Glas mit Shimmer'), const _Card1Glass(), const SizedBox(height: 28),
          _label('#2 – Neon (laufender Rand)'), const _Card2Neon(), const SizedBox(height: 28),
          _label('#3 – James Bond 007'), const _Card3Bond(), const SizedBox(height: 28),
          _label('#4 – Avatar + Funken'), const _Card4Avatar(), const SizedBox(height: 28),
          _label('#7 – Dark Smoke'), const _Card7Smoke(), const SizedBox(height: 28),
          _label('#8 – Steckbrief'), const _Card8Layered(), const SizedBox(height: 28),
          _label('#10 – Akzentlinie (Farbwechsel)'), const _Card10Accent(),
        ],
      );
}

// ─── CURRENT ───────────────────────────────────────────────────────────────
class _CardCurrent extends StatelessWidget {
  const _CardCurrent();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFB71C1C), Color(0xFF6D0000)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFFB71C1C).withOpacity(.35), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.6), width: 2)),
            child: _avatar(),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Willkommen,', style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 13)),
            Text('MaxMustermann', style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
            const SizedBox(height: 8),
            const Row(children: [_MiniStat(icon: '🗡️', value: '3', label: 'Kills'), SizedBox(width: 12), _MiniStat(icon: '🏆', value: '1', label: 'Wins'), SizedBox(width: 12), _MiniStat(icon: '🎮', value: '7', label: 'Spiele')]),
          ])),
          const SizedBox(width: 12),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.casino_rounded, color: Colors.white.withOpacity(.88), size: 28),
            const SizedBox(height: 3),
            Text('WÜRFELN', style: TextStyle(color: Colors.white.withOpacity(.6), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: .8)),
          ]),
        ]),
      );
}

// ─── #1 GLAS + SHIMMER (fixed: covers full card including corners) ──────────
class _Card1Glass extends StatefulWidget {
  const _Card1Glass();
  @override
  State<_Card1Glass> createState() => _Card1GlassState();
}
class _Card1GlassState extends State<_Card1Glass> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(.22), width: 1.2),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.35), width: 1.5)),
                  child: _avatar(bg: Colors.white.withOpacity(.12)),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Willkommen,', style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 13)),
                  Text('MaxMustermann', style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  const Row(children: [_MiniStat(icon: '🗡️', value: '3', label: 'Kills'), SizedBox(width: 12), _MiniStat(icon: '🏆', value: '1', label: 'Wins'), SizedBox(width: 12), _MiniStat(icon: '🎮', value: '7', label: 'Spiele')]),
                ])),
                Icon(Icons.casino_rounded, color: Colors.white.withOpacity(.5), size: 26),
              ]),
            ),
          ),
        ),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(painter: _ShimmerPainter(_ctrl.value)),
            ),
          ),
        ),
      ]);
}

// ─── #2 NEON LAUFENDER RAND ────────────────────────────────────────────────
class _Card2Neon extends StatefulWidget {
  const _Card2Neon();
  @override
  State<_Card2Neon> createState() => _Card2NeonState();
}
class _Card2NeonState extends State<_Card2Neon> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Stack(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEF5350).withOpacity(.2), width: 1.5),
            boxShadow: [BoxShadow(color: const Color(0xFFB71C1C).withOpacity(.4), blurRadius: 22), BoxShadow(color: const Color(0xFFFF6F00).withOpacity(.15), blurRadius: 44, spreadRadius: 4)],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFEF5350).withOpacity(.5), width: 2)),
              child: _avatar(bg: const Color(0xFF2A0000)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Willkommen,', style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 13)),
              Text('MaxMustermann', style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
              const SizedBox(height: 8),
              const Row(children: [_MiniStat(icon: '🗡️', value: '3', label: 'Kills'), SizedBox(width: 12), _MiniStat(icon: '🏆', value: '1', label: 'Wins'), SizedBox(width: 12), _MiniStat(icon: '🎮', value: '7', label: 'Spiele')]),
            ])),
            Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.casino_rounded, color: Color(0xFFEF5350), size: 28),
              const SizedBox(height: 3),
              const Text('WÜRFELN', style: TextStyle(color: Color(0xFFEF5350), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: .8)),
            ]),
          ]),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(painter: _NeonBorderPainter(progress: _ctrl.value, color: const Color(0xFFEF5350), radius: 20)),
          ),
        ),
      ]);
}

// ─── #3 BOND 007 (updated: round avatar, no CODE NAME, yellow agent name) ──
class _Card3Bond extends StatelessWidget {
  const _Card3Bond();
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF050A14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(.55), width: 1),
          boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(.12), blurRadius: 22)],
        ),
        child: Stack(children: [
          Positioned(top: -25, right: -25, child: CustomPaint(size: const Size(150, 150), painter: _GunBarrelPainter())),
          Positioned(bottom: -18, left: -4, child: Text('007',
            style: GoogleFonts.rajdhani(fontSize: 110, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37).withOpacity(.055), letterSpacing: 4))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SizedBox(width: 38, height: 44, child: Stack(children: [
                  CustomPaint(size: const Size(38, 44), painter: _CrestPainter()),
                  const Positioned.fill(child: Padding(padding: EdgeInsets.only(bottom: 4), child: Center(child: Text('M', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 17, fontWeight: FontWeight.w900))))),
                ])),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('MI6 — SECRET INTELLIGENCE SERVICE', style: TextStyle(color: const Color(0xFFD4AF37).withOpacity(.65), fontSize: 7.5, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                  Text('AGENT DOSSIER', style: TextStyle(color: Colors.white.withOpacity(.28), fontSize: 9, letterSpacing: 1)),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD4AF37), width: 1), borderRadius: BorderRadius.circular(3)),
                  child: const Text('TOP SECRET', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ]),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Round avatar with gold border
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0A1020),
                    border: Border.all(color: const Color(0xFFD4AF37).withOpacity(.65), width: 2),
                    boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(.18), blurRadius: 10)],
                  ),
                  child: const Center(child: Text('M', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _DossierField('AGENT', 'MAX MUSTERMANN', valueColor: const Color(0xFFD4AF37)),
                  const SizedBox(height: 5),
                  _DossierField('CLEARANCE', 'LEVEL 7 — ACTIVE'),
                ])),
              ]),
              const SizedBox(height: 14),
              Row(children: List.generate(28, (i) => Expanded(child: Container(height: 1, color: const Color(0xFFD4AF37).withOpacity(i.isEven ? .4 : .1))))),
              const SizedBox(height: 10),
              Row(children: [
                _GoldStat('KILLS', '3'), const SizedBox(width: 22),
                _GoldStat('WINS', '1'), const SizedBox(width: 22),
                _GoldStat('SPIELE', '7'),
                const Spacer(),
                Icon(Icons.casino_rounded, color: const Color(0xFFD4AF37).withOpacity(.5), size: 20),
              ]),
            ]),
          ),
        ]),
      );
}

class _DossierField extends StatelessWidget {
  const _DossierField(this.label, this.value, {this.big = false, this.valueColor});
  final String label, value;
  final bool big;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: const Color(0xFFD4AF37).withOpacity(.5), fontSize: 8, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
        Text(value, style: big
            ? GoogleFonts.rajdhani(fontSize: 26, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37), letterSpacing: 3)
            : TextStyle(color: valueColor ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      ]);
}

class _GoldStat extends StatelessWidget {
  const _GoldStat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: const Color(0xFFD4AF37).withOpacity(.5), fontSize: 8, letterSpacing: 1)),
        Text(value, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 17, fontWeight: FontWeight.w900)),
      ]);
}

// ─── #4 AVATAR + FUNKEN ────────────────────────────────────────────────────
class _Card4Avatar extends StatefulWidget {
  const _Card4Avatar();
  @override
  State<_Card4Avatar> createState() => _Card4AvatarState();
}
class _Card4AvatarState extends State<_Card4Avatar> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1E1E1E), Color(0xFF1A0000)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(.06), width: 1),
        ),
        child: Stack(children: [
          // Sparks + ambient flicker fill entire card
          Positioned.fill(child: AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _SparksPainter(_ctrl.value)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [Color(0xFFB71C1C), Color(0xFFFF6F00), Color(0xFFFFB300), Color(0xFFB71C1C)])),
                child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1E1E1E)), child: _avatar(r: 40)),
              ),
              const SizedBox(height: 10),
              Text('MaxMustermann', style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              Text('Willkommen zurück', style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 12)),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _BigStat('🗡️', '3', 'Kills', const Color(0xFFEF5350)),
                Container(width: 1, height: 34, color: Colors.white.withOpacity(.1)),
                _BigStat('🏆', '1', 'Wins', const Color(0xFFFFB300)),
                Container(width: 1, height: 34, color: Colors.white.withOpacity(.1)),
                _BigStat('🎮', '7', 'Spiele', Colors.white60),
              ]),
            ]),
          ),
          Positioned(bottom: 10, right: 14,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.casino_rounded, color: Colors.white.withOpacity(.55), size: 22),
              const SizedBox(height: 2),
              Text('WÜRFELN', style: TextStyle(color: Colors.white.withOpacity(.35), fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: .7)),
            ])),
        ]),
      );
}

class _BigStat extends StatelessWidget {
  const _BigStat(this.icon, this.value, this.label, this.color);
  final String icon, value, label; final Color color;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900, height: 1)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(.4), fontSize: 10)),
      ]);
}

// ─── #7 DARK SMOKE (updated: dice icon, more visible smoke) ────────────────
class _Card7Smoke extends StatefulWidget {
  const _Card7Smoke();
  @override
  State<_Card7Smoke> createState() => _Card7SmokeState();
}
class _Card7SmokeState extends State<_Card7Smoke> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF3D0000), Color(0xFF080808)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.7), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Stack(children: [
          Positioned.fill(child: AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _SmokePainter(_ctrl.value)))),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              _avatar(bg: const Color(0xFF1A0000)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Willkommen,', style: TextStyle(color: Colors.white.withOpacity(.4), fontSize: 12)),
                Text('MaxMustermann', style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                const SizedBox(height: 8),
                const Row(children: [_MiniStat(icon: '🗡️', value: '3', label: 'Kills'), SizedBox(width: 12), _MiniStat(icon: '🏆', value: '1', label: 'Wins'), SizedBox(width: 12), _MiniStat(icon: '🎮', value: '7', label: 'Spiele')]),
              ])),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.casino_rounded, color: Colors.white.withOpacity(.65), size: 28),
                const SizedBox(height: 3),
                Text('WÜRFELN', style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: .8)),
              ]),
            ]),
          ),
        ]),
      );
}

// ─── #8 STECKBRIEF (WANTED poster redesign) ────────────────────────────────
class _Card8Layered extends StatelessWidget {
  const _Card8Layered();
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8D5A3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF7A4A10), width: 2.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 18, offset: const Offset(0, 7))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Top banner
            Container(
              width: double.infinity,
              color: const Color(0xFF3E1A00),
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
              child: Text('★   G E S U C H T   ★', textAlign: TextAlign.center,
                style: GoogleFonts.rajdhani(color: const Color(0xFFE8D5A3), fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 4)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(children: [
                // Round avatar with ornate frame
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD4B483),
                    border: Border.all(color: const Color(0xFF7A4A10), width: 3),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 8)],
                  ),
                  child: const Center(child: Text('M', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF3E1A00)))),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('MAX MUSTERMANN', style: GoogleFonts.rajdhani(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF3E1A00), letterSpacing: 1.5)),
                  const SizedBox(height: 5),
                  Row(children: [
                    _WantedStat('KILLS', '3'), const SizedBox(width: 16),
                    _WantedStat('SIEGE', '1'), const SizedBox(width: 16),
                    _WantedStat('SPIELE', '7'),
                    const Spacer(),
                    Icon(Icons.casino_rounded, color: const Color(0xFF7A4A10).withOpacity(.55), size: 20),
                  ]),
                ])),
              ]),
            ),
            // Western-style BELOHNUNG footer banner
            Container(
              width: double.infinity,
              color: const Color(0xFF3E1A00),
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
              child: Text('BELOHNUNG: EWIGER RUHM', textAlign: TextAlign.center,
                style: GoogleFonts.rye(color: const Color(0xFFE8D5A3), fontSize: 12, letterSpacing: .5)),
            ),
          ]),
        ),
      );
}

class _WantedStat extends StatelessWidget {
  const _WantedStat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: const Color(0xFF7A4A10).withOpacity(.7), fontSize: 8, letterSpacing: 1, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(color: Color(0xFF3E1A00), fontSize: 16, fontWeight: FontWeight.w900)),
      ]);
}

// ─── #10 AKZENTLINIE FARBWECHSEL ──────────────────────────────────────────
class _Card10Accent extends StatefulWidget {
  const _Card10Accent();
  @override
  State<_Card10Accent> createState() => _Card10AccentState();
}
class _Card10AccentState extends State<_Card10Accent> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(); }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final color = HSVColor.fromAHSV(1, _ctrl.value * 360, .9, .95).toColor();
          return Container(
            decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(.06), width: 1)),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AnimatedContainer(
                  duration: Duration.zero,
                  width: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [color, color.withOpacity(.4)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                    boxShadow: [BoxShadow(color: color.withOpacity(.55), blurRadius: 14)],
                  ),
                ),
                Expanded(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withOpacity(.5), width: 1.5)),
                      child: _avatar(r: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Willkommen,', style: TextStyle(color: Colors.white.withOpacity(.4), fontSize: 12)),
                      Text('MaxMustermann', style: GoogleFonts.rajdhani(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      const Row(children: [_MiniStat(icon: '🗡️', value: '3', label: 'Kills'), SizedBox(width: 12), _MiniStat(icon: '🏆', value: '1', label: 'Wins'), SizedBox(width: 12), _MiniStat(icon: '🎮', value: '7', label: 'Spiele')]),
                    ])),
                    Icon(Icons.casino_rounded, color: Colors.white.withOpacity(.3), size: 22),
                  ]),
                )),
              ]),
            ),
          );
        },
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// CARD PAINTERS
// ═══════════════════════════════════════════════════════════════════════════

// Fixed: strip uses full card diagonal so corners are always covered
class _ShimmerPainter extends CustomPainter {
  final double t;
  const _ShimmerPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final diag = math.sqrt(size.width * size.width + size.height * size.height);
    final stripW = diag * .38;
    // sweep x from -diag/2 to 1.5*diag so corners are always hit
    final x = -diag * .5 + diag * 2.0 * t;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-.28);
    canvas.translate(-size.width / 2, -size.height / 2);
    final rect = Rect.fromLTWH(x - stripW / 2, -diag / 2, stripW, size.height + diag);
    canvas.drawRect(rect, Paint()..shader = LinearGradient(
      colors: [Colors.transparent, Colors.white.withOpacity(.14), Colors.white.withOpacity(.34), Colors.white.withOpacity(.14), Colors.transparent],
      stops: const [0, .3, .5, .7, 1],
    ).createShader(rect));
    canvas.restore();
  }
  @override
  bool shouldRepaint(_ShimmerPainter old) => old.t != t;
}

class _NeonBorderPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double radius;
  const _NeonBorderPainter({required this.progress, required this.color, required this.radius});
  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final total = metric.length;
    final segLen = total * .22;
    final start = progress * total;
    final end = start + segLen;
    final Path seg;
    if (end <= total) {
      seg = metric.extractPath(start, end);
    } else {
      seg = metric.extractPath(start, total);
      seg.addPath(metric.extractPath(0, end - total), Offset.zero);
    }
    canvas.drawPath(seg, Paint()..color = color.withOpacity(.4)..strokeWidth = 12..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawPath(seg, Paint()..color = color.withOpacity(.7)..strokeWidth = 4..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawPath(seg, Paint()..color = Colors.white.withOpacity(.95)..strokeWidth = 1.8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_NeonBorderPainter old) => old.progress != progress;
}

// Sparks + flickering ambient glow from bottom
class _SparksPainter extends CustomPainter {
  final double t;
  const _SparksPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    // Ambient flicker glow from bottom (two layers for depth)
    final flicker = 0.30 + 0.18 * math.sin(t * math.pi * 2 * 3.7) + 0.08 * math.sin(t * math.pi * 2 * 8.1);
    final c1 = Offset(size.width / 2, size.height);
    final r1 = size.width * 0.75;
    canvas.drawCircle(c1, r1, Paint()..shader = RadialGradient(
      colors: [const Color(0xFFFF4500).withOpacity(flicker), const Color(0xFFFF8C00).withOpacity(flicker * .45), Colors.transparent],
      stops: const [0.0, 0.45, 1.0],
    ).createShader(Rect.fromCircle(center: c1, radius: r1)));

    final flicker2 = 0.16 + 0.12 * math.sin(t * math.pi * 2 * 5.3 + 1.2);
    final c2 = Offset(size.width / 2, size.height + 10);
    final r2 = size.width * 0.45;
    canvas.drawCircle(c2, r2, Paint()..shader = RadialGradient(
      colors: [const Color(0xFFFFD700).withOpacity(flicker2), Colors.transparent],
    ).createShader(Rect.fromCircle(center: c2, radius: r2)));

    // Ascending sparks
    for (int i = 0; i < 22; i++) {
      final baseX = (i * 0.618033) % 1.0;
      final speedMult = 0.55 + (i * 0.137) % 0.85;
      final phase = (t * speedMult + i * 0.0454) % 1.0;
      final x = size.width * (0.05 + 0.9 * baseX) + 10 * math.sin(t * math.pi * 2 * 1.3 + i * 1.1);
      final y = size.height * (1.02 - phase * 1.3);
      if (y < -8 || y > size.height + 6) continue;
      final alpha = (1.0 - phase * 1.2).clamp(0.0, 1.0);
      final sz = (2.4 - 1.5 * phase).clamp(0.4, 2.4);
      final sparkColor = Color.lerp(const Color(0xFFFF4500), const Color(0xFFFFFFCC), (phase * 0.9).clamp(0.0, 1.0))!;
      canvas.drawCircle(Offset(x, y), sz,
        Paint()..color = sparkColor.withOpacity(alpha * 0.88)..maskFilter = MaskFilter.blur(BlurStyle.normal, sz * 0.55));
      canvas.drawCircle(Offset(x, y), sz * 0.38,
        Paint()..color = Colors.white.withOpacity(alpha * 0.7));
    }
  }
  @override
  bool shouldRepaint(_SparksPainter old) => old.t != t;
}

class _SmokePainter extends CustomPainter {
  final double t;
  const _SmokePainter(this.t);
  static const _xBases = [.15, .38, .58, .28, .48, .7];
  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 6; i++) {
      final phase = (t * .45 + i * .18) % 1.0;
      final x = size.width * _xBases[i] + 14 * math.sin(t * math.pi * 2 * .7 + i * 1.3);
      final y = size.height * (1.05 - phase * 1.15);
      if (y < -30 || y > size.height + 10) continue;
      final opacity = math.max(0.0, .22 * (1 - phase * 1.4)).toDouble();
      final r = size.width * .07 * (1 + phase * .9);
      canvas.drawCircle(Offset(x, y), r,
        Paint()..color = Colors.white.withOpacity(opacity)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .65));
    }
  }
  @override
  bool shouldRepaint(_SmokePainter old) => old.t != t;
}

class _GunBarrelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final p = Paint()..color = const Color(0xFFD4AF37).withOpacity(.14)..strokeWidth = 1..style = PaintingStyle.stroke;
    for (int i = 1; i <= 9; i++) canvas.drawCircle(Offset(cx, cy), size.width * i / 18, p);
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), p..strokeWidth = .8);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), p);
    canvas.drawCircle(Offset(cx, cy), size.width * .06, Paint()..color = Colors.black.withOpacity(.6));
  }
  @override
  bool shouldRepaint(_GunBarrelPainter _) => false;
}

class _CrestPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final shield = Path()
      ..moveTo(w * .08, 0)..lineTo(w * .92, 0)..lineTo(w * .92, h * .58)
      ..quadraticBezierTo(w * .92, h * .82, w * .5, h)
      ..quadraticBezierTo(w * .08, h * .82, w * .08, h * .58)..close();
    canvas.drawPath(shield, Paint()..color = const Color(0xFFD4AF37).withOpacity(.1));
    canvas.drawPath(shield, Paint()..color = const Color(0xFFD4AF37).withOpacity(.75)..strokeWidth = 1.2..style = PaintingStyle.stroke);
  }
  @override
  bool shouldRepaint(_CrestPainter _) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// DICE TAB
// ═══════════════════════════════════════════════════════════════════════════

class _DiceTab extends StatelessWidget {
  const _DiceTab();
  static const _vals = [2, 4, 5, 1, 6];
  static const _heldIdx = 2;
  static const _sz = 56.0;

  @override
  Widget build(BuildContext context) {
    final designs = <(String, Widget Function(int, bool))>[
      ('CURRENT', _current),
      ('W1 – Holz (Jahresringe + Rinde)', _wood),
      ('W2 – Neon Pips', _neon),
      ('W4 – Vegas Black & Gold', _vegas),
      ('W5 – Blut', _blood),
      ('W6 – App-Rot', _appRed),
      ('W7 – Digital (7-Segment)', _digital),
      ('W9 – Kristall mit Rissen', _cracked),
    ];
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: designs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 28),
      itemBuilder: (_, i) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(designs[i].$1),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (int j = 0; j < _vals.length; j++) designs[i].$2(_vals[j], j == _heldIdx)]),
      ]),
    );
  }

  static Widget _current(int v, bool held) => _base(v: v, held: held,
      bg: held ? const Color(0xFF2E2100) : const Color(0xFF242424),
      border: held ? const Color(0xFFFFB300) : const Color(0x1FFFFFFF),
      pip: held ? const Color(0xFFFFB300) : Colors.white,
      glow: held ? const Color(0xFFFFB300) : null);

  // W1: wood grain lines across face, bark rings only at perimeter
  static Widget _wood(int v, bool held) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: _sz, height: _sz,
      decoration: BoxDecoration(
        color: held ? const Color(0xFFBB7A40) : const Color(0xFF7A4E28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: held ? const Color(0xFFFFD580) : const Color(0xFF3D1800), width: held ? 2.5 : 2),
        boxShadow: held
          ? [BoxShadow(color: const Color(0xFFFFD580).withOpacity(.4), blurRadius: 10)]
          : [BoxShadow(color: Colors.black.withOpacity(.45), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(fit: StackFit.expand, children: [
          CustomPaint(painter: _WoodPainter()),
          Padding(padding: const EdgeInsets.all(8), child: CustomPaint(painter: _PipPainter(v, const Color(0xFF2C1000), pipScale: .14))),
        ]),
      ),
    );
  }

  static Widget _neon(int v, bool held) {
    final c = held ? const Color(0xFFFFD700) : const Color(0xFFFF3B3B);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: _sz, height: _sz,
      decoration: BoxDecoration(
        color: const Color(0xFF080808),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: held ? const Color(0xFFFFD700) : Colors.white.withOpacity(.06), width: held ? 2 : 1),
        boxShadow: [BoxShadow(color: c.withOpacity(.45), blurRadius: held ? 18 : 10)],
      ),
      padding: const EdgeInsets.all(8),
      child: CustomPaint(painter: _NeonPipPainter(v, c, c)),
    );
  }

  static Widget _vegas(int v, bool held) {
    final gold = held ? const Color(0xFFFFE066) : const Color(0xFFFFB300);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: _sz, height: _sz,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: gold, width: held ? 2.5 : 1.5),
        boxShadow: [BoxShadow(color: gold.withOpacity(held ? .55 : .25), blurRadius: held ? 14 : 6)],
      ),
      padding: const EdgeInsets.all(8),
      child: CustomPaint(painter: _DiamondPipPainter(v, gold)),
    );
  }

  // W5: blood splatter die
  static Widget _blood(int v, bool held) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: _sz, height: _sz,
    decoration: BoxDecoration(
      color: held ? const Color(0xFF1A0000) : const Color(0xFF0D0D0D),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: held ? const Color(0xFFFF4444) : const Color(0xFF660000), width: held ? 2 : 1.5),
      boxShadow: [BoxShadow(color: const Color(0xFFCC0000).withOpacity(held ? .45 : .2), blurRadius: held ? 14 : 6)],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: _BloodPainter()),
        Padding(padding: const EdgeInsets.all(8), child: CustomPaint(painter: _PipPainter(v, Colors.white.withOpacity(.92)))),
      ]),
    ),
  );

  static Widget _appRed(int v, bool held) => _base(v: v, held: held,
      bg: held ? const Color(0xFF6D0000) : const Color(0xFF3A0000),
      border: held ? const Color(0xFFFFB300) : const Color(0xFFB71C1C),
      pip: held ? const Color(0xFFFFB300) : Colors.white.withOpacity(.9),
      glow: held ? const Color(0xFFFFB300) : const Color(0xFFB71C1C));

  // W7: 7-segment display
  static Widget _digital(int v, bool held) {
    final accent = held ? const Color(0xFFFFB300) : const Color(0xFF00E5FF);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: _sz, height: _sz,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(.6), width: held ? 2 : 1),
        boxShadow: [BoxShadow(color: accent.withOpacity(.3), blurRadius: 12)],
      ),
      padding: const EdgeInsets.all(10),
      child: CustomPaint(painter: _SegmentPainter(v, accent)),
    );
  }

  static Widget _cracked(int v, bool held) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _sz, height: _sz,
            decoration: BoxDecoration(
              color: held ? const Color(0xFF3D2B00).withOpacity(.5) : Colors.white.withOpacity(.09),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: held ? const Color(0xFFFFD580) : Colors.white.withOpacity(.28), width: held ? 2 : 1),
              boxShadow: held ? [BoxShadow(color: const Color(0xFFFFB300).withOpacity(.4), blurRadius: 12)] : [],
            ),
            child: Stack(fit: StackFit.expand, children: [
              Padding(padding: const EdgeInsets.all(8), child: CustomPaint(painter: _PipPainter(v, held ? const Color(0xFFFFD580) : Colors.white.withOpacity(.85)))),
              CustomPaint(painter: _CrackPainter()),
            ]),
          ),
        ),
      );

  static Widget _base({required int v, required bool held, required Color bg, required Color border, required Color pip, Color? glow, double radius = 10}) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: _sz, height: _sz,
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border, width: held ? 2.5 : 1.5),
          boxShadow: glow != null
              ? [BoxShadow(color: glow.withOpacity(.48), blurRadius: held ? 14 : 5, spreadRadius: 1)]
              : [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(8),
        child: CustomPaint(painter: _PipPainter(v, pip)),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// DICE PAINTERS
// ═══════════════════════════════════════════════════════════════════════════

class _PipPainter extends CustomPainter {
  final int value; final Color color; final double pipScale;
  const _PipPainter(this.value, this.color, {this.pipScale = .13});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final r = size.width * pipScale;
    for (final pip in _kPips[value] ?? const <Offset>[]) canvas.drawCircle(Offset(pip.dx * size.width, pip.dy * size.height), r, p);
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

// W1: grain lines across face, bark rings only at perimeter
class _WoodPainter extends CustomPainter {
  static const _barkR = [1.0, .96, .98, .93, 1.0, .97, .95, .98, .94, 1.0, .97, .95, .98, .93, 1.0, .96, .97, .94, 1.0, .95, .98, .96, .93, 1.0];
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;

    // Subtle horizontal wood grain lines across full face
    for (int i = 0; i < 14; i++) {
      final y = size.height * (i + .4) / 14;
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 3) {
        path.lineTo(x, y + 1.6 * math.sin(x * .35 + i * 1.1));
      }
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFF3D1800).withOpacity(.18)
        ..strokeWidth = .5
        ..style = PaintingStyle.stroke);
    }

    // Bark rings at perimeter only (outer 25% of radius)
    final steps = _barkR.length;
    final baseR = math.min(cx, cy);
    for (int ring = 0; ring < 4; ring++) {
      final frac = 0.72 + ring * 0.07; // 0.72 → 0.93
      final path = Path();
      for (int i = 0; i <= steps; i++) {
        final angle = i * 2 * math.pi / steps;
        final rr = baseR * frac * _barkR[i % steps];
        final x = cx + rr * math.cos(angle);
        final y = cy + rr * math.sin(angle);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      path.close();
      final isOuter = ring == 3;
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFF1A0500).withOpacity(isOuter ? .85 : (.22 + ring * .10))
        ..strokeWidth = isOuter ? 2.5 : .85
        ..style = PaintingStyle.stroke);
    }
  }
  @override
  bool shouldRepaint(_WoodPainter _) => false;
}

class _CrackPainter extends CustomPainter {
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

// W5: blood splatter on die face
class _BloodPainter extends CustomPainter {
  // Deterministic splatter layout [cx, cy, radius] as fractions of canvas size
  static const _spots = [
    [.22, .15, .07], [.68, .10, .05], [.78, .38, .08], [.12, .52, .06],
    [.55, .72, .07], [.38, .88, .05], [.85, .68, .06], [.48, .28, .04],
    [.08, .78, .05], [.62, .48, .04],
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final base  = Paint()..color = const Color(0xFFCC0000);
    final dark  = Paint()..color = const Color(0xFF880000);
    for (int i = 0; i < _spots.length; i++) {
      final x = _spots[i][0] * size.width;
      final y = _spots[i][1] * size.height;
      final r = _spots[i][2] * size.width;
      canvas.drawCircle(Offset(x, y), r, i.isEven ? base : dark);
      // Elongated drip tail
      final angle = 1.2 + i * 0.65;
      final len   = r * (1.8 + (i % 3) * 0.6);
      canvas.drawLine(Offset(x, y), Offset(x + len * math.cos(angle), y + len * math.sin(angle)),
        Paint()..color = const Color(0xFFAA0000)..strokeWidth = r * 1.1..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
    }
    // Tiny satellite drops
    for (int i = 0; i < 7; i++) {
      final x = size.width  * ((i * 0.317 + 0.15) % 1.0);
      final y = size.height * ((i * 0.573 + 0.09) % 1.0);
      canvas.drawCircle(Offset(x, y), size.width * .022, dark);
    }
  }
  @override
  bool shouldRepaint(_BloodPainter _) => false;
}

// W7: 7-segment display painter
// Segments: a=top, b=upper-right, c=lower-right, d=bottom, e=lower-left, f=upper-left, g=middle
class _SegmentPainter extends CustomPainter {
  final int value;
  final Color color;
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
    final w = size.width, h = size.height;
    final t = w * .17;   // segment thickness
    final g = t * .22;   // gap at segment ends

    final onPaint  = Paint()..color = color;
    final offPaint = Paint()..color = color.withOpacity(.09);
    final glowPaint = Paint()..color = color.withOpacity(.38)..maskFilter = MaskFilter.blur(BlurStyle.normal, t * .9);

    final rr = Radius.circular(t / 2);

    void drawH(bool on, double x1, double x2, double y) {
      final rect = Rect.fromLTRB(x1 + g, y - t / 2, x2 - g, y + t / 2);
      final rrect = RRect.fromRectAndRadius(rect, rr);
      if (on) canvas.drawRRect(rrect, glowPaint);
      canvas.drawRRect(rrect, on ? onPaint : offPaint);
    }

    void drawV(bool on, double x, double y1, double y2) {
      final rect = Rect.fromLTRB(x - t / 2, y1 + g, x + t / 2, y2 - g);
      final rrect = RRect.fromRectAndRadius(rect, rr);
      if (on) canvas.drawRRect(rrect, glowPaint);
      canvas.drawRRect(rrect, on ? onPaint : offPaint);
    }

    final l = t / 2;
    final r = w - t / 2;
    final top = t / 2;
    final mid = h / 2;
    final bot = h - t / 2;

    // Digit 1: draw single centered vertical bar, skip dim horizontals
    if (value == 1) {
      drawV(true, w / 2, top, mid);
      drawV(true, w / 2, mid, bot);
      return;
    }

    drawH(s[0], l, r, top);   // a top
    drawV(s[1], r, top, mid); // b upper-right
    drawV(s[2], r, mid, bot); // c lower-right
    drawH(s[3], l, r, bot);   // d bottom
    drawV(s[4], l, mid, bot); // e lower-left
    drawV(s[5], l, top, mid); // f upper-left
    drawH(s[6], l, r, mid);   // g middle
  }

  @override
  bool shouldRepaint(_SegmentPainter old) => old.value != value || old.color != color;
}
