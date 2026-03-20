import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/notification_item.dart';

class NotificationsRepository {
  const NotificationsRepository();

  Future<List<NotificationItem>> getNotifications(String profileId) async {
    final response = await supabase
        .from('notifications')
        .select()
        .eq('profile_id', profileId)
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List)
        .map((row) => NotificationItem.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount(String profileId) async {
    final response = await supabase
        .from('notifications')
        .select()
        .eq('profile_id', profileId)
        .eq('read', false);

    return (response as List).length;
  }

  Future<void> markAsRead(String notificationId) async {
    // ignore: avoid_print
    print('[NotifRepo] markAsRead: $notificationId');
    // ignore: avoid_print
    print('[NotifRepo] currentUser: ${supabase.auth.currentUser?.id}');
    try {
      await supabase
          .from('notifications')
          .update({'read': true})
          .eq('id', notificationId)
          .eq('profile_id', supabase.auth.currentUser!.id);
      // ignore: avoid_print
      print('[NotifRepo] markAsRead success');
    } catch (e) {
      // ignore: avoid_print
      print('[NotifRepo] markAsRead error: $e');
    }
  }

  Future<void> markAllAsRead(String profileId) async {
    await supabase
        .from('notifications')
        .update({'read': true})
        .eq('profile_id', profileId)
        .eq('read', false);
  }

  Future<void> createNotification({
    required String profileId,
    required NotificationType type,
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
  }) async {
    await supabase.from('notifications').insert({
      'profile_id': profileId,
      'type': type.toJson(),
      'title': title,
      'body': body,
      'data': data,
    });
  }
}
