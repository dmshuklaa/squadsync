import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/pending_player.dart';
import 'package:squadsync/shared/models/team_membership.dart';

/// Unified display model for the roster list.
/// Represents either a real [TeamMembership] or a [PendingPlayer].
class RosterEntry {
  const RosterEntry({
    required this.id,
    required this.profileId,
    required this.fullName,
    this.avatarUrl,
    this.position,
    this.jerseyNumber,
    required this.status,
    required this.isPending,
    required this.availabilityThisWeek,
  });

  final String id;
  final String profileId;
  final String fullName;
  final String? avatarUrl;
  final String? position;
  final int? jerseyNumber;
  final MembershipStatus status;

  /// True when this entry comes from [pending_players] (no auth account yet).
  final bool isPending;
  final bool availabilityThisWeek;

  static RosterEntry fromMembership(TeamMembership m) => RosterEntry(
        id: m.id,
        profileId: m.profileId,
        fullName: m.profileFullName ?? 'Unknown',
        avatarUrl: m.profileAvatarUrl,
        position: m.position,
        jerseyNumber: m.jerseyNumber,
        status: m.status,
        isPending: false,
        availabilityThisWeek: m.profileAvailabilityThisWeek ?? true,
      );

  static RosterEntry fromPendingPlayer(PendingPlayer p) => RosterEntry(
        id: p.id,
        profileId: '',
        // Guard: sendInvite fallback stores email as full_name when no name
        // is provided. Display the local-part only so raw emails never appear.
        fullName: (p.fullName == p.email)
            ? p.email.split('@').first
            : p.fullName,
        avatarUrl: null,
        position: p.position,
        jerseyNumber: p.jerseyNumber,
        status: MembershipStatus.pending,
        isPending: true,
        availabilityThisWeek: true,
      );
}
