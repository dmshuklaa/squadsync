import 'package:squadsync/shared/models/enums.dart';

class GuardianLink {
  const GuardianLink({
    required this.id,
    required this.playerProfileId,
    required this.guardianProfileId,
    required this.permissionLevel,
    required this.confirmed,
    required this.createdAt,
  });

  final String id;
  final String playerProfileId;
  final String guardianProfileId;
  final GuardianPermission permissionLevel;
  final bool confirmed;
  final DateTime createdAt;

  factory GuardianLink.fromJson(Map<String, dynamic> json) {
    return GuardianLink(
      id: json['id'] as String,
      playerProfileId: json['player_profile_id'] as String,
      guardianProfileId: json['guardian_profile_id'] as String,
      permissionLevel:
          GuardianPermission.fromString(json['permission_level'] as String),
      confirmed: json['confirmed'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player_profile_id': playerProfileId,
      'guardian_profile_id': guardianProfileId,
      'permission_level': permissionLevel.toJson(),
      'confirmed': confirmed,
      'created_at': createdAt.toIso8601String(),
    };
  }

  GuardianLink copyWith({
    String? id,
    String? playerProfileId,
    String? guardianProfileId,
    GuardianPermission? permissionLevel,
    bool? confirmed,
    DateTime? createdAt,
  }) {
    return GuardianLink(
      id: id ?? this.id,
      playerProfileId: playerProfileId ?? this.playerProfileId,
      guardianProfileId: guardianProfileId ?? this.guardianProfileId,
      permissionLevel: permissionLevel ?? this.permissionLevel,
      confirmed: confirmed ?? this.confirmed,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
