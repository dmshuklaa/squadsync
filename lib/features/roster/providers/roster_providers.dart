import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/features/roster/data/roster_repository.dart';
import 'package:squadsync/shared/models/division.dart';
import 'package:squadsync/shared/models/profile.dart';
import 'package:squadsync/shared/models/roster_entry.dart';
import 'package:squadsync/shared/models/team.dart';

part 'roster_providers.g.dart';

// ── Repository ───────────────────────────────────────────────

@riverpod
RosterRepository rosterRepository(RosterRepositoryRef ref) {
  return const RosterRepository();
}

// ── Current profile ──────────────────────────────────────────

/// Fetches the currently signed-in user's profile.
@riverpod
Future<Profile> currentProfile(CurrentProfileRef ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) throw StateError('No authenticated user');

  final data = await supabase
      .from('profiles')
      .select(
        'id, full_name, email, phone, avatar_url, role, club_id, '
        'push_token, availability_this_week, created_at, updated_at',
      )
      .eq('id', userId)
      .single();

  return Profile.fromJson(data);
}

// ── Teams for user ───────────────────────────────────────────

/// Returns the list of teams accessible to the current user.
@riverpod
Future<List<Team>> userTeams(UserTeamsRef ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile.clubId == null) return [];

  final repo = ref.watch(rosterRepositoryProvider);
  return repo.getTeamsForUser(
    profileId: profile.id,
    clubId: profile.clubId!,
    role: profile.role,
  );
}

// ── Roster for a team ────────────────────────────────────────

/// Returns roster entries for [teamId], merging real memberships and
/// pending players into a unified [RosterEntry] list sorted by name.
@riverpod
Future<List<RosterEntry>> teamRoster(
  TeamRosterRef ref,
  String teamId,
) async {
  final repo = ref.watch(rosterRepositoryProvider);

  final memberships = await repo.getTeamRoster(teamId);
  final pending = await repo.getPendingPlayers(teamId);

  final entries = [
    ...memberships.map(RosterEntry.fromMembership),
    ...pending.map(RosterEntry.fromPendingPlayer),
  ];

  entries.sort((a, b) => a.fullName.compareTo(b.fullName));
  return entries;
}

// ── Divisions for club ───────────────────────────────────────

/// Returns all divisions for the current user's club.
@riverpod
Future<List<Division>> clubDivisions(ClubDivisionsRef ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile.clubId == null) return [];

  final repo = ref.watch(rosterRepositoryProvider);
  return repo.getDivisionsForClub(profile.clubId!);
}
