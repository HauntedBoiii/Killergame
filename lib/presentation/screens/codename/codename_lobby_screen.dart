import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/data/models/codename_session.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';
import 'package:moerderspiel/presentation/providers/codename_provider.dart';
import 'package:moerderspiel/presentation/providers/rps_tournament_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/app_button.dart';
import 'package:moerderspiel/presentation/widgets/common/avatar_widget.dart';

class CodenameLobbyScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const CodenameLobbyScreen({super.key, required this.sessionId});

  @override
  ConsumerState<CodenameLobbyScreen> createState() => _CodenameLobbyScreenState();
}

class _CodenameLobbyScreenState extends ConsumerState<CodenameLobbyScreen> {
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    // Navigate to game screen when session becomes active
    ref.listenManual(
      codenameSessionStreamProvider(widget.sessionId),
      (_, next) {
        if (next.value?.isActive == true && mounted) {
          context.pushReplacement('/codename/${widget.sessionId}');
        }
      },
    );
  }

  Future<void> _startGame(CodenameSession session) async {
    setState(() => _starting = true);
    try {
      await ref.read(codenameRepositoryProvider).startSession(session.id);
    } catch (e) {
      if (mounted) showSnack(context, 'Fehler: $e', isError: true);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _leaveSession(CodenameSession session) async {
    try {
      await ref.read(codenameRepositoryProvider).leaveSession(session.id);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) showSnack(context, 'Fehler: $e', isError: true);
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    showSnack(context, 'Code kopiert!');
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(codenameSessionStreamProvider(widget.sessionId));
    final playersAsync = ref.watch(codenamePlayersStreamProvider(widget.sessionId));
    final userId       = ref.watch(currentUserIdProvider);
    final theme        = Theme.of(context);

    return sessionAsync.when(
      data: (session) {
        final players  = playersAsync.value ?? [];
        final isHost   = session.hostId == userId;
        final canStart = isHost && players.length >= 3;
        final category = _categoryLabel(session.wordCategory);

        return Scaffold(
          appBar: AppBar(
            title: Text(session.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _copyCode(session.code),
                tooltip: 'Code teilen',
              ),
            ],
          ),
          body: Column(
            children: [
              // ── Code-Banner ────────────────────────────────
              GestureDetector(
                onTap: () => _copyCode(session.code),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.18),
                      theme.colorScheme.primary.withValues(alpha: 0.06),
                    ]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Beitrittscode',
                                style: TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(
                              session.code,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Icon(Icons.copy, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(height: 6),
                          Text(
                            '${players.length} Spieler',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(),

              // ── Kategorie-Info ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.label_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('Kategorie: $category',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const Spacer(),
                    if (players.length < 3)
                      Text(
                        '${3 - players.length} Spieler fehlen noch',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      const Text(
                        'Bereit zum Starten!',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ).animate().fadeIn(delay: 50.ms),

              // ── Spielerliste ───────────────────────────────
              Expanded(
                child: playersAsync.when(
                  data: (players) => ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    itemCount: players.length,
                    itemBuilder: (_, i) {
                      final p = players[i];
                      final isMe = p.playerId == userId;
                      return _PlayerTile(
                        player: p,
                        isMe: isMe,
                        isHost: p.playerId == session.hostId,
                      ).animate(delay: Duration(milliseconds: 80 + i * 40))
                          .fadeIn()
                          .slideX(begin: -0.08);
                    },
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('Fehler: $e', style: const TextStyle(color: Colors.red))),
                ),
              ),

              // ── Aktionen ───────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    if (isHost)
                      AppButton(
                        label: 'Spiel starten',
                        onPressed: canStart ? () => _startGame(session) : null,
                        isLoading: _starting,
                        icon: Icons.play_arrow_rounded,
                      ),
                    const SizedBox(height: 8),
                    AppButton(
                      label: 'Verlassen',
                      onPressed: () => _leaveSession(session),
                      outlined: true,
                      color: Colors.red,
                      icon: Icons.exit_to_app,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Fehler: $e'))),
    );
  }

  String _categoryLabel(String cat) => switch (cat) {
        'agenten'   => 'Agenten',
        'orte'      => 'Orte',
        'objekte'   => 'Objekte',
        'essen'     => 'Essen',
        'tiere'     => 'Tiere',
        'alltag'    => 'Alltag',
        'konzepte'  => 'Konzepte',
        'popkultur' => 'Popkultur',
        'laender'   => 'Länder',
        _           => 'Alle Kategorien',
      };
}

// ── Player Tile ────────────────────────────────────────────

class _PlayerTile extends ConsumerWidget {
  final CodenamePlayer player;
  final bool isMe;
  final bool isHost;
  const _PlayerTile({required this.player, required this.isMe, required this.isHost});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme       = Theme.of(context);
    final username    = ref.watch(usernameByIdProvider(player.playerId)).value
        ?? player.playerId.substring(0, 8);
    final avatarUrl   = ref.watch(avatarUrlByIdProvider(player.playerId)).value;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: isMe
            ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          KniffelAwareAvatarWidget(
            imageUrl: avatarUrl,
            name: username,
            radius: 17,
            userId: player.playerId,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              username,
              style: TextStyle(
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          if (isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('HOST',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey)),
            ),
          if (isMe) ...[
            const SizedBox(width: 6),
            Text('(Du)',
                style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
