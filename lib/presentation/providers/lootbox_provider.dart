import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moerderspiel/core/models/loot_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _client = Supabase.instance.client;

// ── Hauptzustand ──────────────────────────────────────────

final lootStateProvider = FutureProvider<LootState>((ref) async {
  final raw = await _client.rpc('get_loot_state');
  return LootState.fromJson(raw as Map<String, dynamic>);
});

// ── Mutations (als einfache Funktionen, kein Notifier nötig) ─

Future<OpenResult> openLootbox(String lootboxId, WidgetRef ref) async {
  final raw = await _client.rpc('open_lootbox', params: {'p_lootbox_id': lootboxId});
  final result = OpenResult.fromJson(raw as Map<String, dynamic>);
  ref.invalidate(lootStateProvider);
  return result;
}

Future<void> setActiveDesign(String? itemId, String type, WidgetRef ref) async {
  await _client.rpc('set_active_design', params: {
    'p_item_id': itemId,
    'p_type':    type,
  });
  ref.invalidate(lootStateProvider);
}

Future<void> tradeCredits(String rarity, String direction, WidgetRef ref) async {
  await _client.rpc('trade_credits', params: {
    'p_rarity':    rarity,
    'p_direction': direction,
  });
  ref.invalidate(lootStateProvider);
}

Future<LootItem> spendCredits(String rarity, WidgetRef ref) async {
  final raw = await _client.rpc('spend_credits', params: {'p_rarity': rarity});
  final json = (raw as Map<String, dynamic>)['item'] as Map<String, dynamic>;
  ref.invalidate(lootStateProvider);
  return LootItem(
    id:        json['item_id'] as String,
    itemType:  json['item_type'] as String,
    designKey: json['design_key'] as String,
    name:      json['name'] as String,
    rarity:    Rarity.fromKey(json['rarity'] as String),
  );
}
