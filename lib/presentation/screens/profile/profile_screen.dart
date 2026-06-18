import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moerderspiel/core/services/push_notification_service.dart';
import 'package:moerderspiel/core/utils/helpers.dart';
import 'package:moerderspiel/presentation/providers/auth_provider.dart';
import 'package:moerderspiel/presentation/providers/game_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/app_button.dart';
import 'package:moerderspiel/presentation/widgets/common/avatar_widget.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _usernameCtrl = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
    if (picked == null) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      await ref.read(authRepositoryProvider).uploadAvatar(userId, picked);
      ref.invalidate(profileProvider);
      if (mounted) showSnack(context, 'Profilbild aktualisiert!');
    } catch (e) {
      if (mounted) showSnack(context, 'Fehler: $e', isError: true);
    }
  }

  Future<void> _saveUsername() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final name = _usernameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateUsername(userId, name);
      ref.invalidate(profileProvider);
      if (mounted) {
        showSnack(context, 'Name gespeichert!');
        setState(() => _editing = false);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Fehler: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final finishedGamesAsync = ref.watch(finishedGamesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Profil'),
        actions: const [],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) return const Center(child: Text('Kein Profil gefunden'));

          if (!_editing && _usernameCtrl.text.isEmpty) {
            _usernameCtrl.text = profile.username;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Avatar section
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _pickAndUploadAvatar,
                      child: AvatarWidget(
                        imageUrl: profile.avatarUrl,
                        name: profile.username,
                        radius: 60,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAndUploadAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Username
              Center(
                child: _editing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 200,
                            child: TextField(
                              controller: _usernameCtrl,
                              autofocus: true,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(border: UnderlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check, color: Colors.green),
                            onPressed: _saving ? null : _saveUsername,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => setState(() => _editing = false),
                          ),
                        ],
                      )
                    : GestureDetector(
                        onTap: () => setState(() => _editing = true),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              profile.username,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.edit, size: 18, color: theme.colorScheme.primary),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 32),

              // Stats grid
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatBox(emoji: '🗡️', value: '${profile.totalKills}', label: 'Kills'),
                    _vDivider,
                    _StatBox(emoji: '🏆', value: '${profile.totalWins}', label: 'Siege'),
                    _vDivider,
                    _StatBox(emoji: '🎮', value: '${profile.totalGames}', label: 'Spiele'),
                    _vDivider,
                    _StatBox(
                      emoji: '📊',
                      value: profile.totalGames > 0
                          ? '${(profile.totalWins / profile.totalGames * 100).round()}%'
                          : '–',
                      label: 'Winrate',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Notification status (web only)
              if (PushNotificationService.isPwa()) _NotificationTile(),

              const SizedBox(height: 24),

              // Game history
              Text('Spielhistorie', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              finishedGamesAsync.when(
                data: (games) {
                  if (games.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Noch keine beendeten Spiele.', style: theme.textTheme.bodyMedium),
                    );
                  }
                  return Column(
                    children: games.take(10).map((g) => ListTile(
                      leading: const Icon(Icons.sports_esports, color: Colors.grey),
                      title: Text(g.name),
                      subtitle: Text(g.endedAt != null ? formatDate(g.endedAt!) : '–'),
                      trailing: g.winnerId == profile.id
                          ? const Text('🏆', style: TextStyle(fontSize: 20))
                          : null,
                    )).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 32),

              // Sign out
              AppButton(
                label: 'Abmelden',
                onPressed: _signOut,
                outlined: true,
                color: Colors.red,
                icon: Icons.logout,
              ),
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
      ),
    );
  }

  static Widget get _vDivider => Container(height: 40, width: 1, color: Colors.grey.withOpacity(0.3));
}

class _NotificationTile extends StatefulWidget {
  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _loading = false;

  Future<void> _enable() async {
    setState(() => _loading = true);
    await PushNotificationService.init();
    if (mounted) setState(() => _loading = false);
    if (mounted) showSnack(context, '🔔 Benachrichtigungen aktiviert!');
  }

  @override
  Widget build(BuildContext context) {
    final perm = PushNotificationService.getPermission();
    final granted = perm == 'granted';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        granted ? Icons.notifications_active : Icons.notifications_off_outlined,
        color: granted ? Colors.green : Colors.grey,
      ),
      title: Text(granted ? 'Benachrichtigungen aktiv' : 'Benachrichtigungen inaktiv'),
      subtitle: Text(granted ? 'Du wirst benachrichtigt wenn etwas passiert.' : 'Tippe um sie zu aktivieren.'),
      trailing: granted
          ? null
          : _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: granted ? null : _enable,
    );
  }
}

class _StatBox extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  const _StatBox({required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}
