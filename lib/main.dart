import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:squadsync/core/router/app_router.dart';
import 'package:squadsync/core/services/push_notification_service.dart';
import 'package:squadsync/core/theme/app_theme.dart';

// TODO: Run `flutterfire configure` to generate firebase_options.dart,
//       then uncomment the import below and the options: line in main().
// import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Firebase — initialise gracefully until `flutterfire configure` is run
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp(
      // TODO: Uncomment after running `flutterfire configure`:
      // options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
  } catch (e) {
    debugPrint('Firebase not configured — push notifications disabled: $e');
  }

  Object? initError;
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
    );
  } catch (e) {
    initError = e;
  }

  // Initialise push notifications only when Firebase is ready and user is signed in
  if (firebaseReady && Supabase.instance.client.auth.currentUser != null) {
    try {
      await PushNotificationService(Supabase.instance.client).initialize();
    } catch (e) {
      debugPrint('PushNotificationService init failed: $e');
    }
  }

  runApp(
    ProviderScope(
      child: initError != null
          ? _ErrorApp(error: initError)
          : const SquadSyncApp(),
    ),
  );
}

class SquadSyncApp extends ConsumerWidget {
  const SquadSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'SquadSync',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}

/// Shown when Supabase initialisation fails so the app doesn't crash silently.
class _ErrorApp extends StatelessWidget {
  const _ErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Supabase init failed:\n$error',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
