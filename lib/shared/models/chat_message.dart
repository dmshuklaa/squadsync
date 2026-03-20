class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.teamId,
    required this.senderId,
    required this.content,
    required this.edited,
    required this.deleted,
    required this.createdAt,
    required this.updatedAt,
    this.senderFullName,
    this.senderAvatarUrl,
  });

  final String id;
  final String teamId;
  final String senderId;
  final String content;
  final bool edited;
  final bool deleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? senderFullName;
  final String? senderAvatarUrl;

  bool get isDeleted => deleted;

  String get displayContent =>
      deleted ? 'This message was deleted' : content;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Handles both joined (profiles nested map) and flat (from stream asyncMap)
    final profiles = json['profiles'] as Map<String, dynamic>?;
    return ChatMessage(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      edited: json['edited'] as bool? ?? false,
      deleted: json['deleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      senderFullName: profiles?['full_name'] as String? ??
          json['sender_full_name'] as String?,
      senderAvatarUrl: profiles?['avatar_url'] as String? ??
          json['sender_avatar_url'] as String?,
    );
  }

  ChatMessage copyWith({String? content, bool? edited, bool? deleted}) {
    return ChatMessage(
      id: id,
      teamId: teamId,
      senderId: senderId,
      content: content ?? this.content,
      edited: edited ?? this.edited,
      deleted: deleted ?? this.deleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
      senderFullName: senderFullName,
      senderAvatarUrl: senderAvatarUrl,
    );
  }
}
