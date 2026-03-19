import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/features/auth/screens/forgot_password_screen.dart';
import 'package:squadsync/features/auth/screens/sign_in_screen.dart';
import 'package:squadsync/features/auth/screens/sign_up_screen.dart';
import 'package:squadsync/features/events/screens/create_event_screen.dart';
import 'package:squadsync/features/events/screens/event_detail_screen.dart';
import 'package:squadsync/features/events/screens/event_list_screen.dart';
import 'package:squadsync/features/events/screens/home_screen.dart';
import 'package:squadsync/features/fill_in/screens/fill_in_rules_screen.dart';
import 'package:squadsync/features/fill_in/screens/request_fill_in_screen.dart';
import 'package:squadsync/features/fill_in/screens/respond_fill_in_screen.dart';
import 'package:squadsync/features/notifications/screens/notifications_screen.dart';
import 'package:squadsync/features/onboarding/screens/onboarding_screen.dart';
import 'package:squadsync/features/profile/screens/guardian_requests_screen.dart';
import 'package:squadsync/features/profile/screens/profile_screen.dart';
import 'package:squadsync/features/roster/screens/add_guardian_screen.dart';
import 'package:squadsync/features/roster/screens/add_player_screen.dart';
import 'package:squadsync/features/roster/screens/player_profile_screen.dart';
import 'package:squadsync/features/roster/screens/roster_list_screen.dart';
import 'package:squadsync/shared/widgets/bottom_nav_shell.dart';

part 'app_router.g.dart';

// ── Route argument types ─────────────────────────────────────

/// Arguments for the /roster/player/:id route.
/// [id] is the profileId for real players, or the pendingPlayerId for pending.
class PlayerProfileArgs {
  const PlayerProfileArgs({
    required this.id,
    required this.isPending,
    required this.teamId,
  });

  final String id;
  final bool isPending;
  final String teamId;
}

/// Arguments for the /roster/player/:id/add-guardian route.
class AddGuardianArgs {
  const AddGuardianArgs({
    required this.playerProfileId,
    required this.playerName,
  });

  final String playerProfileId;
  final String playerName;
}

/// Arguments for the /fill-in/request route.
class FillInArgs {
  const FillInArgs({
    required this.eventId,
    required this.eventTitle,
    required this.targetDivisionId,
  });

  final String eventId;
  final String eventTitle;
  final String targetDivisionId;
}

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
const String kAddGuardianRoute = '/roster/player/:id/add-guardian';
const String kGuardianRequestsRoute = '/profile/guardian-requests';
const String kEventListRoute = '/home/events';
const String kEventDetailRoute = '/events/:id';
const String kCreateEventRoute = '/events/create';
const String kFillInRulesRoute = '/profile/fill-in-rules';
const String kRequestFillInRoute = '/fill-in/request';
const String kRespondFillInRoute = '/fill-in/respond/:id';

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
        path: kCreateEventRoute,
        builder: (context, state) => CreateEventScreen(
          teamId: state.extra as String?,
        ),
      ),
      GoRoute(
        path: kEventDetailRoute,
        builder: (context, state) => EventDetailScreen(
          eventId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: kRequestFillInRoute,
        builder: (context, state) {
          final args = state.extra as FillInArgs;
          return RequestFillInScreen(
            eventId: args.eventId,
            eventTitle: args.eventTitle,
            targetDivisionId: args.targetDivisionId,
          );
        },
      ),
      GoRoute(
        path: kRespondFillInRoute,
        builder: (context, state) => RespondFillInScreen(
          requestId: state.pathParameters['id']!,
        ),
      ),
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
                routes: [
                  GoRoute(
                    path: 'events',
                    builder: (context, state) => const EventListScreen(),
                  ),
                ],
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
                    builder: (context, state) => AddPlayerScreen(
                      teamId: state.extra as String?,
                    ),
                  ),
                  GoRoute(
                    path: 'player/:id',
                    builder: (context, state) {
                      final args = state.extra as PlayerProfileArgs;
                      return PlayerProfileScreen(
                        playerId: args.id,
                        isPending: args.isPending,
                        teamId: args.teamId,
                      );
                    },
                    routes: [
                      GoRoute(
                        path: 'add-guardian',
                        builder: (context, state) {
                          final args = state.extra as AddGuardianArgs;
                          return AddGuardianScreen(
                            playerProfileId: args.playerProfileId,
                            playerName: args.playerName,
                          );
                        },
                      ),
                    ],
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
                routes: [
                  GoRoute(
                    path: 'guardian-requests',
                    builder: (context, state) =>
                        const GuardianRequestsScreen(),
                  ),
                  GoRoute(
                    path: 'fill-in-rules',
                    builder: (context, state) =>
                        const FillInRulesScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

