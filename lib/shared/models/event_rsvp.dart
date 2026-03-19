import 'package:squadsync/shared/models/enums.dart';

class EventRsvp {
  const EventRsvp({
    required this.id,
    required this.eventId,
    required this.profileId,
    required this.status,
    required this.respondedAt,
    required this.createdAt,
  });

  final String id;
  final String eventId;
  final String profileId;
  final RsvpStatus status;
  final DateTime respondedAt;
  final DateTime createdAt;

  factory EventRsvp.fromJson(Map<String, dynamic> json) {
    return EventRsvp(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      profileId: json['profile_id'] as String,
      status: RsvpStatus.fromString(json['status'] as String),
      respondedAt: DateTime.parse(json['responded_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'profile_id': profileId,
      'status': status.toJson(),
      'responded_at': respondedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
