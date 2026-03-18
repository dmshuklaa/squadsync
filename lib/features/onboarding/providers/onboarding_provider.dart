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
  /// Uses the same character set as the Postgres generate_join_code()
  /// function (omits 0/O/1/I to avoid ambiguity).
  /// The clubs.join_code UNIQUE constraint handles the rare collision.
  static String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Creates a new club, sets the current user as club_admin, and seeds a
  /// default Division 1 + Team 1.  Calls [supabase.auth.refreshSession] at
  /// the end so GoRouter's [_AuthChangeNotifier] re-fetches the profile
  /// club_id and redirects to /home.
  ///
  /// UUIDs are generated client-side so we never need to call .select()
  /// after INSERT — avoiding the RLS SELECT policy blocking the RETURNING
  /// clause while the user's profile club_id is still NULL.
  Future<void> createClub(String name, String sportType) async {
    state = const AsyncLoading();
    try {
      // ── Diagnostic logging (remove before production) ──────
      final user = supabase.auth.currentUser;
      final session = supabase.auth.currentSession;
      // ignore: avoid_print
      print('[Onboarding] user id:    ${user?.id}');
      // ignore: avoid_print
      print('[Onboarding] user email: ${user?.email}');
      // ignore: avoid_print
      print('[Onboarding] session exists: ${session != null}');
      // ignore: avoid_print
      print('[Onboarding] token prefix:   '
          '${session?.accessToken.substring(0, 20)}');
      // ───────────────────────────────────────────────────────

      // Generate IDs client-side — no .select() after INSERT means the
      // SELECT RLS policy is never evaluated at clubs/divisions insert time.
      final clubId = _uuid.v4();
      final divisionId = _uuid.v4();

      // 1. Insert club — no .select(), we already know the ID
      // ignore: avoid_print
      print('[Onboarding] inserting club id=$clubId...');
      await supabase.from('clubs').insert({
        'id': clubId,
        'name': name,
        'sport_type': sportType,
        'join_code': _generateJoinCode(),
      });
      // ignore: avoid_print
      print('[Onboarding] clubs insert done');

      // 2. Update current user's profile — club_id + role = club_admin
      // ignore: avoid_print
      print('[Onboarding] updating profile...');
      await supabase
          .from('profiles')
          .update({'club_id': clubId, 'role': 'club_admin'})
          .eq('id', supabase.auth.currentUser!.id);
      // ignore: avoid_print
      print('[Onboarding] profile update done');

      // 3. Seed default Division 1 — no .select(), we already know the ID
      // ignore: avoid_print
      print('[Onboarding] inserting Division 1 id=$divisionId...');
      await supabase.from('divisions').insert({
        'id': divisionId,
        'club_id': clubId,
        'name': 'Division 1',
        'display_order': 1,
      });
      // ignore: avoid_print
      print('[Onboarding] division insert done');

      // 4. Seed default Team 1 (no ID needed back)
      // ignore: avoid_print
      print('[Onboarding] inserting Team 1...');
      final currentYear = DateTime.now().year.toString();
      await supabase.from('teams').insert({
        'division_id': divisionId,
        'name': 'Team 1',
        'season': currentYear,
      });
      // ignore: avoid_print
      print('[Onboarding] team insert done');

      // 5. Trigger GoRouter re-evaluation: refreshSession emits a stream
      //    event that _AuthChangeNotifier picks up, re-fetches club_id, and
      //    calls notifyListeners() — GoRouter then redirects to /home.
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
  /// Throws [ClubNotFoundException] when no club matches — callers should
  /// show an inline error, not a SnackBar.
  Future<void> joinClub(String joinCode) async {
    // ignore: avoid_print
    print('[OnboardingProvider] joinClub called with code: $joinCode');
    state = const AsyncLoading();
    try {
      // 1. Look up club by join code (full row for logging)
      // ignore: avoid_print
      print('[OnboardingProvider] Looking up club with code: '
          '${joinCode.toUpperCase()}');
      final result = await supabase
          .from('clubs')
          .select()
          .ilike('join_code', joinCode.toUpperCase())
          .maybeSingle();

      // ignore: avoid_print
      print('[OnboardingProvider] Club lookup result: $result');

      if (result == null) {
        // ignore: avoid_print
        print('[OnboardingProvider] No club found for code: $joinCode');
        state = const AsyncData(null);
        throw const ClubNotFoundException();
      }

      final clubId = result['id'] as String;
      // ignore: avoid_print
      print('[OnboardingProvider] Found club: '
          '${result['name']} id: $clubId');

      // 2. Update profile — keep existing role, just set club_id
      final userId = supabase.auth.currentUser!.id;
      final userEmail = supabase.auth.currentUser!.email;
      // ignore: avoid_print
      print('[OnboardingProvider] Updating profile $userId '
          'with club_id: $clubId');
      await supabase
          .from('profiles')
          .update({'club_id': clubId})
          .eq('id', userId);
      // ignore: avoid_print
      print('[OnboardingProvider] Profile updated successfully');

      // 3. Find the first team in the club and create/activate membership.
      //
      //    Three cases:
      //    a) Player was never added → insert active membership.
      //    b) Player was added via invite (status=pending) → update to active.
      //    c) Player already has an active membership → do nothing.
      //
      //    Also delete any pending_players row for this email — the player has
      //    now signed up so that shadow record is no longer needed.
      final teamsResult = await supabase
          .from('teams')
          .select('id, divisions!inner(club_id)')
          .eq('divisions.club_id', clubId)
          .limit(1)
          .maybeSingle();

      // ignore: avoid_print
      print('[OnboardingProvider] First team lookup: $teamsResult');

      if (teamsResult != null) {
        final teamId = teamsResult['id'] as String;

        // Check for an existing membership in this team
        final existingMembership = await supabase
            .from('team_memberships')
            .select('id, status')
            .eq('team_id', teamId)
            .eq('profile_id', userId)
            .maybeSingle();

        // ignore: avoid_print
        print('[OnboardingProvider] Existing membership: $existingMembership');

        if (existingMembership == null) {
          // No membership — create one as active
          await supabase.from('team_memberships').insert({
            'team_id': teamId,
            'profile_id': userId,
            'status': 'active',
          });
          // ignore: avoid_print
          print('[OnboardingProvider] Created active membership in team $teamId');
        } else if (existingMembership['status'] != 'active') {
          // Membership exists but is pending/inactive — activate it
          await supabase
              .from('team_memberships')
              .update({'status': 'active'})
              .eq('id', existingMembership['id'] as String);
          // ignore: avoid_print
          print('[OnboardingProvider] Activated existing membership '
              '${existingMembership['id']}');
        } else {
          // ignore: avoid_print
          print('[OnboardingProvider] Membership already active — no change');
        }

        // Clean up shadow pending_players row if one exists for this email
        if (userEmail != null) {
          await supabase
              .from('pending_players')
              .delete()
              .eq('team_id', teamId)
              .eq('email', userEmail);
          // ignore: avoid_print
          print('[OnboardingProvider] Cleaned up pending_players for $userEmail');
        }
      }

      // 4. Trigger GoRouter re-evaluation (same mechanism as createClub)
      await supabase.auth.refreshSession();

      state = const AsyncData(null);
    } on ClubNotFoundException {
      // State already set to AsyncData(null) above — just rethrow so
      // the screen can show the inline error.
      rethrow;
    } catch (e, st) {
      // ignore: avoid_print
      print('[OnboardingProvider] joinClub error: $e');
      // ignore: avoid_print
      print('[OnboardingProvider] type: ${e.runtimeType}');
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
