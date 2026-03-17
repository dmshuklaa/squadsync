import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/features/roster/data/csv_mapper.dart';
import 'package:squadsync/shared/models/division.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/guardian_link.dart';
import 'package:squadsync/shared/models/pending_player.dart';
import 'package:squadsync/shared/models/profile.dart';
import 'package:squadsync/shared/models/team.dart';
import 'package:squadsync/shared/models/team_membership.dart';

class RosterRepository {
  const RosterRepository();

  /// Fetches all memberships for [teamId], joining profile fields.
  Future<List<TeamMembership>> getTeamRoster(String teamId) async {
    // ignore: avoid_print
    print('[RosterRepository] getTeamRoster called with teamId: $teamId');
    try {
      final response = await supabase
          .from('team_memberships')
          .select(
            'id, team_id, profile_id, position, jersey_number, status, '
            'created_at, updated_at, '
            'profiles(full_name, avatar_url, availability_this_week)',
          )
          .eq('team_id', teamId)
          .order('profiles(full_name)');

      // ignore: avoid_print
      print('[RosterRepository] getTeamRoster raw response: $response');

      return (response as List)
          .map((row) => TeamMembership.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('[RosterRepository] getTeamRoster error: $e');
      // ignore: avoid_print
      print('[RosterRepository] error type: ${e.runtimeType}');
      // ignore: avoid_print
      print('[RosterRepository] stackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Returns teams accessible to [profileId] based on [role]:
  /// - club_admin / coach: all teams in the club (via divisions join)
  /// - player / parent: only teams where they have a membership
  ///
  /// Each [Team] has [divisionName] populated from the joined divisions row.
  Future<List<Team>> getTeamsForUser({
    required String profileId,
    required String clubId,
    required UserRole role,
  }) async {
    if (role == UserRole.clubAdmin || role == UserRole.coach) {
      final response = await supabase
          .from('teams')
          .select('id, division_id, name, season, created_at, divisions(name)')
          .eq('divisions.club_id', clubId)
          .order('name');

      return (response as List)
          .map((row) => Team.fromJson(row as Map<String, dynamic>))
          .where((t) => t.divisionName != null)
          .toList();
    } else {
      // player / parent: only teams they belong to
      final response = await supabase
          .from('team_memberships')
          .select(
            'teams(id, division_id, name, season, created_at, divisions(name))',
          )
          .eq('profile_id', profileId)
          .neq('status', MembershipStatus.archived.toJson());

      return (response as List)
          .map((row) {
            final teamData = row['teams'] as Map<String, dynamic>?;
            return teamData == null ? null : Team.fromJson(teamData);
          })
          .whereType<Team>()
          .toList();
    }
  }

  // ── Add player ───────────────────────────────────────────────

  /// Adds a player manually to [teamId].
  ///
  /// If a profile with [email] already exists the player is linked directly
  /// (membership status = active). If not, an entry is created in
  /// [pending_players] — no Supabase auth account or Edge Function is needed.
  Future<void> addPlayerManually({
    required String teamId,
    required String clubId,
    required String fullName,
    required String email,
    String? phone,
    String? position,
    int? jerseyNumber,
  }) async {
    // 1. Check if a real profile with this email already exists
    final existingProfile = await supabase
        .from('profiles')
        .select('id')
        .eq('email', email)
        .maybeSingle();

    if (existingProfile != null) {
      // 2a. Profile exists — check for duplicate membership
      final profileId = existingProfile['id'] as String;

      final existingMembership = await supabase
          .from('team_memberships')
          .select('id')
          .eq('team_id', teamId)
          .eq('profile_id', profileId)
          .maybeSingle();

      if (existingMembership != null) {
        throw Exception('This player is already on the team');
      }

      await supabase.from('team_memberships').insert({
        'team_id': teamId,
        'profile_id': profileId,
        'position': position,
        'jersey_number': jerseyNumber,
        'status': MembershipStatus.active.toJson(),
      });
      return;
    }

    // 2b. Check if already in pending_players for this team
    final existingPending = await supabase
        .from('pending_players')
        .select('id')
        .eq('team_id', teamId)
        .eq('email', email)
        .maybeSingle();

    if (existingPending != null) {
      throw Exception('An invite for this email is already pending');
    }

    // 3. No profile yet — insert into pending_players (no Edge Function needed)
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');

    final pendingData = <String, dynamic>{
      'team_id': teamId,
      'club_id': clubId,
      'full_name': fullName,
      'email': email,
      'position': position,
      'jersey_number': jerseyNumber,
      'invited_by': currentUser.id,
    };
    if (phone != null && phone.isNotEmpty) pendingData['phone'] = phone;
    // No .select() to avoid RLS SELECT policy issues
    await supabase.from('pending_players').insert(pendingData);
  }

  /// Sends an invitation email to [email] and adds them to [teamId].
  ///
  /// If a real profile exists they are linked as active (no email sent).
  /// If not, the send-invite Edge Function is called to create an auth user
  /// and send the magic-link email. If the Edge Function is not yet deployed,
  /// falls back to creating a [pending_players] entry so the invite still
  /// appears in the roster list.
  Future<void> sendInvite({
    required String teamId,
    required String email,
    String? fullName,
  }) async {
    // 1. Check for existing real profile
    final existingProfile = await supabase
        .from('profiles')
        .select('id')
        .eq('email', email)
        .maybeSingle();

    if (existingProfile != null) {
      final profileId = existingProfile['id'] as String;

      final existingMembership = await supabase
          .from('team_memberships')
          .select('id')
          .eq('team_id', teamId)
          .eq('profile_id', profileId)
          .maybeSingle();

      if (existingMembership != null) {
        throw Exception('This player is already on the team');
      }

      await supabase.from('team_memberships').insert({
        'team_id': teamId,
        'profile_id': profileId,
        'status': MembershipStatus.active.toJson(),
      });
      return;
    }

    // 2. Try Edge Function to create auth user + send magic-link email
    bool edgeFunctionSucceeded = false;
    try {
      final response = await supabase.functions.invoke(
        'send-invite',
        body: {
          'email': email,
          'fullName': fullName ?? email,
          'teamId': teamId,
          'sendEmail': true,
        },
      );
      if (response.status == 200) {
        final data = response.data as Map<String, dynamic>;
        final profileId = data['userId'] as String;
        final isNew = data['isNew'] as bool? ?? true;

        final existingMembership = await supabase
            .from('team_memberships')
            .select('id')
            .eq('team_id', teamId)
            .eq('profile_id', profileId)
            .maybeSingle();

        if (existingMembership == null) {
          await supabase.from('team_memberships').insert({
            'team_id': teamId,
            'profile_id': profileId,
            'status': isNew
                ? MembershipStatus.pending.toJson()
                : MembershipStatus.active.toJson(),
          });
        }
        edgeFunctionSucceeded = true;
      } else {
        // ignore: avoid_print
        print('send-invite returned ${response.status} — falling back');
      }
    } catch (e) {
      // Edge Function not deployed yet — fall back to pending_players
      // ignore: avoid_print
      print('send-invite not available: $e');
    }

    if (edgeFunctionSucceeded) return;

    // 3. Fallback: Edge Function unavailable — store in pending_players
    final existingPending = await supabase
        .from('pending_players')
        .select('id')
        .eq('team_id', teamId)
        .eq('email', email)
        .maybeSingle();

    if (existingPending != null) {
      throw Exception('An invite for this email is already pending');
    }

    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');

    final profileRow = await supabase
        .from('profiles')
        .select('club_id')
        .eq('id', currentUser.id)
        .single();
    final clubId = profileRow['club_id'] as String?;
    if (clubId == null) throw Exception('No club associated with your account');

    await supabase.from('pending_players').insert({
      'team_id': teamId,
      'club_id': clubId,
      'full_name': fullName ?? email,
      'email': email,
      'invited_by': currentUser.id,
    });
  }

  /// Imports [players] in batches of 20 into [teamId].
  ///
  /// Each player is either linked (profile found by email → active membership)
  /// or invited (new auth user created → pending membership + invite email sent).
  /// Reports progress via [onProgress] callback.
  Future<ImportResult> importPlayers({
    required String teamId,
    required List<PlayerImportRow> players,
    void Function(int current, int total)? onProgress,
  }) async {
    int linkedCount = 0;
    int invitedCount = 0;
    int skippedCount = 0;
    final List<SkippedRow> skippedRows = [];

    const batchSize = 20;

    for (int i = 0; i < players.length; i += batchSize) {
      final batch =
          players.sublist(i, (i + batchSize).clamp(0, players.length));

      for (int j = 0; j < batch.length; j++) {
        final player = batch[j];
        final rowNumber = i + j + 2; // row 1 = headers; data is 0-indexed
        onProgress?.call(i + j + 1, players.length);

        try {
          // Check for existing profile
          final existing = await supabase
              .from('profiles')
              .select('id')
              .eq('email', player.email)
              .maybeSingle();

          String profileId;
          bool isNew;

          if (existing != null) {
            profileId = existing['id'] as String;
            isNew = false;
          } else {
            final response = await supabase.functions.invoke(
              'send-invite',
              body: {
                'email': player.email,
                'fullName': player.fullName.isNotEmpty
                    ? player.fullName
                    : player.email,
                'teamId': teamId,
                'sendEmail': true,
              },
            );
            if (response.status != 200) {
              skippedCount++;
              skippedRows.add(SkippedRow(
                rowNumber: rowNumber,
                email: player.email,
                reason: 'Failed to create account',
              ));
              continue;
            }
            final data = response.data as Map<String, dynamic>;
            profileId = data['userId'] as String;
            isNew = data['isNew'] as bool? ?? true;
          }

          // Skip if already a member
          final existingMembership = await supabase
              .from('team_memberships')
              .select('id')
              .eq('team_id', teamId)
              .eq('profile_id', profileId)
              .maybeSingle();

          if (existingMembership != null) {
            skippedCount++;
            skippedRows.add(SkippedRow(
              rowNumber: rowNumber,
              email: player.email,
              reason: 'Already a member',
            ));
            continue;
          }

          await supabase.from('team_memberships').insert({
            'team_id': teamId,
            'profile_id': profileId,
            'position': player.position,
            'jersey_number': player.jerseyNumber,
            'status': isNew
                ? MembershipStatus.pending.toJson()
                : MembershipStatus.active.toJson(),
          });

          if (isNew) {
            invitedCount++;
          } else {
            linkedCount++;
          }
        } catch (e) {
          skippedCount++;
          skippedRows.add(SkippedRow(
            rowNumber: rowNumber,
            email: player.email,
            reason: e.toString(),
          ));
        }
      }
    }

    return ImportResult(
      totalRows: players.length,
      successCount: linkedCount + invitedCount,
      linkedCount: linkedCount,
      invitedCount: invitedCount,
      skippedCount: skippedCount,
      skippedRows: skippedRows,
    );
  }

  /// Returns all [PendingPlayer] records for [teamId], ordered by full_name.
  Future<List<PendingPlayer>> getPendingPlayers(String teamId) async {
    final response = await supabase
        .from('pending_players')
        .select()
        .eq('team_id', teamId)
        .order('full_name');

    return (response as List)
        .map((row) => PendingPlayer.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // ── Player profile ───────────────────────────────────────────

  /// Fetches a single [Profile] by [profileId]. Returns null if not found.
  Future<Profile?> getProfileById(String profileId) async {
    final data = await supabase
        .from('profiles')
        .select(
          'id, full_name, email, phone, avatar_url, role, club_id, '
          'push_token, availability_this_week, created_at, updated_at',
        )
        .eq('id', profileId)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  /// Fetches a single [PendingPlayer] by [pendingPlayerId].
  /// Returns null if not found.
  Future<PendingPlayer?> getPendingPlayerById(String pendingPlayerId) async {
    final data = await supabase
        .from('pending_players')
        .select()
        .eq('id', pendingPlayerId)
        .maybeSingle();

    if (data == null) return null;
    return PendingPlayer.fromJson(data);
  }

  /// Fetches the [TeamMembership] for [profileId] in [teamId].
  /// Returns null if no membership exists.
  Future<TeamMembership?> getMembershipForPlayer({
    required String profileId,
    required String teamId,
  }) async {
    final data = await supabase
        .from('team_memberships')
        .select(
          'id, team_id, profile_id, position, jersey_number, status, '
          'created_at, updated_at, '
          'profiles(full_name, avatar_url, availability_this_week)',
        )
        .eq('profile_id', profileId)
        .eq('team_id', teamId)
        .maybeSingle();

    if (data == null) return null;
    return TeamMembership.fromJson(data);
  }

  /// Updates the [status] column of a team membership.
  Future<void> updateMembershipStatus({
    required String membershipId,
    required MembershipStatus status,
  }) async {
    await supabase
        .from('team_memberships')
        .update({'status': status.toJson()})
        .eq('id', membershipId);
  }

  /// Updates [position] and [jerseyNumber] on a team membership.
  Future<void> updateMembershipDetails({
    required String membershipId,
    String? position,
    int? jerseyNumber,
  }) async {
    await supabase.from('team_memberships').update({
      'position': position,
      'jersey_number': jerseyNumber,
    }).eq('id', membershipId);
  }

  /// Updates [availability_this_week] on a profile (own profile only — RLS enforced).
  Future<void> updateAvailability({
    required String profileId,
    required bool available,
  }) async {
    await supabase
        .from('profiles')
        .update({'availability_this_week': available})
        .eq('id', profileId);
  }

  /// Returns fill-in history for [profileId], limited to 20 rows.
  /// Returns an empty list if the [fill_in_log] table does not exist yet.
  Future<List<Map<String, dynamic>>> getFillInHistory(
      String profileId) async {
    try {
      final response = await supabase
          .from('fill_in_log')
          .select('game_name, event_date, target_division_name, outcome')
          .eq('player_profile_id', profileId)
          .order('event_date', ascending: false)
          .limit(20);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (_) {
      // Table does not exist yet (Sprint 3) — return empty list
      return [];
    }
  }

  /// Returns guardian links for [playerProfileId], joining guardian profile data.
  Future<List<GuardianLink>> getGuardianLinks(
      String playerProfileId) async {
    try {
      final response = await supabase
          .from('guardian_links')
          .select(
            'id, player_profile_id, guardian_profile_id, '
            'permission_level, confirmed, created_at, '
            'profiles!guardian_profile_id(full_name, avatar_url)',
          )
          .eq('player_profile_id', playerProfileId);

      return (response as List)
          .map((row) => GuardianLink.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Deletes a pending_players row by [pendingPlayerId].
  Future<void> deletePendingPlayer(String pendingPlayerId) async {
    await supabase
        .from('pending_players')
        .delete()
        .eq('id', pendingPlayerId);
  }

  /// Calls the send-invite Edge Function to resend a magic-link email.
  /// Does not create a new pending_player row — the player is already listed.
  Future<void> resendInviteEmail({
    required String teamId,
    required String email,
    String? fullName,
  }) async {
    try {
      await supabase.functions.invoke(
        'send-invite',
        body: {
          'email': email,
          'fullName': fullName ?? email,
          'teamId': teamId,
          'sendEmail': true,
        },
      );
    } catch (e) {
      // Edge Function not yet deployed — silently succeed (nothing to resend)
      // ignore: avoid_print
      print('send-invite not available for resend: $e');
    }
  }

  /// Returns all divisions for a club, ordered by display_order.
  Future<List<Division>> getDivisionsForClub(String clubId) async {
    final response = await supabase
        .from('divisions')
        .select('id, club_id, name, display_order, fill_in_enabled, created_at')
        .eq('club_id', clubId)
        .order('display_order');

    return (response as List)
        .map((row) => Division.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
