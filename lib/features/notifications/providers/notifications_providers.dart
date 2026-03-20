import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/features/fill_in/data/fill_in_repository.dart';
import 'package:squadsync/features/notifications/data/notifications_repository.dart';
import 'package:squadsync/shared/models/fill_in_request.dart';
import 'package:squadsync/shared/models/notification_item.dart';

part 'notifications_providers.g.dart';

@riverpod
NotificationsRepository notificationsRepository(
    NotificationsRepositoryRef ref) {
  return const NotificationsRepository();
}

@riverpod
Future<List<NotificationItem>> notifications(NotificationsRef ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];
  return ref.watch(notificationsRepositoryProvider).getNotifications(userId);
}

@riverpod
Future<int> unreadCount(UnreadCountRef ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return 0;
  return ref.watch(notificationsRepositoryProvider).getUnreadCount(userId);
}

/// Pending fill-in requests for the currently logged-in player.
/// Resolves the user ID internally so callers don't need to pass it.
@riverpod
Future<List<FillInRequest>> myPendingFillInRequests(
  MyPendingFillInRequestsRef ref,
) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return [];
  return const FillInRepository().getPendingRequestsForPlayer(userId);
}
