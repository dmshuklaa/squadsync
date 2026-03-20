import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:squadsync/features/chat/data/chat_repository.dart';
import 'package:squadsync/shared/models/chat_message.dart';

part 'chat_providers.g.dart';

@riverpod
ChatRepository chatRepository(ChatRepositoryRef ref) {
  return const ChatRepository();
}

@riverpod
Stream<List<ChatMessage>> chatMessages(
  ChatMessagesRef ref,
  String teamId,
) {
  return ref.read(chatRepositoryProvider).watchMessages(teamId);
}
