import 'package:squadsync/shared/models/enums.dart';

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.profileId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String profileId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  bool get isFillInRequest => type == NotificationType.fillInRequest;
  bool get isGuardianRequest => type == NotificationType.guardianRequest;
  String? get relatedId => data['id'] as String?;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      type: NotificationType.fromString(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  NotificationItem copyWith({bool? read}) {
    return NotificationItem(
      id: id,
      profileId: profileId,
      type: type,
      title: title,
      body: body,
      data: data,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }
}
