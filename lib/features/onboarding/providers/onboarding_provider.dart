import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'package:squadsync/core/supabase/supabase_client.dart';

part 'onboarding_provider.g.dart';

/// Thrown by [OnboardingNotifier.joinClub] when no club matches the code.
/// The screen catches this to show an inline error rather than a SnackBar.
class ClubNotFoundException implements Exception {
  const ClubNotFoundException();
}

/// Handles all Supabase work for the onboarding flow.
///
/// State is [AsyncLoading] while an operation is in flight,
/// [AsyncData] when idle or successful, [AsyncError] on unexpected failure.
@riverpod
class OnboardingNotifier extends _$OnboardingNotifier {
  @override
  FutureOr<void> build() {}

  static const _uuid = Uuid();

  /// Generates a 6-character alphanumeric join code client-side.
  static String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Creates a new club, sets the current user as club_admin, and seeds a
  /// default Division 1 + Team 1.
  Future<void> createClub(String name, String sportType) async {
    state = const AsyncLoading();
    try {
      final clubId = _uuid.v4();
      final divisionId = _uuid.v4();

      await supabase.from('clubs').insert({
        'id': clubId,
        'name': name,
        'sport_type': sportType,
        'join_code': _generateJoinCode(),
      });

      await supabase
          .from('profiles')
          .update({'club_id': clubId, 'role': 'club_admin'})
          .eq('id', supabase.auth.currentUser!.id);

      await supabase.from('divisions').insert({
        'id': divisionId,
        'club_id': clubId,
        'name': 'Division 1',
        'display_order': 1,
      });

      final currentYear = DateTime.now().year.toString();
      await supabase.from('teams').insert({
        'division_id': divisionId,
        'name': 'Team 1',
        'season': currentYear,
      });

      await supabase.auth.refreshSession();

      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Looks up a club by join code (case-insensitive) and links the current
  /// user's profile to it, keeping their existing role.
  ///
  /// Also handles per-player join codes stored in [pending_players.join_code].
  /// When a per-player code is matched:
  ///   - The user's profile is linked to the club
  ///   - A team_membership is created/activated for the specific team
  ///   - The pending_players row is deleted
  ///
  /// Throws [ClubNotFoundException] when no club or pending player matches.
  Future<void> joinClub(String joinCode) async {
    state = const AsyncLoading();
    try {
      final userId = supabase.auth.currentUser!.id;
      final userEmail = supabase.auth.currentUser!.email;
      final code = joinCode.trim().toUpperCase();

      // 1. First try clubs.join_code (6-char club-level code)
      final clubResult = await supabase
          .from('clubs')
          .select()
          .ilike('join_code', code)
          .maybeSingle();

      if (clubResult != null) {
        await _joinViaClubCode(
            clubResult: clubResult, userId: userId, userEmail: userEmail);
        await supabase.auth.refreshSession();
        state = const AsyncData(null);
        return;
      }

      // 2. Try pending_players.join_code (8-char per-player code)
      final pendingResult = await supabase
          .from('pending_players')
          .select('id, club_id, team_id, full_name')
          .ilike('join_code', code)
          .maybeSingle();

      if (pendingResult != null) {
        await _joinViaPendingPlayerCode(
            pendingResult: pendingResult,
            userId: userId,
            userEmail: userEmail);
        await supabase.auth.refreshSession();
        state = const AsyncData(null);
        return;
      }

      // 3. No match found
      state = const AsyncData(null);
      throw const ClubNotFoundException();
    } on ClubNotFoundException {
      rethrow;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> _joinViaClubCode({
    required Map<String, dynamic> clubResult,
    required String userId,
    required String? userEmail,
  }) async {
    final clubId = clubResult['id'] as String;

    // Update profile — keep existing role, just set club_id
    await supabase
        .from('profiles')
        .update({'club_id': clubId})
        .eq('id', userId);

    // Find the first team in the club and create/activate membership
    final teamsResult = await supabase
        .from('teams')
        .select('id, divisions!inner(club_id)')
        .eq('divisions.club_id', clubId)
        .limit(1)
        .maybeSingle();

    if (teamsResult != null) {
      final teamId = teamsResult['id'] as String;

      final existingMembership = await supabase
          .from('team_memberships')
          .select('id, status')
          .eq('team_id', teamId)
          .eq('profile_id', userId)
          .maybeSingle();

      if (existingMembership == null) {
        await supabase.from('team_memberships').insert({
          'team_id': teamId,
          'profile_id': userId,
          'status': 'active',
        });
      } else if (existingMembership['status'] != 'active') {
        await supabase
            .from('team_memberships')
            .update({'status': 'active'})
            .eq('id', existingMembership['id'] as String);
      }
    }

    // Delete pending_players rows for this email
    if (userEmail != null) {
      await supabase
          .from('pending_players')
          .delete()
          .eq('email', userEmail);
    }
  }

  Future<void> _joinViaPendingPlayerCode({
    required Map<String, dynamic> pendingResult,
    required String userId,
    required String? userEmail,
  }) async {
    final pendingId = pendingResult['id'] as String;
    final clubId = pendingResult['club_id'] as String;
    final teamId = pendingResult['team_id'] as String;

    // Link the user to the club
    await supabase
        .from('profiles')
        .update({'club_id': clubId})
        .eq('id', userId);

    // Create or activate membership for the specific team
    final existingMembership = await supabase
        .from('team_memberships')
        .select('id, status')
        .eq('team_id', teamId)
        .eq('profile_id', userId)
        .maybeSingle();

    if (existingMembership == null) {
      await supabase.from('team_memberships').insert({
        'team_id': teamId,
        'profile_id': userId,
        'status': 'active',
      });
    } else if (existingMembership['status'] != 'active') {
      await supabase
          .from('team_memberships')
          .update({'status': 'active'})
          .eq('id', existingMembership['id'] as String);
    }

    // Delete the pending_players row — player has now signed up
    await supabase.from('pending_players').delete().eq('id', pendingId);

    // Also delete any other pending rows for this email
    if (userEmail != null) {
      await supabase
          .from('pending_players')
          .delete()
          .eq('email', userEmail);
    }
  }
}
