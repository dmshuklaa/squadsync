import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:squadsync/features/events/data/events_repository.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/event.dart';
import 'package:squadsync/shared/models/event_roster_entry.dart';
import 'package:squadsync/shared/models/event_rsvp.dart';

part 'events_providers.g.dart';

// ── Repository ────────────────────────────────────────────────

@riverpod
EventsRepository eventsRepository(EventsRepositoryRef ref) {
  return const EventsRepository();
}

// ── Upcoming events (for home screen) ────────────────────────

/// Returns events starting from now for all teams the current user belongs to.
@riverpod
Future<List<Event>> upcomingEvents(UpcomingEventsRef ref) async {
  final teams = await ref.watch(userTeamsProvider.future);
  if (teams.isEmpty) return [];

  final repo = ref.watch(eventsRepositoryProvider);
  final now = DateTime.now();

  final futures = teams.map(
    (team) => repo.getUpcomingEvents(teamId: team.id, from: now),
  );

  final results = await Future.wait(futures);
  final all = results.expand((list) => list).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  return all;
}

// ── Events for a single team ──────────────────────────────────

@riverpod
Future<List<Event>> teamEvents(
  TeamEventsRef ref,
  String teamId,
) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getEventsForTeam(teamId);
}

// ── Single event ──────────────────────────────────────────────

@riverpod
Future<Event?> eventDetail(
  EventDetailRef ref,
  String eventId,
) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getEventById(eventId);
}

// ── RSVPs for an event ────────────────────────────────────────

@riverpod
Future<List<EventRsvp>> eventRsvps(
  EventRsvpsRef ref,
  String eventId,
) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getRsvpsForEvent(eventId);
}

// ── Current user's RSVP for an event ─────────────────────────

@riverpod
Future<EventRsvp?> myRsvp(
  MyRsvpRef ref,
  String eventId,
) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getMyRsvp(eventId);
}

// ── RSVP counts for an event ──────────────────────────────────

@riverpod
Future<Map<RsvpStatus, int>> rsvpCounts(
  RsvpCountsRef ref,
  String eventId,
) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getRsvpCounts(eventId);
}

// ── Event roster ──────────────────────────────────────────────

@riverpod
Future<List<EventRosterEntry>> eventRoster(
  EventRosterRef ref,
  String eventId,
) async {
  final repo = ref.watch(eventsRepositoryProvider);
  return repo.getEventRoster(eventId);
}

// ── RSVP mutation notifier ────────────────────────────────────

@riverpod
class RsvpNotifier extends _$RsvpNotifier {
  @override
  FutureOr<void> build() {}

  Future<void> upsertRsvp({
    required String eventId,
    required RsvpStatus status,
  }) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(eventsRepositoryProvider);
      await repo.upsertRsvp(eventId: eventId, status: status);
      ref.invalidate(myRsvpProvider(eventId));
      ref.invalidate(eventRsvpsProvider(eventId));
      ref.invalidate(rsvpCountsProvider(eventId));
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
