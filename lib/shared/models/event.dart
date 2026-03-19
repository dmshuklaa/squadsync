import 'package:squadsync/shared/models/enums.dart';

class Event {
  const Event({
    required this.id,
    required this.teamId,
    required this.createdBy,
    required this.title,
    required this.eventType,
    required this.status,
    required this.startsAt,
    this.endsAt,
    this.location,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String teamId;
  final String createdBy;
  final String title;
  final EventType eventType;
  final EventStatus status;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? location;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      createdBy: json['created_by'] as String,
      title: json['title'] as String,
      eventType: EventType.fromString(json['event_type'] as String),
      status: EventStatus.fromString(json['status'] as String),
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team_id': teamId,
      'created_by': createdBy,
      'title': title,
      'event_type': eventType.toJson(),
      'status': status.toJson(),
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'location': location,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Event copyWith({
    String? id,
    String? teamId,
    String? createdBy,
    String? title,
    EventType? eventType,
    EventStatus? status,
    DateTime? startsAt,
    DateTime? endsAt,
    String? location,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      eventType: eventType ?? this.eventType,
      status: status ?? this.status,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
