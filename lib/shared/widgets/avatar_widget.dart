import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:squadsync/core/theme/app_theme.dart';

/// Circular avatar that shows [avatarUrl] if available, otherwise
/// shows the first letter of [fullName] on a navy background.
///
/// When [showRing] is true a 2 px teal accent ring is drawn around
/// the avatar — used on profile header banners.
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.fullName,
    this.avatarUrl,
    this.size = 40,
    this.showRing = false,
  });

  final String fullName;
  final String? avatarUrl;
  final double size;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final avatar = _buildAvatar(context);
    if (!showRing) return avatar;

    // Teal ring: 2 px border + 3 px gap between ring and avatar
    final ringSize = size + 10;
    return Container(
      width: ringSize,
      height: ringSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.accent, width: 2.5),
      ),
      child: Center(child: avatar),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final url = avatarUrl;
    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => _initials(),
          errorWidget: (_, _, _) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() {
    final initial =
        fullName.trim().isNotEmpty ? fullName.trim()[0].toUpperCase() : '?';
    // Curated palette — cycles by character code so the same name always
    // gets the same colour but adjacent names differ.
    const palette = [
      AppColors.primary,           // deep navy
      AppColors.accent,            // electric teal
      AppColors.primaryLight,      // mid navy
      Color(0xFF6C5CE7),           // purple
      Color(0xFFE17055),           // coral
      Color(0xFF00B894),           // green
    ];
    final bg = palette[initial.codeUnitAt(0) % palette.length];
    final fg = bg == AppColors.accent ? AppColors.primary : Colors.white;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: bg,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}
