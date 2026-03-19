import 'package:squadsync/shared/models/enums.dart';

class FillInRequest {
  const FillInRequest({
    required this.id,
    required this.eventId,
    required this.requestingCoachId,
    required this.playerId,
    this.positionNeeded,
    required this.status,
    required this.requestedAt,
    this.respondedAt,
    this.playerFullName,
    this.playerAvatarUrl,
    this.eventTitle,
    this.coachFullName,
  });

  final String id;
  final String eventId;
  final String requestingCoachId;
  final String playerId;
  final String? positionNeeded;
  final FillInRequestStatus status;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final String? playerFullName;
  final String? playerAvatarUrl;
  final String? eventTitle;
  final String? coachFullName;

  factory FillInRequest.fromJson(Map<String, dynamic> json) {
    final player = json['players'] as Map<String, dynamic>?;
    final event = json['events'] as Map<String, dynamic>?;
    final coach = json['coaches'] as Map<String, dynamic>?;
    return FillInRequest(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      requestingCoachId: json['requesting_coach_id'] as String,
      playerId: json['player_id'] as String,
      positionNeeded: json['position_needed'] as String?,
      status: FillInRequestStatus.fromString(json['status'] as String),
      requestedAt: DateTime.parse(json['requested_at'] as String),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String)
          : null,
      playerFullName: player?['full_name'] as String?,
      playerAvatarUrl: player?['avatar_url'] as String?,
      eventTitle: event?['title'] as String?,
      coachFullName: coach?['full_name'] as String?,
    );
  }

  FillInRequest copyWith({
    String? id,
    String? eventId,
    String? requestingCoachId,
    String? playerId,
    String? positionNeeded,
    FillInRequestStatus? status,
    DateTime? requestedAt,
    DateTime? respondedAt,
    String? playerFullName,
    String? playerAvatarUrl,
    String? eventTitle,
    String? coachFullName,
  }) =>
      FillInRequest(
        id: id ?? this.id,
        eventId: eventId ?? this.eventId,
        requestingCoachId: requestingCoachId ?? this.requestingCoachId,
        playerId: playerId ?? this.playerId,
        positionNeeded: positionNeeded ?? this.positionNeeded,
        status: status ?? this.status,
        requestedAt: requestedAt ?? this.requestedAt,
        respondedAt: respondedAt ?? this.respondedAt,
        playerFullName: playerFullName ?? this.playerFullName,
        playerAvatarUrl: playerAvatarUrl ?? this.playerAvatarUrl,
        eventTitle: eventTitle ?? this.eventTitle,
        coachFullName: coachFullName ?? this.coachFullName,
      );
}
