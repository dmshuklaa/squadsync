import 'package:flutter/foundation.dart';
import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/features/notifications/data/notifications_repository.dart';
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
    final response = await supabase
        .from('team_memberships')
        .select(
          'id, team_id, profile_id, position, jersey_number, status, '
          'created_at, updated_at, '
          'profiles(full_name, avatar_url, availability_this_week)',
        )
        .eq('team_id', teamId)
        .order('profiles(full_name)');

    return (response as List)
        .map((row) => TeamMembership.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Returns teams accessible to [profileId] based on [role].
  Future<List<Team>> getTeamsForUser({
    required String profileId,
    required String clubId,
    required UserRole role,
  }) async {
    List<Team> teams;

    if (role == UserRole.clubAdmin || role == UserRole.coach) {
      final profileResponse = await supabase
          .from('profiles')
          .select('club_id')
          .eq('id', profileId)
          .single();
      final resolvedClubId = profileResponse['club_id'] as String?;

      if (resolvedClubId == null) return [];

      final response = await supabase
          .from('teams')
          .select(
            'id, name, division_id, season, created_at, '
            'divisions!inner(id, name, display_order, club_id)',
          )
          .eq('divisions.club_id', resolvedClubId)
          .order('display_order', referencedTable: 'divisions', ascending: true);

      teams = (response as List)
          .map((row) => Team.fromJson(row as Map<String, dynamic>))
          .toList();
    } else {
      final response = await supabase
          .from('team_memberships')
          .select(
            'team_id, '
            'teams!inner('
            'id, division_id, name, season, created_at, '
            'divisions!inner(id, name, display_order)'
            ')',
          )
          .eq('profile_id', profileId)
          .eq('status', 'active');

      teams = (response as List)
          .map((row) {
            final teamData = row['teams'] as Map<String, dynamic>?;
            return teamData == null ? null : Team.fromJson(teamData);
          })
          .whereType<Team>()
          .toList();
    }

    if (teams.isEmpty) {
      final fallback = await supabase
          .from('team_memberships')
          .select(
            'teams!inner('
            'id, division_id, name, season, created_at, '
            'divisions!inner(id, name, display_order)'
            ')',
          )
          .eq('profile_id', profileId)
          .eq('status', 'active');

      teams = (fallback as List)
          .map((row) {
            final teamData = row['teams'] as Map<String, dynamic>?;
            return teamData == null ? null : Team.fromJson(teamData);
          })
          .whereType<Team>()
          .toList();
    }

    return teams;
  }

  // ── Add player ───────────────────────────────────────────────

  Future<void> addPlayerManually({
    required String teamId,
    required String clubId,
    required String fullName,
    String? email,
    String? phone,
    String? position,
    int? jerseyNumber,
  }) async {
    if (email != null && email.isNotEmpty) {
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
          'position': position,
          'jersey_number': jerseyNumber,
          'status': MembershipStatus.active.toJson(),
        });
        return;
      }

      final existingPending = await supabase
          .from('pending_players')
          .select('id')
          .eq('team_id', teamId)
          .eq('email', email)
          .maybeSingle();

      if (existingPending != null) {
        throw Exception('An invite for this email is already pending');
      }
    }

    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');

    final joinCode = email == null || email.isEmpty
        ? generatePlayerJoinCode()
        : null;

    final pendingData = <String, dynamic>{
      'team_id': teamId,
      'club_id': clubId,
      'full_name': fullName,
      'email': email?.isNotEmpty == true ? email : null,
      'position': position,
      'jersey_number': jerseyNumber,
      'invited_by': currentUser.id,
      'join_code': joinCode,
    };
    if (phone != null && phone.isNotEmpty) pendingData['phone'] = phone;
    await supabase.from('pending_players').insert(pendingData);
  }

  Future<void> sendInvite({
    required String teamId,
    required String email,
    String? fullName,
  }) async {
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
        debugPrint('send-invite returned ${response.status} — falling back');
      }
    } catch (e) {
      debugPrint('send-invite not available: $e');
    }

    if (edgeFunctionSucceeded) return;

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

  // ── Division / team helpers ───────────────────────────────────

  /// Finds an existing division with [name] in [clubId] or creates one.
  /// Returns the division id.
  Future<String> findOrCreateDivision({
    required String clubId,
    required String name,
  }) async {
    final existing = await supabase
        .from('divisions')
        .select('id')
        .eq('club_id', clubId)
        .ilike('name', name.trim())
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    // Get max display_order
    final maxOrder = await supabase
        .from('divisions')
        .select('display_order')
        .eq('club_id', clubId)
        .order('display_order', ascending: false)
        .limit(1)
        .maybeSingle();

    final nextOrder = ((maxOrder?['display_order'] as int?) ?? 0) + 1;

    final inserted = await supabase.from('divisions').insert({
      'club_id': clubId,
      'name': name.trim(),
      'display_order': nextOrder,
    }).select('id').single();

    return inserted['id'] as String;
  }

  /// Finds an existing team with [name] in [divisionId] or creates one.
  /// Returns the team id.
  Future<String> findOrCreateTeam({
    required String divisionId,
    required String name,
  }) async {
    final existing = await supabase
        .from('teams')
        .select('id')
        .eq('division_id', divisionId)
        .ilike('name', name.trim())
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final currentYear = DateTime.now().year.toString();
    final inserted = await supabase.from('teams').insert({
      'division_id': divisionId,
      'name': name.trim(),
      'season': currentYear,
    }).select('id').single();

    return inserted['id'] as String;
  }

  /// Imports [players] into [teamId].
  ///
  /// - Players with email: linked to existing profile or invited via Edge Function.
  /// - Players without email: inserted directly into pending_players with a
  ///   generated 8-char join code.
  /// - Division/team columns auto-create divisions and teams if needed.
  Future<ImportResult> importPlayers({
    required String teamId,
    required String clubId,
    required List<PlayerImportRow> players,
    void Function(int current, int total)? onProgress,
  }) async {
    int linkedCount = 0;
    int invitedCount = 0;
    int pendingCount = 0;
    int skippedCount = 0;
    final List<SkippedRow> skippedRows = [];
    final List<({String name, String joinCode})> playersWithCodes = [];

    // Cache division/team lookups to avoid repeated DB calls
    final divisionCache = <String, String>{}; // name → id
    final teamCache = <String, String>{}; // '$divisionId:$name' → id

    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) throw Exception('Not authenticated');

    for (int i = 0; i < players.length; i++) {
      final player = players[i];
      final rowNumber = i + 2;
      onProgress?.call(i + 1, players.length);

      try {
        // Resolve target team (default to passed teamId)
        String targetTeamId = teamId;

        if (player.division != null || player.team != null) {
          String? divisionId;

          if (player.division != null) {
            final divKey = player.division!.trim().toLowerCase();
            divisionId = divisionCache[divKey] ??
                await findOrCreateDivision(
                  clubId: clubId,
                  name: player.division!,
                );
            divisionCache[divKey] = divisionId;
          } else {
            // No division column — get division from default team
            final teamRow = await supabase
                .from('teams')
                .select('division_id')
                .eq('id', teamId)
                .maybeSingle();
            divisionId = teamRow?['division_id'] as String?;
          }

          if (player.team != null && divisionId != null) {
            final teamKey = '$divisionId:${player.team!.trim().toLowerCase()}';
            targetTeamId = teamCache[teamKey] ??
                await findOrCreateTeam(
                  divisionId: divisionId,
                  name: player.team!,
                );
            teamCache[teamKey] = targetTeamId;
          }
        }

        if (player.email != null && player.email!.isNotEmpty) {
          // ── Has email — existing invite/link flow ──────────────
          final existing = await supabase
              .from('profiles')
              .select('id')
              .eq('email', player.email!)
              .maybeSingle();

          if (existing != null) {
            final profileId = existing['id'] as String;
            final existingMembership = await supabase
                .from('team_memberships')
                .select('id')
                .eq('team_id', targetTeamId)
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
              'team_id': targetTeamId,
              'profile_id': profileId,
              'position': player.position,
              'jersey_number': player.jerseyNumber,
              'status': MembershipStatus.active.toJson(),
            });
            linkedCount++;
          } else {
            // Try Edge Function
            bool edgeFunctionSucceeded = false;
            try {
              final response = await supabase.functions.invoke(
                'send-invite',
                body: {
                  'email': player.email,
                  'fullName': player.fullName.isNotEmpty
                      ? player.fullName
                      : player.email,
                  'teamId': targetTeamId,
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
                    .eq('team_id', targetTeamId)
                    .eq('profile_id', profileId)
                    .maybeSingle();

                if (existingMembership == null) {
                  await supabase.from('team_memberships').insert({
                    'team_id': targetTeamId,
                    'profile_id': profileId,
                    'position': player.position,
                    'jersey_number': player.jerseyNumber,
                    'status': isNew
                        ? MembershipStatus.pending.toJson()
                        : MembershipStatus.active.toJson(),
                  });
                }
                edgeFunctionSucceeded = true;
                invitedCount++;
              }
            } catch (_) {}

            if (!edgeFunctionSucceeded) {
              // Fallback — pending_players with email
              final existingPending = await supabase
                  .from('pending_players')
                  .select('id')
                  .eq('team_id', targetTeamId)
                  .eq('email', player.email!)
                  .maybeSingle();

              if (existingPending != null) {
                skippedCount++;
                skippedRows.add(SkippedRow(
                  rowNumber: rowNumber,
                  email: player.email,
                  reason: 'Already pending',
                ));
                continue;
              }

              await supabase.from('pending_players').insert({
                'team_id': targetTeamId,
                'club_id': clubId,
                'full_name': player.fullName.isNotEmpty
                    ? player.fullName
                    : player.email,
                'email': player.email,
                'position': player.position,
                'jersey_number': player.jerseyNumber,
                'invited_by': currentUser.id,
              });
              invitedCount++;
            }
          }
        } else {
          // ── No email — create pending_players with join code ──
          final joinCode = generatePlayerJoinCode();

          await supabase.from('pending_players').insert({
            'team_id': targetTeamId,
            'club_id': clubId,
            'full_name': player.fullName,
            'position': player.position,
            'jersey_number': player.jerseyNumber,
            'join_code': joinCode,
            'invited_by': currentUser.id,
          });
          playersWithCodes.add((name: player.fullName, joinCode: joinCode));
          pendingCount++;
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

    return ImportResult(
      totalRows: players.length,
      successCount: linkedCount + invitedCount + pendingCount,
      linkedCount: linkedCount,
      invitedCount: invitedCount,
      pendingCount: pendingCount,
      skippedCount: skippedCount,
      skippedRows: skippedRows,
      playersWithCodes: playersWithCodes,
    );
  }

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

  Future<Profile?> getProfileById(String profileId) async {
    final data = await supabase
        .from('profiles')
        .select(
          'id, full_name, email, phone, avatar_url, role, club_id, '
          'push_token, availability_this_week, default_availability, '
          'created_at, updated_at',
        )
        .eq('id', profileId)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<PendingPlayer?> getPendingPlayerById(String pendingPlayerId) async {
    final data = await supabase
        .from('pending_players')
        .select()
        .eq('id', pendingPlayerId)
        .maybeSingle();

    if (data == null) return null;
    return PendingPlayer.fromJson(data);
  }

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

  Future<void> updateMembershipStatus({
    required String membershipId,
    required MembershipStatus status,
  }) async {
    await supabase
        .from('team_memberships')
        .update({'status': status.toJson()})
        .eq('id', membershipId);
  }

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

  Future<void> updateAvailability({
    required String profileId,
    required bool available,
  }) async {
    await supabase
        .from('profiles')
        .update({'availability_this_week': available})
        .eq('id', profileId);
  }

  Future<void> updateDefaultAvailability({
    required String profileId,
    required bool defaultAvailable,
  }) async {
    await supabase
        .from('profiles')
        .update({'default_availability': defaultAvailable})
        .eq('id', profileId);
  }

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
      return [];
    }
  }

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

  Future<void> deletePendingPlayer(String pendingPlayerId) async {
    await supabase
        .from('pending_players')
        .delete()
        .eq('id', pendingPlayerId);
  }

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
      debugPrint('send-invite not available for resend: $e');
    }
  }

  // ── Guardian link management ──────────────────────────────────

  Future<Profile?> searchProfileByEmail(String email) async {
    final data = await supabase
        .from('profiles')
        .select(
          'id, full_name, email, phone, avatar_url, role, club_id, '
          'push_token, availability_this_week, default_availability, '
          'created_at, updated_at',
        )
        .ilike('email', email.trim())
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<void> createGuardianLinkRequest({
    required String playerProfileId,
    required String guardianProfileId,
    required GuardianPermission permissionLevel,
  }) async {
    final existing = await supabase
        .from('guardian_links')
        .select('id')
        .eq('player_profile_id', playerProfileId)
        .eq('guardian_profile_id', guardianProfileId)
        .maybeSingle();

    if (existing != null) {
      throw Exception('This guardian is already linked to this player');
    }

    await supabase.from('guardian_links').insert({
      'player_profile_id': playerProfileId,
      'guardian_profile_id': guardianProfileId,
      'permission_level': permissionLevel.toJson(),
      'confirmed': false,
    });

    try {
      final playerData = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', playerProfileId)
          .maybeSingle();
      final playerName =
          (playerData?['full_name'] as String?) ?? 'a player';
      await const NotificationsRepository().createNotification(
        profileId: guardianProfileId,
        type: NotificationType.guardianRequest,
        title: 'Guardian link request',
        body:
            'You have been requested as a guardian for $playerName. Tap to review.',
        data: {},
      );
    } catch (_) {}
  }

  Future<void> confirmGuardianLink(String guardianLinkId) async {
    await supabase
        .from('guardian_links')
        .update({'confirmed': true})
        .eq('id', guardianLinkId)
        .eq('guardian_profile_id', supabase.auth.currentUser!.id);

    try {
      final linkData = await supabase
          .from('guardian_links')
          .select('player_profile_id')
          .eq('id', guardianLinkId)
          .maybeSingle();
      final playerProfileId = linkData?['player_profile_id'] as String?;
      if (playerProfileId != null) {
        final guardianId = supabase.auth.currentUser!.id;
        final guardianData = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', guardianId)
            .maybeSingle();
        final guardianName =
            (guardianData?['full_name'] as String?) ?? 'Your guardian';
        await const NotificationsRepository().createNotification(
          profileId: playerProfileId,
          type: NotificationType.guardianAccepted,
          title: 'Guardian link confirmed',
          body: '$guardianName has accepted your guardian request.',
          data: {},
        );
      }
    } catch (_) {}
  }

  Future<void> declineGuardianLink(String guardianLinkId) async {
    await supabase
        .from('guardian_links')
        .delete()
        .eq('id', guardianLinkId)
        .eq('guardian_profile_id', supabase.auth.currentUser!.id);
  }

  Future<void> removeGuardianLink(String guardianLinkId) async {
    await supabase
        .from('guardian_links')
        .delete()
        .eq('id', guardianLinkId);
  }

  Future<List<GuardianLink>> getPendingGuardianRequests() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await supabase
          .from('guardian_links')
          .select(
            'id, player_profile_id, guardian_profile_id, '
            'permission_level, confirmed, created_at, '
            'profiles!player_profile_id(full_name, avatar_url)',
          )
          .eq('guardian_profile_id', userId)
          .eq('confirmed', false);

      return (response as List).map((row) {
        return GuardianLink.fromJson(row as Map<String, dynamic>);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Team?> getTeamById(String teamId) async {
    final data = await supabase
        .from('teams')
        .select('id, division_id, name, season, created_at')
        .eq('id', teamId)
        .maybeSingle();

    if (data == null) return null;
    return Team.fromJson(data);
  }

  Future<void> updateTeamSquadSize({
    required String teamId,
    int? squadSize,
    int? playingXiSize,
  }) async {
    await supabase.from('teams').update({
      'squad_size': squadSize,
      'playing_xi_size': playingXiSize,
    }).eq('id', teamId);
  }

  Future<int> getActiveMemberCount(String clubId) async {
    final response = await supabase
        .from('profiles')
        .select('id')
        .eq('club_id', clubId)
        .neq('role', 'parent');

    return (response as List).length;
  }

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

  /// Returns all teams in [divisionId].
  Future<List<Team>> getTeamsForDivision(String divisionId) async {
    final response = await supabase
        .from('teams')
        .select('id, division_id, name, season, created_at')
        .eq('division_id', divisionId)
        .order('name');

    return (response as List)
        .map((row) => Team.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new division in [clubId].
  Future<void> createDivision({
    required String clubId,
    required String name,
    String? firstTeamName,
  }) async {
    final maxOrder = await supabase
        .from('divisions')
        .select('display_order')
        .eq('club_id', clubId)
        .order('display_order', ascending: false)
        .limit(1)
        .maybeSingle();

    final nextOrder = ((maxOrder?['display_order'] as int?) ?? 0) + 1;

    final divisionRow = await supabase.from('divisions').insert({
      'club_id': clubId,
      'name': name.trim(),
      'display_order': nextOrder,
    }).select('id').single();

    final divisionId = divisionRow['id'] as String;

    if (firstTeamName != null && firstTeamName.trim().isNotEmpty) {
      await supabase.from('teams').insert({
        'division_id': divisionId,
        'name': firstTeamName.trim(),
        'season': DateTime.now().year.toString(),
      });
    }
  }

  /// Creates a team in [divisionId].
  Future<void> createTeam({
    required String divisionId,
    required String name,
  }) async {
    await supabase.from('teams').insert({
      'division_id': divisionId,
      'name': name.trim(),
      'season': DateTime.now().year.toString(),
    });
  }

  /// Renames a division.
  Future<void> renameDivision({
    required String divisionId,
    required String name,
  }) async {
    await supabase
        .from('divisions')
        .update({'name': name.trim()})
        .eq('id', divisionId);
  }

  /// Renames a team.
  Future<void> renameTeam({
    required String teamId,
    required String name,
  }) async {
    await supabase
        .from('teams')
        .update({'name': name.trim()})
        .eq('id', teamId);
  }

  /// Deletes a division (and all teams in it via cascade).
  Future<void> deleteDivision(String divisionId) async {
    await supabase.from('divisions').delete().eq('id', divisionId);
  }

  /// Deletes a team.
  Future<void> deleteTeam(String teamId) async {
    await supabase.from('teams').delete().eq('id', teamId);
  }
}
