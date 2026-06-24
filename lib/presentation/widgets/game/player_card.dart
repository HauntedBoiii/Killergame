import 'package:flutter/material.dart';
import 'package:moerderspiel/data/models/game_player.dart';
import 'package:moerderspiel/presentation/widgets/common/avatar_widget.dart';

class PlayerCard extends StatelessWidget {
  final GamePlayer player;
  final bool isMe;
  final bool isTarget;
  final VoidCallback? onRemove;

  const PlayerCard({
    super.key,
    required this.player,
    this.isMe = false,
    this.isTarget = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDead = !player.isAlive;

    // Border and glow colors
    final Color accentColor = isTarget
        ? theme.colorScheme.primary
        : isMe
            ? const Color(0xFF2979FF)
            : Colors.transparent;

    final bool hasAccent = isTarget || isMe;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: hasAccent
            ? LinearGradient(
                colors: [
                  accentColor.withValues(alpha: 0.18),
                  accentColor.withValues(alpha: 0.04),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: hasAccent ? null : theme.cardTheme.color,
        border: Border.all(
          color: hasAccent ? accentColor.withValues(alpha: 0.7) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: hasAccent
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: KniffelAwareAvatarWidget(
          imageUrl: player.avatarUrl,
          name: player.displayName,
          isAlive: player.isAlive,
          radius: 24,
          userId: player.playerId,
        ),
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(
              player.displayName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: isDead ? Colors.grey : null,
                decoration: isDead ? TextDecoration.lineThrough : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (player.isAdmin) _Badge('Admin', theme.colorScheme.primary),
            if (isMe) _Badge('Du', const Color(0xFF2979FF)),
            if (isTarget) _Badge('🎯 Ziel', theme.colorScheme.primary),
          ],
        ),
        subtitle: Row(
          children: [
            if (player.kills > 0) ...[
              const Text('🗡️', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 2),
              Text('${player.kills}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const Text(' Kills  ', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            if (isDead)
              const Text('☠️ Eliminiert', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (player.isReady && player.isAlive)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.green, size: 16),
              ),
            if (!player.isReady && player.isAlive)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_empty, color: Colors.orange, size: 16),
              ),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                onPressed: onRemove,
                tooltip: 'Entfernen',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
