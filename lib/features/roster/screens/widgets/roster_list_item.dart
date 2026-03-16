import 'package:flutter/material.dart';

import 'package:squadsync/shared/models/team_membership.dart';
import 'package:squadsync/shared/widgets/avatar_widget.dart';
import 'package:squadsync/shared/widgets/status_badge.dart';

/// A single row in the roster list showing avatar, name, position/jersey,
/// availability indicator, and status badge.
class RosterListItem extends StatelessWidget {
  const RosterListItem({
    super.key,
    required this.membership,
    required this.onTap,
  });

  final TeamMembership membership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = membership.profileFullName ?? 'Unknown Player';
    final position = membership.position;
    final jersey = membership.jerseyNumber;
    final available = membership.profileAvailabilityThisWeek;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          AvatarWidget(
            fullName: name,
            avatarUrl: membership.profileAvatarUrl,
            size: 44,
          ),
          if (available != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: available ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _subtitle(position, jersey),
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
      trailing: StatusBadge(membership.status),
    );
  }

  String _subtitle(String? position, int? jersey) {
    final parts = <String>[];
    if (position != null) parts.add(position);
    if (jersey != null) parts.add('#$jersey');
    return parts.isEmpty ? 'No position' : parts.join(' · ');
  }
}
