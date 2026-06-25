import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moerderspiel/core/models/loot_item.dart';
import 'package:moerderspiel/presentation/widgets/common/avatar_widget.dart';

// ── Daten-Container ───────────────────────────────────────

class ProfileCardData {
  final String username;
  final String? avatarUrl;
  final String? userId;
  final int kills;
  final int wins;
  final int games;
  final VoidCallback? onDiceTap;
  final VoidCallback? onCardTap;

  const ProfileCardData({
    required this.username,
    this.avatarUrl,
    this.userId,
    this.kills = 0,
    this.wins  = 0,
    this.games = 0,
    this.onDiceTap,
    this.onCardTap,
  });
}

// ── Haupt-Widget: delegiert ans richtige Design ───────────

class ProfileCardWidget extends StatelessWidget {
  final CardDesign design;
  final ProfileCardData data;

  const ProfileCardWidget({super.key, required this.design, required this.data});

  @override
  Widget build(BuildContext context) => switch (design) {
    CardDesign.current => _CardCurrent(data: data),
    CardDesign.smoke   => _CardSmoke(data: data),
    CardDesign.accent  => _CardAccent(data: data),
    CardDesign.glass   => _CardGlass(data: data),
    CardDesign.neon    => _CardNeon(data: data),
    CardDesign.wanted  => _CardWanted(data: data),
    CardDesign.bond    => _CardBond(data: data),
    CardDesign.sparks  => _CardSparks(data: data),
  };
}

// ── Gemeinsame Helfer ─────────────────────────────────────

Widget _avatar(ProfileCardData d, {double r = 32, Color? bg}) =>
    KniffelAwareAvatarWidget(imageUrl: d.avatarUrl, name: d.username, radius: r, userId: d.userId);

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

Widget _statsRow(ProfileCardData d) => Row(children: [
      _MiniStat(icon: '🗡️', value: '${d.kills}', label: 'Kills'),
      const SizedBox(width: 12),
      _MiniStat(icon: '🏆', value: '${d.wins}', label: 'Wins'),
      const SizedBox(width: 12),
      _MiniStat(icon: '🎮', value: '${d.games}', label: 'Spiele'),
    ]);

Widget _diceButton(ProfileCardData d, {Color iconColor = Colors.white, double iconOpacity = 0.88}) =>
    GestureDetector(
      onTap: d.onDiceTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.casino_rounded, color: iconColor.withOpacity(iconOpacity), size: 28),
          const SizedBox(height: 3),
          Text('WÜRFELN', style: TextStyle(color: iconColor.withOpacity(iconOpacity * .68), fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: .8)),
        ]),
      ),
    );

// ═══════════════════════════════════════════════════════════
// CARD DESIGNS
// ═══════════════════════════════════════════════════════════

// ─── CURRENT (Standard) ───────────────────────────────────
class _CardCurrent extends StatelessWidget {
  const _CardCurrent({required this.data});
  final ProfileCardData data;
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
            child: _avatar(data),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Willkommen,', style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 13)),
            Text(data.username, style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
            const SizedBox(height: 8),
            _statsRow(data),
          ])),
          const SizedBox(width: 12),
          _diceButton(data),
        ]),
      );
}

// ─── DARK SMOKE ───────────────────────────────────────────
class _CardSmoke extends StatefulWidget {
  const _CardSmoke({required this.data});
  final ProfileCardData data;
  @override
  State<_CardSmoke> createState() => _CardSmokeState();
}
class _CardSmokeState extends State<_CardSmoke> with SingleTickerProviderStateMixin {
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
          Padding(padding: const EdgeInsets.all(20), child: Row(children: [
            _avatar(widget.data, bg: const Color(0xFF1A0000)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Willkommen,', style: TextStyle(color: Colors.white.withOpacity(.4), fontSize: 12)),
              Text(widget.data.username, style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
              const SizedBox(height: 8),
              _statsRow(widget.data),
            ])),
            _diceButton(widget.data, iconOpacity: .65),
          ])),
        ]),
      );
}

// ─── FARBWECHSEL ──────────────────────────────────────────
class _CardAccent extends StatefulWidget {
  const _CardAccent({required this.data});
  final ProfileCardData data;
  @override
  State<_CardAccent> createState() => _CardAccentState();
}
class _CardAccentState extends State<_CardAccent> with SingleTickerProviderStateMixin {
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
                Container(
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
                      child: _avatar(widget.data, r: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Willkommen,', style: TextStyle(color: Colors.white.withOpacity(.4), fontSize: 12)),
                      Text(widget.data.username, style: GoogleFonts.rajdhani(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                      const SizedBox(height: 6),
                      _statsRow(widget.data),
                    ])),
                    _diceButton(widget.data, iconColor: Colors.white, iconOpacity: .3),
                  ]),
                )),
              ]),
            ),
          );
        },
      );
}

// ─── GLAS MIT SHIMMER ─────────────────────────────────────
class _CardGlass extends StatefulWidget {
  const _CardGlass({required this.data});
  final ProfileCardData data;
  @override
  State<_CardGlass> createState() => _CardGlassState();
}
class _CardGlassState extends State<_CardGlass> with SingleTickerProviderStateMixin {
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
                  child: _avatar(widget.data),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Willkommen,', style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 13)),
                  Text(widget.data.username, style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  _statsRow(widget.data),
                ])),
                _diceButton(widget.data, iconColor: Colors.white, iconOpacity: .5),
              ]),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _ShimmerPainter(_ctrl.value))),
            ),
          ),
        ),
      ]);
}

// ─── NEON RAND ────────────────────────────────────────────
class _CardNeon extends StatefulWidget {
  const _CardNeon({required this.data});
  final ProfileCardData data;
  @override
  State<_CardNeon> createState() => _CardNeonState();
}
class _CardNeonState extends State<_CardNeon> with SingleTickerProviderStateMixin {
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
              child: _avatar(widget.data, bg: const Color(0xFF2A0000)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Willkommen,', style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 13)),
              Text(widget.data.username, style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
              const SizedBox(height: 8),
              _statsRow(widget.data),
            ])),
            _diceButton(widget.data, iconColor: const Color(0xFFEF5350), iconOpacity: 1),
          ]),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(painter: _NeonBorderPainter(progress: _ctrl.value, color: const Color(0xFFEF5350), radius: 20)),
            ),
          ),
        ),
      ]);
}

// ─── STECKBRIEF ───────────────────────────────────────────
class _CardWanted extends StatelessWidget {
  const _CardWanted({required this.data});
  final ProfileCardData data;
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
                Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD4B483),
                    border: Border.all(color: const Color(0xFF7A4A10), width: 3),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 8)],
                  ),
                  child: ClipOval(child: _avatar(data, r: 35)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data.username.toUpperCase(), style: GoogleFonts.rajdhani(fontSize: 17, fontWeight: FontWeight.w900, color: const Color(0xFF3E1A00), letterSpacing: 1.5)),
                  const SizedBox(height: 5),
                  Row(children: [
                    _WantedStat('KILLS', '${data.kills}'), const SizedBox(width: 16),
                    _WantedStat('SIEGE', '${data.wins}'), const SizedBox(width: 16),
                    _WantedStat('SPIELE', '${data.games}'),
                    const Spacer(),
                    GestureDetector(onTap: data.onDiceTap, child: Icon(Icons.casino_rounded, color: const Color(0xFF7A4A10).withOpacity(.55), size: 20)),
                  ]),
                ])),
              ]),
            ),
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

// ─── AGENT 007 ────────────────────────────────────────────
class _CardBond extends StatelessWidget {
  const _CardBond({required this.data});
  final ProfileCardData data;
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
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0A1020),
                    border: Border.all(color: const Color(0xFFD4AF37).withOpacity(.65), width: 2),
                    boxShadow: [BoxShadow(color: const Color(0xFFD4AF37).withOpacity(.18), blurRadius: 10)],
                  ),
                  child: ClipOval(child: _avatar(data, r: 32)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _DossierField('AGENT', data.username.toUpperCase(), valueColor: const Color(0xFFD4AF37)),
                  const SizedBox(height: 5),
                  const _DossierField('CLEARANCE', 'LEVEL 7 — ACTIVE'),
                ])),
              ]),
              const SizedBox(height: 14),
              Row(children: List.generate(28, (i) => Expanded(child: Container(height: 1, color: const Color(0xFFD4AF37).withOpacity(i.isEven ? .4 : .1))))),
              const SizedBox(height: 10),
              Row(children: [
                _GoldStat('KILLS', '${data.kills}'), const SizedBox(width: 22),
                _GoldStat('WINS', '${data.wins}'), const SizedBox(width: 22),
                _GoldStat('SPIELE', '${data.games}'),
                const Spacer(),
                GestureDetector(onTap: data.onDiceTap, child: Icon(Icons.casino_rounded, color: const Color(0xFFD4AF37).withOpacity(.5), size: 20)),
              ]),
            ]),
          ),
        ]),
      );
}

class _DossierField extends StatelessWidget {
  const _DossierField(this.label, this.value, {this.valueColor});
  final String label, value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: const Color(0xFFD4AF37).withOpacity(.5), fontSize: 8, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
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

// ─── FUNKEN ───────────────────────────────────────────────
class _CardSparks extends StatefulWidget {
  const _CardSparks({required this.data});
  final ProfileCardData data;
  @override
  State<_CardSparks> createState() => _CardSparksState();
}
class _CardSparksState extends State<_CardSparks> with SingleTickerProviderStateMixin {
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
          Positioned.fill(child: AnimatedBuilder(animation: _ctrl, builder: (_, __) => CustomPaint(painter: _SparksPainter(_ctrl.value)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [Color(0xFFB71C1C), Color(0xFFFF6F00), Color(0xFFFFB300), Color(0xFFB71C1C)])),
                child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1E1E1E)), child: _avatar(widget.data, r: 40)),
              ),
              const SizedBox(height: 10),
              Text(widget.data.username, style: GoogleFonts.rajdhani(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              Text('Willkommen zurück', style: TextStyle(color: Colors.white.withOpacity(.45), fontSize: 12)),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _BigStat('🗡️', '${widget.data.kills}', 'Kills', const Color(0xFFEF5350)),
                Container(width: 1, height: 34, color: Colors.white.withOpacity(.1)),
                _BigStat('🏆', '${widget.data.wins}', 'Wins', const Color(0xFFFFB300)),
                Container(width: 1, height: 34, color: Colors.white.withOpacity(.1)),
                _BigStat('🎮', '${widget.data.games}', 'Spiele', Colors.white60),
              ]),
            ]),
          ),
          Positioned(bottom: 10, right: 14,
            child: GestureDetector(onTap: widget.data.onDiceTap, child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.casino_rounded, color: Colors.white.withOpacity(.55), size: 22),
              const SizedBox(height: 2),
              Text('WÜRFELN', style: TextStyle(color: Colors.white.withOpacity(.35), fontSize: 7, fontWeight: FontWeight.w700, letterSpacing: .7)),
            ]))),
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

// ═══════════════════════════════════════════════════════════
// PAINTERS (Card)
// ═══════════════════════════════════════════════════════════

class _ShimmerPainter extends CustomPainter {
  final double t;
  const _ShimmerPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final diag  = math.sqrt(size.width * size.width + size.height * size.height);
    final stripW = diag * .38;
    final x      = -diag * .5 + diag * 2.0 * t;
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
  final double progress; final Color color; final double radius;
  const _NeonBorderPainter({required this.progress, required this.color, required this.radius});
  @override
  void paint(Canvas canvas, Size size) {
    final path    = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius)));
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric  = metrics.first;
    final total   = metric.length;
    final segLen  = total * .22;
    final start   = progress * total;
    final end     = start + segLen;
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

class _SparksPainter extends CustomPainter {
  final double t;
  const _SparksPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
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
    for (int i = 0; i < 22; i++) {
      final baseX     = (i * 0.618033) % 1.0;
      final speedMult = 0.55 + (i * 0.137) % 0.85;
      final phase     = (t * speedMult + i * 0.0454) % 1.0;
      final x = size.width * (0.05 + 0.9 * baseX) + 10 * math.sin(t * math.pi * 2 * 1.3 + i * 1.1);
      final y = size.height * (1.02 - phase * 1.3);
      if (y < -8 || y > size.height + 6) continue;
      final alpha      = (1.0 - phase * 1.2).clamp(0.0, 1.0);
      final sz         = (2.4 - 1.5 * phase).clamp(0.4, 2.4);
      final sparkColor = Color.lerp(const Color(0xFFFF4500), const Color(0xFFFFFFCC), (phase * 0.9).clamp(0.0, 1.0))!;
      canvas.drawCircle(Offset(x, y), sz, Paint()..color = sparkColor.withOpacity(alpha * 0.88)..maskFilter = MaskFilter.blur(BlurStyle.normal, sz * 0.55));
      canvas.drawCircle(Offset(x, y), sz * 0.38, Paint()..color = Colors.white.withOpacity(alpha * 0.7));
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
      final phase   = (t * .45 + i * .18) % 1.0;
      final x       = size.width * _xBases[i] + 14 * math.sin(t * math.pi * 2 * .7 + i * 1.3);
      final y       = size.height * (1.05 - phase * 1.15);
      if (y < -30 || y > size.height + 10) continue;
      final opacity = math.max(0.0, .22 * (1 - phase * 1.4)).toDouble();
      final r       = size.width * .07 * (1 + phase * .9);
      canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withOpacity(opacity)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .65));
    }
  }
  @override
  bool shouldRepaint(_SmokePainter old) => old.t != t;
}

class _GunBarrelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final p  = Paint()..color = const Color(0xFFD4AF37).withOpacity(.14)..strokeWidth = 1..style = PaintingStyle.stroke;
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
