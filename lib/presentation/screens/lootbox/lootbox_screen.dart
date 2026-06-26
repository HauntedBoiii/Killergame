import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moerderspiel/core/models/loot_item.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';
import 'package:moerderspiel/presentation/providers/lootbox_provider.dart';
import 'package:moerderspiel/presentation/widgets/kniffel/dice_widget.dart';
import 'package:moerderspiel/presentation/widgets/profile_card/profile_card_widget.dart';

class LootboxScreen extends ConsumerStatefulWidget {
  const LootboxScreen({super.key});
  @override
  ConsumerState<LootboxScreen> createState() => _LootboxScreenState();
}

class _LootboxScreenState extends ConsumerState<LootboxScreen> with TickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lootAsync = ref.watch(lootStateProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('Sammlung', style: GoogleFonts.rajdhani(fontWeight: FontWeight.w700, fontSize: 20)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFFEF5350),
          labelColor: const Color(0xFFEF5350),
          unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(
              child: lootAsync.maybeWhen(
                data: (s) {
                  final count = s.readyBoxes.length;
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.inventory_2_outlined, size: 16),
                    const SizedBox(width: 6),
                    const Text('Lootboxen'),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      _Badge(count),
                    ],
                  ]);
                },
                orElse: () => const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.inventory_2_outlined, size: 16), SizedBox(width: 6), Text('Lootboxen')]),
              ),
            ),
            const Tab(icon: Icon(Icons.style_outlined, size: 16), text: 'Inventar'),
            const Tab(icon: Icon(Icons.toll_outlined, size: 16), text: 'Credits'),
          ],
        ),
      ),
      body: lootAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (state) => TabBarView(
          controller: _tab,
          children: [
            _LootboxTab(state: state),
            _InventarTab(state: state),
            _CreditsTab(state: state),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.count);
  final int count;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFEF5350), borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
      );
}

// ═══════════════════════════════════════════════════════════
// TAB 1: LOOTBOXEN
// ═══════════════════════════════════════════════════════════

class _LootboxTab extends ConsumerStatefulWidget {
  const _LootboxTab({required this.state});
  final LootState state;
  @override
  ConsumerState<_LootboxTab> createState() => _LootboxTabState();
}

class _LootboxTabState extends ConsumerState<_LootboxTab> with SingleTickerProviderStateMixin {
  late final AnimationController _slotCtrl;
  bool _animating  = false;
  bool _showResult = false;
  OpenResult? _result;
  List<Rarity> _reel = [];
  int _targetIndex   = 0;

  static const _tileCount   = 60;
  static const _targetSlot  = 44;
  static const _visibleTiles = 7;

  @override
  void initState() {
    super.initState();
    _slotCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  }

  @override
  void dispose() {
    _slotCtrl.dispose();
    super.dispose();
  }

  void _buildReel(Rarity result) {
    final rng  = math.Random();
    final pool = [
      ...List.filled(49, Rarity.bronze),
      ...List.filled(14, Rarity.silver),
      ...List.filled(7,  Rarity.gold),
      ...List.filled(1,  Rarity.diamond),
    ]..shuffle(rng);

    _reel = List<Rarity>.from(pool.take(_tileCount));
    _reel[_targetSlot] = result;
    _targetIndex = _targetSlot;
  }

  Future<void> _openBox(UserLootbox box) async {
    if (_animating) return;
    // Clear _reel so any old _SlotMachine is removed from tree before we start
    setState(() { _animating = true; _showResult = false; _result = null; _reel = []; });

    try {
      final result = await openLootbox(box.id, ref);
      if (!mounted) return;

      _buildReel(result.rarity);
      // Reset to 0 before putting _SlotMachine into tree, so it appears at start position
      _slotCtrl.reset();
      // Force rebuild: _SlotMachine enters tree with correct reel at ctrl.value = 0
      setState(() {});
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      await _slotCtrl.animateTo(1.0, curve: Curves.easeOutExpo);

      if (mounted) setState(() { _result = result; _showResult = true; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _animating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boxes = widget.state.lootboxes;
    final ready = widget.state.readyBoxes;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Slot-Maschine
        if (_reel.isNotEmpty) ...[
          _SlotMachine(ctrl: _slotCtrl, reel: _reel, targetIndex: _targetIndex, visibleTiles: _visibleTiles),
          const SizedBox(height: 16),
        ],

        // Ergebnis-Overlay
        if (_showResult && _result != null) _ResultCard(result: _result!, onDismiss: () => setState(() { _showResult = false; _reel = []; })),
        if (_showResult) const SizedBox(height: 16),

        // Lootbox-Karten
        if (boxes.isEmpty)
          _EmptyState()
        else
          ...boxes.map((box) => _LootboxCard(box: box, onOpen: ready.contains(box) && !_animating ? () => _openBox(box) : null)),
      ],
    );
  }
}

class _SlotMachine extends StatelessWidget {
  const _SlotMachine({required this.ctrl, required this.reel, required this.targetIndex, required this.visibleTiles});
  final AnimationController ctrl;
  final List<Rarity> reel;
  final int targetIndex, visibleTiles;

  @override
  Widget build(BuildContext context) {
    final tileW = (MediaQuery.of(context).size.width - 32) / visibleTiles;
    final centerOffset = (visibleTiles / 2).floor() * tileW;
    final targetX = targetIndex * tileW - centerOffset;

    return Column(children: [
      Text('CSGO CASE OPENING', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Container(
        height: 90,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(.08)),
        ),
        child: Stack(children: [
          // Reel: Positioned bei left=0 → exakte Pixelposition, kein Layout-Ambiguität
          AnimatedBuilder(
            animation: ctrl,
            builder: (_, __) => Positioned(
              left: -ctrl.value * targetX,
              top: 0,
              bottom: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: reel.map((r) => _ReelTile(rarity: r, width: tileW)).toList(),
              ),
            ),
          ),
          // Zentrum-Markierung
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: tileW - 8,
                  height: double.infinity,
                  child: Column(children: [
                    Container(height: 3, decoration: BoxDecoration(color: const Color(0xFFEF5350), borderRadius: BorderRadius.circular(2), boxShadow: [BoxShadow(color: const Color(0xFFEF5350).withValues(alpha: .6), blurRadius: 8)])),
                    const Spacer(),
                    Container(height: 3, decoration: BoxDecoration(color: const Color(0xFFEF5350), borderRadius: BorderRadius.circular(2), boxShadow: [BoxShadow(color: const Color(0xFFEF5350).withValues(alpha: .6), blurRadius: 8)])),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _ReelTile extends StatelessWidget {
  const _ReelTile({required this.rarity, required this.width});
  final Rarity rarity; final double width;

  @override
  Widget build(BuildContext context) {
    final Color bg = switch (rarity) {
      Rarity.bronze  => const Color(0xFF2A1A00),
      Rarity.silver  => const Color(0xFF1A1A2A),
      Rarity.gold    => const Color(0xFF2A2000),
      Rarity.diamond => const Color(0xFF040C1E),
    };
    return Container(
      width: width,
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: rarity.color.withOpacity(.5), width: 1.5),
        boxShadow: [BoxShadow(color: rarity.color.withOpacity(.15), blurRadius: 8)],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(_rarityIcon(rarity), style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(rarity.label.toUpperCase(), style: TextStyle(color: rarity.color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ]),
    );
  }

  String _rarityIcon(Rarity r) => switch (r) {
    Rarity.bronze  => '🥉',
    Rarity.silver  => '🥈',
    Rarity.gold    => '🥇',
    Rarity.diamond => '💎',
  };
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onDismiss});
  final OpenResult result; final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = result.rarity.color;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.6), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(.2), blurRadius: 20)],
      ),
      child: Column(children: [
        Row(children: [
          Text(_rarityIcon(result.rarity), style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(result.isCredit ? '${result.rarity.label}-Credit erhalten!' : result.item!.name,
              style: GoogleFonts.rajdhani(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            Text(
              result.isCredit
                  ? 'Du besitzt bereits alle ${result.rarity.label}-Items'
                  : '${result.rarity.label} · ${result.item!.itemType == 'card' ? 'Profilkarte' : 'Würfel'}',
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ])),
          IconButton(icon: const Icon(Icons.close, color: Colors.white38), onPressed: onDismiss),
        ]),
      ]),
    );
  }

  String _rarityIcon(Rarity r) => switch (r) {
    Rarity.bronze  => '🥉',
    Rarity.silver  => '🥈',
    Rarity.gold    => '🥇',
    Rarity.diamond => '💎',
  };
}

class _LootboxCard extends StatelessWidget {
  const _LootboxCard({required this.box, required this.onOpen});
  final UserLootbox box; final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final ready = box.isReady;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ready ? const Color(0xFFEF5350).withOpacity(.4) : Colors.white.withOpacity(.06)),
      ),
      child: Row(children: [
        Text(box.source == 'kniffel' ? '🎲' : '🗡️', style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${box.sourceLabel}-Lootbox', style: GoogleFonts.rajdhani(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(
            ready ? 'Bereit zum Öffnen' : 'Verfügbar ab ${_formatDate(box.availableAt)}',
            style: TextStyle(color: ready ? const Color(0xFF4CAF50) : Colors.white38, fontSize: 12),
          ),
        ])),
        if (onOpen != null)
          ElevatedButton(
            onPressed: onOpen,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF5350), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Öffnen'),
          )
        else if (!ready)
          const Icon(Icons.lock_clock, color: Colors.white38),
      ]),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(children: [
            const Text('📦', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text('Keine Lootboxen', style: GoogleFonts.rajdhani(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white70)),
            const SizedBox(height: 8),
            const Text('Gewinne ein Mörderspiel (≥8 Spieler)\noder den täglichen Kniffel-Wettbewerb!',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 13)),
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
// TAB 2: INVENTAR
// ═══════════════════════════════════════════════════════════

class _InventarTab extends ConsumerWidget {
  const _InventarTab({required this.state});
  final LootState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.value;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Aktive Vorschau
        Text('AKTIVES DESIGN', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        IgnorePointer(
          child: ProfileCardWidget(
            design: state.activeCardDesign,
            data: ProfileCardData(
              username:  profile?.username ?? 'Spieler',
              avatarUrl: profile?.avatarUrl,
              userId:    profile?.id,
              kills:     profile?.totalKills  ?? 0,
              wins:      profile?.totalWins   ?? 0,
              games:     profile?.totalGames  ?? 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [1, 2, 3, 4, 5].map((v) =>
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: DiceWidget(value: v, design: state.activeDiceDesign, size: 44))
        ).toList()),
        const SizedBox(height: 24),

        // Karten-Designs
        Text('PROFILKARTEN', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _CardSection(state: state, profile: profile),
        const SizedBox(height: 24),

        // Würfel-Designs
        Text('WÜRFEL', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _DiceSection(state: state),
      ],
    );
  }
}

class _CardSection extends ConsumerWidget {
  const _CardSection({required this.state, required this.profile});
  final LootState state;
  final dynamic profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = state.cardItems;
    final allDesigns = [
      _DesignEntry(CardDesign.current, null, 'Standard',  Rarity.bronze, true),
      ...cards.map((item) => _DesignEntry(CardDesign.fromKey(item.designKey), item.id, item.name, item.rarity, true)),
    ];

    return Column(
      children: allDesigns.map((entry) {
        final isActive = state.activeCardDesign == entry.design;
        return _CardDesignRow(
          entry: entry,
          isActive: isActive,
          data: ProfileCardData(
            username:  profile?.username  ?? 'Spieler',
            avatarUrl: profile?.avatarUrl,
            userId:    profile?.id,
            kills:     profile?.totalKills  ?? 0,
            wins:      profile?.totalWins   ?? 0,
            games:     profile?.totalGames  ?? 0,
          ),
          onSelect: () => setActiveDesign(isActive ? null : entry.itemId, 'card', ref),
        );
      }).toList(),
    );
  }
}

class _CardDesignRow extends StatelessWidget {
  const _CardDesignRow({required this.entry, required this.isActive, required this.data, required this.onSelect});
  final _DesignEntry entry; final bool isActive; final ProfileCardData data; final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onSelect,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _RarityBadge(entry.rarity),
            const SizedBox(width: 8),
            Text(entry.name, style: GoogleFonts.rajdhani(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            const Spacer(),
            _SelectButton(isActive: isActive, onTap: onSelect),
          ]),
          const SizedBox(height: 8),
          IgnorePointer(child: ProfileCardWidget(design: entry.design, data: data)),
          const SizedBox(height: 16),
        ]),
      );
}

class _DiceSection extends ConsumerWidget {
  const _DiceSection({required this.state});
  final LootState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dices = state.diceItems;
    final allDesigns = [
      _DesignEntry(DiceDesign.current, null, 'Standard', Rarity.bronze, true),
      ...dices.map((item) => _DesignEntry(DiceDesign.fromKey(item.designKey), item.id, item.name, item.rarity, true)),
    ];
    const vals = [2, 4, 5, 1, 6];

    return Column(
      children: allDesigns.map((entry) {
        final design   = entry.design as DiceDesign;
        final isActive = state.activeDiceDesign == design;
        return GestureDetector(
          onTap: () => setActiveDesign(isActive ? null : entry.itemId, 'dice', ref),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _RarityBadge(entry.rarity),
              const SizedBox(width: 8),
              Text(entry.name, style: GoogleFonts.rajdhani(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              _SelectButton(isActive: isActive, onTap: () => setActiveDesign(isActive ? null : entry.itemId, 'dice', ref)),
            ]),
            const SizedBox(height: 8),
            IgnorePointer(child: Row(children: vals.map((v) => Padding(padding: const EdgeInsets.only(right: 8), child: DiceWidget(value: v, design: design, size: 50))).toList())),
            const SizedBox(height: 16),
          ]),
        );
      }).toList(),
    );
  }
}

class _DesignEntry {
  final dynamic design;
  final String? itemId;
  final String name;
  final Rarity rarity;
  final bool owned;
  const _DesignEntry(this.design, this.itemId, this.name, this.rarity, this.owned);
}

class _RarityBadge extends StatelessWidget {
  const _RarityBadge(this.rarity);
  final Rarity rarity;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: rarity.color.withOpacity(.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: rarity.color.withOpacity(.4))),
        child: Text(rarity.label.toUpperCase(), style: TextStyle(color: rarity.color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
      );
}

class _SelectButton extends StatelessWidget {
  const _SelectButton({required this.isActive, required this.onTap});
  final bool isActive; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEF5350) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isActive ? const Color(0xFFEF5350) : Colors.white38),
          ),
          child: Text(isActive ? 'Aktiv' : 'Wählen', style: TextStyle(color: isActive ? Colors.white : Colors.white60, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      );
}

// ═══════════════════════════════════════════════════════════
// TAB 3: CREDITS
// ═══════════════════════════════════════════════════════════

class _CreditsTab extends ConsumerWidget {
  const _CreditsTab({required this.state});
  final LootState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credits = state.credits;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('DEINE CREDITS', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _CreditCard(rarity: Rarity.bronze, count: credits.bronze)),
          const SizedBox(width: 10),
          Expanded(child: _CreditCard(rarity: Rarity.silver, count: credits.silver)),
          const SizedBox(width: 10),
          Expanded(child: _CreditCard(rarity: Rarity.gold,   count: credits.gold)),
        ]),
        const SizedBox(height: 28),

        Text('HANDELN', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        _TradeRow(
          label: '2× Bronze → 1× Silber',
          from: Rarity.bronze, to: Rarity.silver,
          canAfford: credits.bronze >= 2,
          onTap: () => _trade(context, ref, 'bronze', 'up'),
        ),
        _TradeRow(
          label: '2× Silber → 1× Gold',
          from: Rarity.silver, to: Rarity.gold,
          canAfford: credits.silver >= 2,
          onTap: () => _trade(context, ref, 'silver', 'up'),
        ),
        _TradeRow(
          label: '1× Gold → 2× Silber',
          from: Rarity.gold, to: Rarity.silver,
          canAfford: credits.gold >= 1,
          onTap: () => _trade(context, ref, 'gold', 'down'),
        ),
        _TradeRow(
          label: '1× Silber → 2× Bronze',
          from: Rarity.silver, to: Rarity.bronze,
          canAfford: credits.silver >= 1,
          onTap: () => _trade(context, ref, 'silver', 'down'),
        ),

        const SizedBox(height: 28),
        Text('CREDIT EINLÖSEN', style: GoogleFonts.rajdhani(color: Colors.white38, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Schalte ein zufälliges Item der gewählten Seltenheit frei.', style: TextStyle(color: Colors.white38, fontSize: 12)),
        const SizedBox(height: 12),

        for (final r in Rarity.values.where((r) => r != Rarity.diamond))
          _SpendRow(
            rarity: r,
            count: credits[r],
            hasUnowned: _hasUnowned(r),
            onSpend: () => _spend(context, ref, r),
          ),
      ],
    );
  }

  bool _hasUnowned(Rarity r) {
    const total = {Rarity.bronze: 9, Rarity.silver: 3, Rarity.gold: 2};
    final owned = state.cardItems.where((i) => i.rarity == r).length
                + state.diceItems.where((i) => i.rarity == r).length;
    return owned < (total[r] ?? 0);
  }

  Future<void> _trade(BuildContext context, WidgetRef ref, String rarity, String dir) async {
    try {
      await tradeCredits(rarity, dir, ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _spend(BuildContext context, WidgetRef ref, Rarity rarity) async {
    try {
      final item = await spendCredits(rarity.key, ref);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${item.name} freigeschaltet!'),
          backgroundColor: rarity.color.withOpacity(.8),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
      }
    }
  }
}

class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.rarity, required this.count});
  final Rarity rarity; final int count;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: rarity.color.withOpacity(.35), width: 1.5),
          boxShadow: count > 0 ? [BoxShadow(color: rarity.color.withOpacity(.12), blurRadius: 12)] : [],
        ),
        child: Column(children: [
          Text(_rarityIcon(rarity), style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text('$count', style: TextStyle(color: rarity.color, fontSize: 28, fontWeight: FontWeight.w900, height: 1)),
          Text(rarity.label, style: TextStyle(color: rarity.color.withOpacity(.7), fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );

  String _rarityIcon(Rarity r) => switch (r) {
    Rarity.bronze  => '🥉',
    Rarity.silver  => '🥈',
    Rarity.gold    => '🥇',
    Rarity.diamond => '💎',
  };
}

class _TradeRow extends StatelessWidget {
  const _TradeRow({required this.label, required this.from, required this.to, required this.canAfford, required this.onTap});
  final String label; final Rarity from, to; final bool canAfford; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: canAfford ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: Opacity(
              opacity: canAfford ? 1.0 : 0.4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  Text(_rarityIcon(from), style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, color: Colors.white38, size: 16),
                  const SizedBox(width: 6),
                  Text(_rarityIcon(to), style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                  Icon(Icons.swap_horiz_rounded, color: canAfford ? const Color(0xFFEF5350) : Colors.white24, size: 20),
                ]),
              ),
            ),
          ),
        ),
      );

  String _rarityIcon(Rarity r) => switch (r) {
    Rarity.bronze  => '🥉',
    Rarity.silver  => '🥈',
    Rarity.gold    => '🥇',
    Rarity.diamond => '💎',
  };
}

class _SpendRow extends StatelessWidget {
  const _SpendRow({required this.rarity, required this.count, required this.hasUnowned, required this.onSpend});
  final Rarity rarity; final int count; final bool hasUnowned; final VoidCallback onSpend;
  @override
  Widget build(BuildContext context) {
    final canSpend = count > 0 && hasUnowned;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rarity.color.withOpacity(.25)),
      ),
      child: Row(children: [
        Text(_icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${rarity.label}-Item freischalten', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          Text(
            hasUnowned ? '$count Credit${count != 1 ? 's' : ''} verfügbar' : 'Alle Items bereits freigeschaltet',
            style: TextStyle(color: hasUnowned ? rarity.color.withValues(alpha: .7) : Colors.white38, fontSize: 11),
          ),
        ])),
        ElevatedButton(
          onPressed: canSpend ? onSpend : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: rarity.color,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: Text('Einlösen', style: TextStyle(color: canSpend ? Colors.black : Colors.white24, fontWeight: FontWeight.w800, fontSize: 12)),
        ),
      ]),
    );
  }

  String get _icon => switch (rarity) {
    Rarity.bronze  => '🥉',
    Rarity.silver  => '🥈',
    Rarity.gold    => '🥇',
    Rarity.diamond => '💎',
  };
}
