class EventRosterEntry {
  const EventRosterEntry({
    required this.id,
    required this.eventId,
    required this.profileId,
    required this.isFillIn,
    this.homeDivisionId,
    required this.addedAt,
    this.profileFullName,
    this.profileAvatarUrl,
  });

  final String id;
  final String eventId;
  final String profileId;
  final bool isFillIn;
  // Not stored in DB — placeholder for fill-in eligibility (always null for now)
  final String? homeDivisionId;
  // Maps to created_at in the event_roster table
  final DateTime addedAt;
  final String? profileFullName;
  final String? profileAvatarUrl;

  factory EventRosterEntry.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return EventRosterEntry(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      profileId: json['profile_id'] as String,
      isFillIn: json['is_fill_in'] as bool? ?? false,
      homeDivisionId: json['home_division_id'] as String?,
      addedAt: DateTime.parse(json['created_at'] as String),
      profileFullName: profile?['full_name'] as String?,
      profileAvatarUrl: profile?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_id': eventId,
        'profile_id': profileId,
        'is_fill_in': isFillIn,
        'home_division_id': homeDivisionId,
        'added_at': addedAt.toIso8601String(),
      };

  EventRosterEntry copyWith({
    String? id,
    String? eventId,
    String? profileId,
    bool? isFillIn,
    String? homeDivisionId,
    DateTime? addedAt,
    String? profileFullName,
    String? profileAvatarUrl,
  }) =>
      EventRosterEntry(
        id: id ?? this.id,
        eventId: eventId ?? this.eventId,
        profileId: profileId ?? this.profileId,
        isFillIn: isFillIn ?? this.isFillIn,
        homeDivisionId: homeDivisionId ?? this.homeDivisionId,
        addedAt: addedAt ?? this.addedAt,
        profileFullName: profileFullName ?? this.profileFullName,
        profileAvatarUrl: profileAvatarUrl ?? this.profileAvatarUrl,
      );
}
