import 'package:flutter/material.dart';

import 'package:squadsync/shared/models/roster_entry.dart';
import 'package:squadsync/shared/widgets/avatar_widget.dart';
import 'package:squadsync/shared/widgets/status_badge.dart';

/// A single row in the roster list showing avatar, name, position/jersey,
/// availability indicator, and status badge.
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          AvatarWidget(
            fullName: entry.fullName,
            avatarUrl: entry.avatarUrl,
            size: 44,
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
                      ? Colors.green
                      : Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        entry.fullName,
        style: const TextStyle(fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _subtitle(entry.position, entry.jerseyNumber),
        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
      trailing: StatusBadge(entry.status),
    );
  }

  String _subtitle(String? position, int? jersey) {
    final parts = <String>[];
    if (position != null) parts.add(position);
    if (jersey != null) parts.add('#$jersey');
    return parts.isEmpty ? 'No position' : parts.join(' · ');
  }
}
