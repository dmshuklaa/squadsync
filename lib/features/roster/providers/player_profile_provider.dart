import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:squadsync/features/roster/data/roster_repository.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/guardian_link.dart';
import 'package:squadsync/shared/models/pending_player.dart';
import 'package:squadsync/shared/models/profile.dart';
import 'package:squadsync/shared/models/team_membership.dart';

part 'player_profile_provider.g.dart';

// ── Read providers ────────────────────────────────────────────

@riverpod
Future<Profile?> profileById(ProfileByIdRef ref, String profileId) async {
  final repo = ref.watch(rosterRepositoryProvider);
  return repo.getProfileById(profileId);
}

@riverpod
Future<PendingPlayer?> pendingPlayerById(
  PendingPlayerByIdRef ref,
  String pendingId,
) async {
  final repo = ref.watch(rosterRepositoryProvider);
  return repo.getPendingPlayerById(pendingId);
}

@riverpod
Future<TeamMembership?> teamMembershipForPlayer(
  TeamMembershipForPlayerRef ref,
  String profileId,
  String teamId,
) async {
  final repo = ref.watch(rosterRepositoryProvider);
  return repo.getMembershipForPlayer(profileId: profileId, teamId: teamId);
}

@riverpod
Future<List<Map<String, dynamic>>> fillInHistory(
  FillInHistoryRef ref,
  String profileId,
) async {
  final repo = ref.watch(rosterRepositoryProvider);
  return repo.getFillInHistory(profileId);
}

@riverpod
Future<List<GuardianLink>> guardianLinks(
  GuardianLinksRef ref,
  String playerProfileId,
) async {
  final repo = ref.watch(rosterRepositoryProvider);
  return repo.getGuardianLinks(playerProfileId);
}

// ── Mutation notifier ─────────────────────────────────────────

@riverpod
class PlayerProfileNotifier extends _$PlayerProfileNotifier {
  @override
  FutureOr<void> build() {}

  RosterRepository get _repo => ref.read(rosterRepositoryProvider);

  Future<void> updateMembershipStatus({
    required String membershipId,
    required MembershipStatus status,
    required String profileId,
    required String teamId,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.updateMembershipStatus(
        membershipId: membershipId,
        status: status,
      );
      ref.invalidate(teamMembershipForPlayerProvider(profileId, teamId));
      ref.invalidate(teamRosterProvider(teamId));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateMembershipDetails({
    required String membershipId,
    String? position,
    int? jerseyNumber,
    required String profileId,
    required String teamId,
  }) async {
    try {
      await _repo.updateMembershipDetails(
        membershipId: membershipId,
        position: position,
        jerseyNumber: jerseyNumber,
      );
      ref.invalidate(teamMembershipForPlayerProvider(profileId, teamId));
      ref.invalidate(teamRosterProvider(teamId));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> updateAvailability({
    required String profileId,
    required bool available,
    required String teamId,
  }) async {
    try {
      await _repo.updateAvailability(profileId: profileId, available: available);
      ref.invalidate(profileByIdProvider(profileId));
      ref.invalidate(teamRosterProvider(teamId));
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> deletePendingPlayer({
    required String pendingPlayerId,
    required String teamId,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.deletePendingPlayer(pendingPlayerId);
      ref.invalidate(teamRosterProvider(teamId));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> resendInviteEmail({
    required String teamId,
    required String email,
    String? fullName,
  }) async {
    try {
      await _repo.resendInviteEmail(
        teamId: teamId,
        email: email,
        fullName: fullName,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
