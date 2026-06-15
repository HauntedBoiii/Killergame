import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final bool isAlive;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 24,
    this.isAlive = true,
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
    return avatar;
  }

  Widget _placeholder(String initials, BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
