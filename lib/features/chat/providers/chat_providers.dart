import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:squadsync/features/chat/data/chat_repository.dart';

part 'chat_providers.g.dart';

@riverpod
ChatRepository chatRepository(ChatRepositoryRef ref) {
  return const ChatRepository();
}
