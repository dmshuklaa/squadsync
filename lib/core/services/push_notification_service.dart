import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// TODO: Import generated firebase_options.dart after running `flutterfire configure`
// import 'package:squadsync/firebase_options.dart';

/// Handles FCM token registration and foreground/background message routing.
///
/// Usage:
///   await PushNotificationService(Supabase.instance.client).initialize();
///
/// Prerequisites (not yet configured):
///   1. Run `flutterfire configure` to generate firebase_options.dart
///   2. Add google-services.json to android/app/
///   3. Add GoogleService-Info.plist to ios/Runner/
class PushNotificationService {
  PushNotificationService(this._supabase);

  final SupabaseClient _supabase;

  Future<void> initialize() async {
    final messaging = FirebaseMessaging.instance;

    // Request notification permissions
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get and save FCM token
    final token = await messaging.getToken();
    if (token != null) {
      await _saveFcmToken(token);
    }

    // Refresh token when it changes
    messaging.onTokenRefresh.listen(_saveFcmToken);

    // Handle messages while the app is in the foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was launched from a terminated-state notification tap
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _handleNotificationTap(initial);
    }
  }

  Future<void> _saveFcmToken(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('profiles')
          .update({'fcm_token': token}).eq('id', userId);
    } catch (e) {
      debugPrint('[PushNotif] Failed to save FCM token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // TODO: Show a local notification using flutter_local_notifications
    // when a push arrives while the app is open.
    debugPrint('[PushNotif] Foreground message: ${message.notification?.title}');
  }

  void _handleNotificationTap(RemoteMessage message) {
    // TODO: Navigate to the relevant screen based on data payload.
    // Use a GlobalKey<NavigatorState> or a stream to pass the route
    // to the router after the widget tree is ready.
    //
    // Example payload: {'type': 'fill_in_request', 'id': '<requestId>'}
    final type = message.data['type'];
    final id = message.data['id'];
    debugPrint('[PushNotif] Notification tapped: type=$type id=$id');
  }
}
