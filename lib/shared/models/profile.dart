import 'package:squadsync/shared/models/enums.dart';

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    required this.role,
    this.clubId,
    this.pushToken,
    required this.availabilityThisWeek,
    required this.defaultAvailability,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final UserRole role;
  final String? clubId;
  final String? pushToken;
  final bool availabilityThisWeek;
  final bool defaultAvailability;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: UserRole.fromString(json['role'] as String),
      clubId: json['club_id'] as String?,
      pushToken: json['push_token'] as String?,
      availabilityThisWeek: json['availability_this_week'] as bool? ?? true,
      defaultAvailability: json['default_availability'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'role': role.toJson(),
      'club_id': clubId,
      'push_token': pushToken,
      'availability_this_week': availabilityThisWeek,
      'default_availability': defaultAvailability,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Profile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
    UserRole? role,
    String? clubId,
    String? pushToken,
    bool? availabilityThisWeek,
    bool? defaultAvailability,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Profile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      clubId: clubId ?? this.clubId,
      pushToken: pushToken ?? this.pushToken,
      availabilityThisWeek: availabilityThisWeek ?? this.availabilityThisWeek,
      defaultAvailability: defaultAvailability ?? this.defaultAvailability,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
