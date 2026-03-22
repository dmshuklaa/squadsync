import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/features/notifications/data/notifications_repository.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/fill_in_request.dart';
import 'package:squadsync/shared/models/fill_in_rule.dart';
import 'package:squadsync/shared/models/profile.dart';

class FillInRepository {
  const FillInRepository();

  Future<List<FillInRule>> getRules(String clubId) async {
    final response = await supabase
        .from('fill_in_rules')
        .select('''
          *,
          source_divisions:source_division_id(name),
          target_divisions:target_division_id(name)
        ''')
        .eq('club_id', clubId)
        .order('created_at');

    return (response as List)
        .map((row) => FillInRule.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> createRule({
    required String clubId,
    required String sourceDivisionId,
    required String targetDivisionId,
    int? minAge,
  }) async {
    await supabase.from('fill_in_rules').insert({
      'club_id': clubId,
      'source_division_id': sourceDivisionId,
      'target_division_id': targetDivisionId,
      'min_age': minAge,
    });
  }

  Future<void> toggleRule(String ruleId, bool enabled) async {
    await supabase
        .from('fill_in_rules')
        .update({'enabled': enabled})
        .eq('id', ruleId);
  }

  Future<void> deleteRule(String ruleId) async {
    await supabase.from('fill_in_rules').delete().eq('id', ruleId);
  }

  Future<void> updateFillInMode({
    required String clubId,
    required String mode,
  }) async {
    await supabase
        .from('clubs')
        .update({'fill_in_mode': mode})
        .eq('id', clubId);
  }

  Future<List<Profile>> getEligiblePlayers({
    required String clubId,
    required String targetDivisionId,
    required String eventId,
  }) async {
    // Check the club's fill-in mode
    final clubData = await supabase
        .from('clubs')
        .select('fill_in_mode')
        .eq('id', clubId)
        .maybeSingle();
    final isOpenMode = (clubData?['fill_in_mode'] as String?) == 'open';

    Set<String> allCandidateIds;

    if (isOpenMode) {
      // Open mode: all active members across all club teams are eligible
      final teamsResponse = await supabase
          .from('teams')
          .select('id, divisions!inner(club_id)')
          .eq('divisions.club_id', clubId);

      final teamIds = (teamsResponse as List)
          .map((t) => t['id'] as String)
          .toList();

      if (teamIds.isEmpty) return [];

      final membersResponse = await supabase
          .from('team_memberships')
          .select('profile_id')
          .inFilter('team_id', teamIds)
          .eq('status', 'active');

      allCandidateIds = (membersResponse as List)
          .map((r) => r['profile_id'] as String)
          .toSet();
    } else {
      // Restricted mode: source division IDs from enabled fill-in rules
      final rulesResponse = await supabase
          .from('fill_in_rules')
          .select('source_division_id')
          .eq('target_division_id', targetDivisionId)
          .eq('club_id', clubId)
          .eq('enabled', true);

      final sourceDivisionIds = (rulesResponse as List)
          .map((r) => r['source_division_id'] as String)
          .toList();

      if (sourceDivisionIds.isEmpty) return [];

      final teamsResponse = await supabase
          .from('teams')
          .select('id')
          .inFilter('division_id', sourceDivisionIds);

      final teamIds = (teamsResponse as List)
          .map((t) => t['id'] as String)
          .toList();

      if (teamIds.isEmpty) return [];

      final membersResponse = await supabase
          .from('team_memberships')
          .select('profile_id')
          .inFilter('team_id', teamIds)
          .eq('status', 'active');

      allCandidateIds = (membersResponse as List)
          .map((r) => r['profile_id'] as String)
          .toSet();
    }

    if (allCandidateIds.isEmpty) return [];

    // Already-rostered player IDs for this event
    final rosterResponse = await supabase
        .from('event_roster')
        .select('profile_id')
        .eq('event_id', eventId);
    final rosteredIds = (rosterResponse as List)
        .map((r) => r['profile_id'] as String)
        .toSet();

    // Players with a pending fill-in request for this event
    final pendingResponse = await supabase
        .from('fill_in_requests')
        .select('player_id')
        .eq('event_id', eventId)
        .eq('status', FillInRequestStatus.pending.toJson());
    final pendingIds = (pendingResponse as List)
        .map((r) => r['player_id'] as String)
        .toSet();

    // Filter out rostered/pending, then fetch available profiles
    final eligibleIds = allCandidateIds
        .where((id) => !rosteredIds.contains(id) && !pendingIds.contains(id))
        .toList();

    if (eligibleIds.isEmpty) return [];

    final profilesResponse = await supabase
        .from('profiles')
        .select()
        .inFilter('id', eligibleIds)
        .eq('availability_this_week', true);

    return (profilesResponse as List)
        .map((row) => Profile.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<int> getFillInCountThisSeason(
    String playerId,
    String clubId,
  ) async {
    final year = DateTime.now().year;
    final response = await supabase
        .from('fill_in_log')
        .select('id')
        .eq('player_id', playerId)
        .gte('created_at', '$year-01-01T00:00:00Z');

    return (response as List).length;
  }

  Future<FillInRequest> createRequest({
    required String eventId,
    required String playerId,
    required String requestingCoachId,
    String? positionNeeded,
  }) async {
    final data = await supabase
        .from('fill_in_requests')
        .insert({
          'event_id': eventId,
          'player_id': playerId,
          'requesting_coach_id': requestingCoachId,
          if (positionNeeded != null && positionNeeded.isNotEmpty)
            'position_needed': positionNeeded,
        })
        .select()
        .single();

    final request = FillInRequest.fromJson(data);

    // Notify player of the new fill-in request
    try {
      final eventData = await supabase
          .from('events')
          .select('title')
          .eq('id', eventId)
          .maybeSingle();
      final eventTitle = (eventData?['title'] as String?) ?? 'an event';
      await const NotificationsRepository().createNotification(
        profileId: playerId,
        type: NotificationType.fillInRequest,
        title: 'Fill-in request',
        body: 'You have been requested to fill in for $eventTitle',
        data: {'id': request.id},
      );
    } catch (_) {}

    return request;
  }

  Future<void> respondToRequest({
    required String requestId,
    required FillInRequestStatus status,
  }) async {
    // Fetch the request first so we can use its fields
    final requestData = await supabase
        .from('fill_in_requests')
        .select()
        .eq('id', requestId)
        .single();

    await supabase.from('fill_in_requests').update({
      'status': status.toJson(),
      'responded_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);

    if (status == FillInRequestStatus.accepted) {
      final eventId = requestData['event_id'] as String;
      final playerId = requestData['player_id'] as String;

      // Get player's division for the log
      final memberData = await supabase
          .from('team_memberships')
          .select('teams!inner(division_id)')
          .eq('profile_id', playerId)
          .eq('status', 'active')
          .limit(1)
          .maybeSingle();

      final homeDivisionId = memberData != null
          ? (memberData['teams'] as Map<String, dynamic>)['division_id']
              as String
          : null;

      // Add to event_roster
      await supabase.from('event_roster').upsert({
        'event_id': eventId,
        'profile_id': playerId,
        'is_fill_in': true,
      }, onConflict: 'event_id,profile_id');

      // Auto-RSVP the fill-in player as going
      await supabase.from('event_rsvps').upsert({
        'event_id': eventId,
        'profile_id': playerId,
        'status': 'going',
        'responded_at': DateTime.now().toIso8601String(),
      }, onConflict: 'event_id,profile_id');

      // Insert fill_in_log
      if (homeDivisionId != null) {
        final eventData = await supabase
            .from('events')
            .select('starts_at, title, team_id, teams!inner(division_id)')
            .eq('id', eventId)
            .single();

        final targetDivisionId =
            (eventData['teams'] as Map<String, dynamic>)['division_id']
                as String;

        await supabase.from('fill_in_log').insert({
          'fill_in_request_id': requestId,
          'player_id': playerId,
          'home_division_id': homeDivisionId,
          'target_division_id': targetDivisionId,
          'event_id': eventId,
          'event_date': (eventData['starts_at'] as String).substring(0, 10),
          'game_name': eventData['title'] as String,
        });

        // Notify the requesting coach that the player accepted
        try {
          final requestingCoachId =
              requestData['requesting_coach_id'] as String;
          final playerData = await supabase
              .from('profiles')
              .select('full_name')
              .eq('id', playerId)
              .maybeSingle();
          final playerName =
              (playerData?['full_name'] as String?) ?? 'The player';
          final gameTitle = eventData['title'] as String;
          await const NotificationsRepository().createNotification(
            profileId: requestingCoachId,
            type: NotificationType.fillInAccepted,
            title: 'Fill-in accepted',
            body: '$playerName has accepted your fill-in request for $gameTitle',
            data: {'id': requestId},
          );
        } catch (_) {}
      }
    }

    if (status == FillInRequestStatus.declined) {
      final eventId = requestData['event_id'] as String;
      final playerId = requestData['player_id'] as String;

      // Auto-RSVP the declined fill-in player as not going
      await supabase.from('event_rsvps').upsert({
        'event_id': eventId,
        'profile_id': playerId,
        'status': 'not_going',
        'responded_at': DateTime.now().toIso8601String(),
      }, onConflict: 'event_id,profile_id');
    }
  }

  Future<List<FillInRequest>> getPendingRequestsForPlayer(
    String playerId,
  ) async {
    final response = await supabase
        .from('fill_in_requests')
        .select('''
          *,
          players:player_id(full_name, avatar_url),
          events:event_id(title),
          coaches:requesting_coach_id(full_name)
        ''')
        .eq('player_id', playerId)
        .eq('status', FillInRequestStatus.pending.toJson())
        .order('requested_at', ascending: false);

    return (response as List)
        .map((row) => FillInRequest.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<FillInRequest?> getRequestById(String requestId) async {
    final data = await supabase
        .from('fill_in_requests')
        .select('''
          *,
          players:player_id(full_name, avatar_url),
          events:event_id(title, starts_at),
          coaches:requesting_coach_id(full_name)
        ''')
        .eq('id', requestId)
        .maybeSingle();

    if (data == null) return null;
    return FillInRequest.fromJson(data);
  }
}
