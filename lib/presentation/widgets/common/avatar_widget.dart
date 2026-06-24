import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moerderspiel/presentation/providers/kniffel_provider.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final bool isAlive;
  final bool showCrown;
  final bool showClown;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 24,
    this.isAlive = true,
    this.showCrown = false,
    this.showClown = false,
  });

  @override
  Widget build(BuildContext context) {
    final initials = (name?.isNotEmpty == true) ? name![0].toUpperCase() : '?';

    Widget avatar;
    if (imageUrl != null) {
      avatar = CachedNetworkImage(
        imageUrl: imageUrl!,
        imageBuilder: (_, img) => CircleAvatar(radius: radius, backgroundImage: img),
        placeholder: (_, __) => _placeholder(initials, context),
        errorWidget: (_, __, ___) => _placeholder(initials, context),
      );
    } else {
      avatar = _placeholder(initials, context);
    }

    if (!isAlive) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.213, 0.715, 0.072, 0, 0,
              0.213, 0.715, 0.072, 0, 0,
              0.213, 0.715, 0.072, 0, 0,
              0,     0,     0,     1, 0,
            ]),
            child: avatar,
          ),
          Positioned.fill(
            child: Center(
              child: Text('☠️', style: TextStyle(fontSize: radius * 0.8)),
            ),
          ),
        ],
      );
    }

    if (showCrown) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            top: -(radius * 0.45),
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '👑',
                style: TextStyle(fontSize: radius * 0.65),
              ),
            ),
          ),
        ],
      );
    }

    if (showClown) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            top: -(radius * 0.45),
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                '🤡',
                style: TextStyle(fontSize: radius * 0.65),
              ),
            ),
          ),
        ],
      );
    }

    return avatar;
  }

  Widget _placeholder(String initials, BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Drop-in replacement for [AvatarWidget] that automatically shows the Kniffel
/// crown (🥇 daily winner) or clown (🤡 last place) based on [userId].
class KniffelAwareAvatarWidget extends ConsumerWidget {
  final String? imageUrl;
  final String? name;
  final String? userId;
  final double radius;
  final bool isAlive;

  const KniffelAwareAvatarWidget({
    super.key,
    this.imageUrl,
    this.name,
    this.userId,
    this.radius = 24,
    this.isAlive = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(dailyKniffelBadgesProvider).value;
    final showCrown =
        userId != null && (badges?.winners.contains(userId) ?? false);
    final showClown =
        userId != null && (badges?.lastPlace.contains(userId) ?? false);

    return AvatarWidget(
      imageUrl: imageUrl,
      name: name,
      radius: radius,
      isAlive: isAlive,
      showCrown: showCrown,
      showClown: showClown,
    );
  }
}
