import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:moerderspiel/presentation/providers/game_provider.dart';
import 'package:moerderspiel/presentation/widgets/common/app_button.dart';
import 'package:moerderspiel/presentation/widgets/common/avatar_widget.dart';

class TargetScreen extends ConsumerWidget {
  final String gameId;
  const TargetScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentAsync = ref.watch(assignmentProvider(gameId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Dein Ziel')),
      body: assignmentAsync.when(
        data: (assignment) {
          if (assignment == null) {
            return const Center(child: Text('Keine aktive Zuweisung'));
          }
          final target = assignment.targetProfile;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Target photo with dramatic frame
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.3)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: AvatarWidget(
                    imageUrl: target?.avatarUrl,
                    name: target?.username,
                    radius: 72,
                  ),
                ).animate().fadeIn().scale(curve: Curves.elasticOut),

                const SizedBox(height: 24),
                Text(
                  '🎯 ZIELERFASST',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  target?.username ?? '???',
                  style: GoogleFonts.rajdhani(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(height: 8),
                      const Text(
                        'Diese Information ist streng geheim.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Niemand außer dir weiß, wer dein Ziel ist. Sei diskret!',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 32),
                AppButton(
                  label: 'Kill melden',
                  onPressed: () => context.push('/game/$gameId/report-kill'),
                  icon: Icons.gps_fixed,
                ).animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Meine Aufgaben ansehen',
                  onPressed: () => context.push('/game/$gameId/tasks'),
                  outlined: true,
                  icon: Icons.task_alt,
                ).animate().fadeIn(delay: 700.ms),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
      ),
    );
  }
}
