import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Circular avatar that shows [avatarUrl] if available, otherwise
/// shows the first letter of [fullName] on a coloured background.
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.fullName,
    this.avatarUrl,
    this.size = 40,
  });

  final String fullName;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => _initials(context),
          errorWidget: (_, _, _) => _initials(context),
        ),
      );
    }
    return _initials(context);
  }

  Widget _initials(BuildContext context) {
    final initial =
        fullName.trim().isNotEmpty ? fullName.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
