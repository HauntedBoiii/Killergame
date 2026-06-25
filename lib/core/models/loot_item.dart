import 'package:flutter/material.dart';

// ── Enums ─────────────────────────────────────────────────

enum CardDesign {
  current(''),
  smoke('smoke'),
  accent('accent'),
  glass('glass'),
  neon('neon'),
  wanted('wanted'),
  bond('bond'),
  sparks('sparks');

  const CardDesign(this.key);
  final String key;

  static CardDesign fromKey(String? key) {
    if (key == null || key.isEmpty) return CardDesign.current;
    return CardDesign.values.firstWhere((d) => d.key == key, orElse: () => CardDesign.current);
  }
}

enum DiceDesign {
  current(''),
  wood('wood'),
  neon('neon'),
  vegas('vegas'),
  blood('blood'),
  appRed('app_red'),
  digital('digital'),
  crystal('crystal');

  const DiceDesign(this.key);
  final String key;

  static DiceDesign fromKey(String? key) {
    if (key == null || key.isEmpty) return DiceDesign.current;
    return DiceDesign.values.firstWhere((d) => d.key == key, orElse: () => DiceDesign.current);
  }
}

enum Rarity {
  bronze('bronze', Color(0xFFCD7F32)),
  silver('silver', Color(0xFFC0C0C0)),
  gold('gold',   Color(0xFFFFD700));

  const Rarity(this.key, this.color);
  final String key;
  final Color color;

  String get label => switch (this) {
    Rarity.bronze => 'Bronze',
    Rarity.silver => 'Silber',
    Rarity.gold   => 'Gold',
  };

  static Rarity fromKey(String key) =>
      Rarity.values.firstWhere((r) => r.key == key, orElse: () => Rarity.bronze);
}

// ── Models ────────────────────────────────────────────────

class LootItem {
  final String id;
  final String itemType;
  final String designKey;
  final String name;
  final Rarity rarity;
  final DateTime? unlockedAt;

  const LootItem({
    required this.id,
    required this.itemType,
    required this.designKey,
    required this.name,
    required this.rarity,
    this.unlockedAt,
  });

  factory LootItem.fromJson(Map<String, dynamic> json) => LootItem(
        id:         json['item_id'] as String,
        itemType:   json['item_type'] as String,
        designKey:  json['design_key'] as String,
        name:       json['name'] as String,
        rarity:     Rarity.fromKey(json['rarity'] as String),
        unlockedAt: json['unlocked_at'] != null
            ? DateTime.parse(json['unlocked_at'] as String)
            : null,
      );
}

class UserLootbox {
  final String id;
  final String source;
  final String status;
  final DateTime availableAt;
  final DateTime createdAt;

  const UserLootbox({
    required this.id,
    required this.source,
    required this.status,
    required this.availableAt,
    required this.createdAt,
  });

  bool get isReady => status == 'ready' && !DateTime.now().isBefore(availableAt);

  String get sourceLabel => source == 'kniffel' ? 'Kniffel' : 'Mörderspiel';

  factory UserLootbox.fromJson(Map<String, dynamic> json) => UserLootbox(
        id:          json['id'] as String,
        source:      json['source'] as String,
        status:      json['status'] as String,
        availableAt: DateTime.parse(json['available_at'] as String),
        createdAt:   DateTime.parse(json['created_at'] as String),
      );
}

class UserCredits {
  final int bronze;
  final int silver;
  final int gold;

  const UserCredits({required this.bronze, required this.silver, required this.gold});

  factory UserCredits.fromJson(Map<String, dynamic> json) => UserCredits(
        bronze: (json['bronze'] as num?)?.toInt() ?? 0,
        silver: (json['silver'] as num?)?.toInt() ?? 0,
        gold:   (json['gold']   as num?)?.toInt() ?? 0,
      );

  int operator [](Rarity r) => switch (r) {
    Rarity.bronze => bronze,
    Rarity.silver => silver,
    Rarity.gold   => gold,
  };
}

class LootState {
  final List<UserLootbox> lootboxes;
  final List<LootItem>    inventory;
  final UserCredits       credits;
  final CardDesign        activeCardDesign;
  final DiceDesign        activeDiceDesign;

  const LootState({
    required this.lootboxes,
    required this.inventory,
    required this.credits,
    required this.activeCardDesign,
    required this.activeDiceDesign,
  });

  List<UserLootbox> get readyBoxes => lootboxes.where((b) => b.isReady).toList();

  List<LootItem> get cardItems => inventory.where((i) => i.itemType == 'card').toList();
  List<LootItem> get diceItems => inventory.where((i) => i.itemType == 'dice').toList();

  factory LootState.fromJson(Map<String, dynamic> json) => LootState(
        lootboxes: (json['lootboxes'] as List<dynamic>? ?? [])
            .map((e) => UserLootbox.fromJson(e as Map<String, dynamic>))
            .toList(),
        inventory: (json['inventory'] as List<dynamic>? ?? [])
            .map((e) => LootItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        credits:         UserCredits.fromJson(json['credits'] as Map<String, dynamic>? ?? {}),
        activeCardDesign: CardDesign.fromKey(json['active_card_key'] as String?),
        activeDiceDesign: DiceDesign.fromKey(json['active_dice_key'] as String?),
      );
}

// ── Lootbox-Opening Result ────────────────────────────────

class OpenResult {
  final bool isCredit;
  final Rarity rarity;
  final LootItem? item;

  const OpenResult({required this.isCredit, required this.rarity, this.item});

  factory OpenResult.fromJson(Map<String, dynamic> json) {
    final rarity = Rarity.fromKey(json['rarity'] as String);
    final isCredit = json['type'] == 'credit';
    LootItem? item;
    if (!isCredit && json['item'] != null) {
      final raw = json['item'] as Map<String, dynamic>;
      item = LootItem(
        id:        raw['item_id'] as String,
        itemType:  raw['item_type'] as String,
        designKey: raw['design_key'] as String,
        name:      raw['name'] as String,
        rarity:    Rarity.fromKey(raw['rarity'] as String),
      );
    }
    return OpenResult(isCredit: isCredit, rarity: rarity, item: item);
  }
}
