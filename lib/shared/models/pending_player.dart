class PendingPlayer {
  const PendingPlayer({
    required this.id,
    required this.teamId,
    required this.clubId,
    required this.fullName,
    required this.email,
    this.phone,
    this.position,
    this.jerseyNumber,
    this.invitedBy,
    required this.createdAt,
  });

  final String id;
  final String teamId;
  final String clubId;
  final String fullName;
  final String email;
  final String? phone;
  final String? position;
  final int? jerseyNumber;
  final String? invitedBy;
  final DateTime createdAt;

  factory PendingPlayer.fromJson(Map<String, dynamic> json) {
    return PendingPlayer(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      clubId: json['club_id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      position: json['position'] as String?,
      jerseyNumber: json['jersey_number'] as int?,
      invitedBy: json['invited_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team_id': teamId,
      'club_id': clubId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'position': position,
      'jersey_number': jerseyNumber,
      'invited_by': invitedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PendingPlayer copyWith({
    String? id,
    String? teamId,
    String? clubId,
    String? fullName,
    String? email,
    String? phone,
    String? position,
    int? jerseyNumber,
    String? invitedBy,
    DateTime? createdAt,
  }) {
    return PendingPlayer(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      clubId: clubId ?? this.clubId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      position: position ?? this.position,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      invitedBy: invitedBy ?? this.invitedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
