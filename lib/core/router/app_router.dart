import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/features/auth/screens/forgot_password_screen.dart';
import 'package:squadsync/features/auth/screens/sign_in_screen.dart';
import 'package:squadsync/features/auth/screens/sign_up_screen.dart';
import 'package:squadsync/features/events/screens/home_screen.dart';
import 'package:squadsync/features/notifications/screens/notifications_screen.dart';
import 'package:squadsync/features/onboarding/screens/onboarding_screen.dart';
import 'package:squadsync/features/profile/screens/profile_screen.dart';
import 'package:squadsync/features/roster/screens/roster_list_screen.dart';
import 'package:squadsync/shared/widgets/bottom_nav_shell.dart';

part 'app_router.g.dart';

// ── Named route paths ────────────────────────────────────────
const String kSignInRoute = '/sign-in';
const String kSignUpRoute = '/sign-up';
const String kForgotPasswordRoute = '/forgot-password';
const String kOnboardingRoute = '/onboarding';
const String kHomeRoute = '/home';
const String kRosterRoute = '/roster';
const String kRosterAddPlayerRoute = '/roster/add-player';
const String kPlayerProfileRoute = '/roster/player/:id';
const String kNotificationsRoute = '/notifications';
const String kProfileRoute = '/profile';

// ── Auth-aware ChangeNotifier for GoRouter refreshListenable ─

/// Tracks the current [Session] and the user's [clubId] so GoRouter can
/// redirect without any async work inside the redirect callback.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    _session = supabase.auth.currentSession;
    _subscription = supabase.auth.onAuthStateChange.listen(_onAuthStateChange);
    if (_session != null) _fetchClubId();
  }

  Session? _session;
  Session? get session => _session;

  String? _clubId;
  String? get clubId => _clubId;

  late final StreamSubscription<AuthState> _subscription;

  void _onAuthStateChange(AuthState authState) {
    _session = authState.session;
    if (_session != null) {
      _fetchClubId();
    } else {
      _clubId = null;
      notifyListeners();
    }
  }

  Future<void> _fetchClubId() async {
    try {
      final data = await supabase
          .from('profiles')
          .select('club_id')
          .eq('id', _session!.user.id)
          .maybeSingle();
      _clubId = data?['club_id'] as String?;
    } catch (_) {
      _clubId = null;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// ── Router provider ──────────────────────────────────────────

@Riverpod(keepAlive: true)
GoRouter appRouter(AppRouterRef ref) {
  final notifier = _AuthChangeNotifier();
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation:
        supabase.auth.currentSession != null ? kHomeRoute : kSignInRoute,
    refreshListenable: notifier,
    redirect: (BuildContext context, GoRouterState state) {
      final session = notifier.session;
      final uri = state.uri.toString();

      final isAuthRoute = uri == kSignInRoute ||
          uri == kSignUpRoute ||
          uri == kForgotPasswordRoute;

      // No session → force to sign-in (unless already on an auth route)
      if (session == null) {
        return isAuthRoute ? null : kSignInRoute;
      }

      // Has session → redirect away from auth routes
      if (isAuthRoute) {
        return notifier.clubId == null ? kOnboardingRoute : kHomeRoute;
      }

      // Has session + club → skip onboarding if already done
      if (uri == kOnboardingRoute && notifier.clubId != null) {
        return kHomeRoute;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: kSignInRoute,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: kSignUpRoute,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: kForgotPasswordRoute,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: kOnboardingRoute,
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            BottomNavShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: kHomeRoute,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: kRosterRoute,
                builder: (context, state) => const RosterListScreen(),
                routes: [
                  GoRoute(
                    path: 'add-player',
                    builder: (context, state) => const _PlaceholderScreen(
                      title: 'Add Player',
                    ),
                  ),
                  GoRoute(
                    path: 'player/:id',
                    builder: (context, state) {
                      final id = state.pathParameters['id']!;
                      return _PlaceholderScreen(
                        title: 'Player Profile',
                        subtitle: id,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: kNotificationsRoute,
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: kProfileRoute,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

// ── Placeholder screen for sub-routes not yet built ──────────

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$title — coming soon',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
