import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/event.dart';
import 'package:squadsync/shared/models/event_rsvp.dart';

class EventsRepository {
  const EventsRepository();

  /// Returns scheduled events for [teamId] starting from [from] (inclusive),
  /// ordered ascending by starts_at.
  Future<List<Event>> getUpcomingEvents({
    required String teamId,
    required DateTime from,
    int limit = 20,
  }) async {
    final response = await supabase
        .from('events')
        .select()
        .eq('team_id', teamId)
        .eq('status', EventStatus.scheduled.toJson())
        .gte('starts_at', from.toIso8601String())
        .order('starts_at')
        .limit(limit);

    return (response as List)
        .map((row) => Event.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Returns all events for [teamId] ordered by starts_at descending.
  Future<List<Event>> getEventsForTeam(String teamId) async {
    final response = await supabase
        .from('events')
        .select()
        .eq('team_id', teamId)
        .order('starts_at', ascending: false);

    return (response as List)
        .map((row) => Event.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches a single [Event] by [eventId]. Returns null if not found.
  Future<Event?> getEventById(String eventId) async {
    final data = await supabase
        .from('events')
        .select()
        .eq('id', eventId)
        .maybeSingle();

    if (data == null) return null;
    return Event.fromJson(data);
  }

  /// Creates a new event. Returns the created [Event].
  Future<Event> createEvent({
    required String teamId,
    required String title,
    required EventType eventType,
    required DateTime startsAt,
    DateTime? endsAt,
    String? location,
    String? notes,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final data = await supabase
        .from('events')
        .insert({
          'team_id': teamId,
          'created_by': userId,
          'title': title,
          'event_type': eventType.toJson(),
          'status': EventStatus.scheduled.toJson(),
          'starts_at': startsAt.toIso8601String(),
          if (endsAt != null) 'ends_at': endsAt.toIso8601String(),
          if (location != null && location.isNotEmpty) 'location': location,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        })
        .select()
        .single();

    return Event.fromJson(data);
  }

  /// Updates the status of an event (e.g. cancelled, completed).
  Future<void> updateEventStatus({
    required String eventId,
    required EventStatus status,
  }) async {
    await supabase
        .from('events')
        .update({'status': status.toJson()})
        .eq('id', eventId);
  }

  /// Returns all RSVPs for [eventId].
  Future<List<EventRsvp>> getRsvpsForEvent(String eventId) async {
    final response = await supabase
        .from('event_rsvps')
        .select()
        .eq('event_id', eventId);

    return (response as List)
        .map((row) => EventRsvp.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Returns the current user's RSVP for [eventId], or null if none.
  Future<EventRsvp?> getMyRsvp(String eventId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await supabase
        .from('event_rsvps')
        .select()
        .eq('event_id', eventId)
        .eq('profile_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return EventRsvp.fromJson(data);
  }

  /// Upserts the current user's RSVP for [eventId].
  Future<void> upsertRsvp({
    required String eventId,
    required RsvpStatus status,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    await supabase.from('event_rsvps').upsert({
      'event_id': eventId,
      'profile_id': userId,
      'status': status.toJson(),
      'responded_at': DateTime.now().toIso8601String(),
    }, onConflict: 'event_id,profile_id');
  }
}
