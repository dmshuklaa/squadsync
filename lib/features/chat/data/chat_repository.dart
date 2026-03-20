import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/shared/models/chat_message.dart';

class ChatRepository {
  const ChatRepository();

  Future<List<ChatMessage>> getMessages(
    String teamId, {
    int limit = 50,
    String? beforeId,
  }) async {
    // Resolve cursor timestamp before building the filter chain
    // (filters must precede .order()/.limit() in the builder)
    String? beforeTimestamp;
    if (beforeId != null) {
      final cursor = await supabase
          .from('chat_messages')
          .select('created_at')
          .eq('id', beforeId)
          .maybeSingle();
      beforeTimestamp = cursor?['created_at'] as String?;
    }

    var filterQuery = supabase
        .from('chat_messages')
        .select('*, profiles!sender_id(full_name, avatar_url)')
        .eq('team_id', teamId);

    if (beforeTimestamp != null) {
      filterQuery = filterQuery.lt('created_at', beforeTimestamp);
    }

    final response = await filterQuery
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((row) => ChatMessage.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendMessage({
    required String teamId,
    required String senderId,
    required String content,
  }) async {
    final data = await supabase
        .from('chat_messages')
        .insert({
          'team_id': teamId,
          'sender_id': senderId,
          'content': content,
        })
        .select('*, profiles!sender_id(full_name, avatar_url)')
        .single();

    return ChatMessage.fromJson(data);
  }

  Future<void> editMessage({
    required String messageId,
    required String content,
  }) async {
    await supabase
        .from('chat_messages')
        .update({'content': content, 'edited': true}).eq('id', messageId);
  }

  Future<void> deleteMessage(String messageId) async {
    await supabase.from('chat_messages').update({
      'deleted': true,
      'content': '[deleted]',
    }).eq('id', messageId);
  }
}
