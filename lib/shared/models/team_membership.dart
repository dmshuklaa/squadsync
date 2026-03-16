import 'package:squadsync/shared/models/enums.dart';

class TeamMembership {
  const TeamMembership({
    required this.id,
    required this.teamId,
    required this.profileId,
    this.position,
    this.jerseyNumber,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String teamId;
  final String profileId;
  final String? position;
  final int? jerseyNumber;
  final MembershipStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TeamMembership.fromJson(Map<String, dynamic> json) {
    return TeamMembership(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      profileId: json['profile_id'] as String,
      position: json['position'] as String?,
      jerseyNumber: json['jersey_number'] as int?,
      status: MembershipStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team_id': teamId,
      'profile_id': profileId,
      'position': position,
      'jersey_number': jerseyNumber,
      'status': status.toJson(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  TeamMembership copyWith({
    String? id,
    String? teamId,
    String? profileId,
    String? position,
    int? jerseyNumber,
    MembershipStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeamMembership(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      profileId: profileId ?? this.profileId,
      position: position ?? this.position,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
