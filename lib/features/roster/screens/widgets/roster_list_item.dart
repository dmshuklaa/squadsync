import 'package:flutter/material.dart';

import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/shared/models/roster_entry.dart';
import 'package:squadsync/shared/widgets/avatar_widget.dart';
import 'package:squadsync/shared/widgets/status_badge.dart';

/// A card-style row in the roster list showing avatar, name,
/// position/jersey, availability indicator, and status badge.
class RosterListItem extends StatelessWidget {
  const RosterListItem({
    super.key,
    required this.entry,
    this.onTap,
  });

  final RosterEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            // Avatar with optional availability dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                AvatarWidget(
                  fullName: entry.fullName,
                  avatarUrl: entry.avatarUrl,
                  size: 48,
                ),
                if (!entry.isPending)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: entry.availabilityThisWeek
                            ? AppColors.activeGreen
                            : AppColors.pendingAmber,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.fullName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(entry.position, entry.jerseyNumber),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(entry.status),
          ],
        ),
      ),
    );
  }

  String _subtitle(String? position, int? jersey) {
    final parts = <String>[];
    if (position != null) parts.add(position);
    if (jersey != null) parts.add('#$jersey');
    return parts.isEmpty ? 'No position' : parts.join(' · ');
  }
}
