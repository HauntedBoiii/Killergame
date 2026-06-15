import 'package:flutter/material.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/data/models/elimination.dart';
import 'package:moerderspiel/presentation/widgets/common/avatar_widget.dart';

class KillHistoryItem extends StatelessWidget {
  final Elimination elimination;
  final String currentUserId;

  const KillHistoryItem({
    super.key,
    required this.elimination,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = elimination.killerId == currentUserId;
    final killerName = elimination.killerProfile?.username ?? 'Unbekannt';
    final victimName = elimination.victimProfile?.username ?? 'Unbekannt';

    Color statusColor;
    IconData statusIcon;
    switch (elimination.status) {
      case EliminationStatus.confirmed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case EliminationStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: isMe
            ? Border.all(color: theme.colorScheme.primary.withOpacity(0.5))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(
                imageUrl: elimination.killerProfile?.avatarUrl,
                name: killerName,
                radius: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      TextSpan(
                        text: killerName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: '  🗡️  '),
                      TextSpan(
                        text: victimName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              Icon(statusIcon, color: statusColor, size: 18),
            ],
          ),
          if (elimination.task != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '📋 ${elimination.task!.description}',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            timeAgo(elimination.createdAt),
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
