import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/auth/screens/sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  Object? initError;
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
    );
  } catch (e) {
    initError = e;
  }

  runApp(
    ProviderScope(
      child: initError != null
          ? _ErrorApp(error: initError)
          : const SquadSyncApp(),
    ),
  );
}

class SquadSyncApp extends StatelessWidget {
  const SquadSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SquadSync',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const SignInScreen(),
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
