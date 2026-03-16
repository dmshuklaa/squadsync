import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/shared/models/division.dart';
import 'package:squadsync/shared/models/enums.dart';
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
