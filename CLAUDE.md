# SquadSync

## What this app does
SquadSync is a mobile-first sports club roster management app for 
multi-division clubs. It lets club admins, coaches, players, and 
parents manage rosters, communicate in real time, and handle 
cross-division fill-in requests (where a player from a lower division 
temporarily fills a spot in a higher division game).

## Platform
Mobile only — iOS and Android.
Flutter 3.41.4 / Dart 3.11.1
Web app is Phase 2 — do NOT build any web-specific UI now.

## GitHub
https://github.com/dmshuklaa/squadsync.git

## Tech stack
- Flutter 3.41.4 with Dart 3.11.1
- Supabase (supabase_flutter ^2.8.0) — database, auth, 
  real-time subscriptions, storage, edge functions
- Riverpod (flutter_riverpod ^2.6.1) — all state management
- GoRouter (go_router ^14.6.2) — all navigation
- flutter_dotenv — environment variables (.env file, never hardcoded)
- flutter_secure_storage — session persistence
- flutter_local_notifications — push notifications
- connectivity_plus — offline detection
- file_picker — CSV import
- image_picker — avatar and chat image uploads
- cached_network_image — all network image display
- intl — date/time formatting
- uuid — generating IDs client-side where needed
- fl_chart — charts (Phase 2, do not build yet)

## Folder structure
lib/
  main.dart                  App entry point, Supabase init, Riverpod, GoRouter
  core/
    supabase/
      supabase_client.dart   Supabase client singleton
    router/
      app_router.dart        GoRouter config, all named routes
    theme/
      app_theme.dart         MaterialTheme, colours, typography
    utils/
      validators.dart        Zod-equivalent validation helpers
      date_helpers.dart      Date formatting utilities
      error_mapper.dart      Maps Supabase errors to user-friendly messages
    constants/
      app_constants.dart     App-wide constants
  features/
    auth/
      data/                  Supabase auth calls
      providers/             Riverpod providers for auth state
      screens/               sign_in, sign_up, forgot_password
    onboarding/
      providers/             onboarding_provider (createClub, joinClub)
      screens/               onboarding_screen (TabBar: create club / join club)
    roster/
      data/
      providers/
      screens/               roster_list, player_profile, add_player, 
                             add_guardian, import_csv
    events/
      data/
      providers/
      screens/               event_list, event_detail, create_event, 
                             event_roster, event_chat
    fill_in/
      data/
      providers/
      screens/               request_fill_in, respond_fill_in, fill_in_rules
    notifications/
      data/
      providers/
      screens/               notifications_list
    profile/
      data/
      providers/
      screens/               profile, availability, guardian_requests, 
                             club_settings, divisions
    chat/
      data/
      providers/
      screens/               chat_screen (embedded in event_detail)
  shared/
    widgets/                 squad_sync_logo, bottom_nav_shell
    models/                  Shared data models / Dart classes
    extensions/              Dart extension methods

## Database (Supabase — ap-southeast-2 Sydney region)
- All DB access goes through lib/core/supabase/supabase_client.dart
- Row Level Security (RLS) MUST be enabled on ALL tables
- Never expose secret key in the app — publishable key only
- Publishable key and URL loaded from .env via flutter_dotenv
- All migrations stored in /supabase/migrations/

## Key domain concepts
- Club: top-level entity, has a join code, has multiple divisions
- Division: e.g. Div 1, Div 2. Belongs to a club. Has multiple teams.
- Team: belongs to one division. Has a roster of players.
- Profile: a user. Role is one of: club_admin, coach, player, parent.
- Team membership: links a profile to a team with a position and status.
- Guardian: a parent profile linked to a junior player profile.
- Event: a game or training session. Has a roster and a chat channel.
- Fill-in request: a coach requests a lower-division player for one event.
- Eligibility rule: admin-set rule — which divisions can fill in for which.
- Fill-in log: permanent audit record of all fill-in activity.

## Coding rules
- All files are .dart — no exceptions
- All Riverpod providers use the code generation style 
  (@riverpod annotation) consistently
- Every widget has explicit typed parameters — no dynamic
- Never use BuildContext across async gaps without mounted check
- All Supabase responses must be null-checked and error-handled
- Error states must always be shown — never leave screen blank on error
- Loading states must always be shown — use shimmer or CircularProgressIndicator
- All user-facing strings in English for now (i18n-ready structure)
- Use Riverpod providers for ALL data fetching — no raw FutureBuilder 
  calling Supabase directly from widgets
- Navigator must never be called directly — always use GoRouter context.go() 
  or context.push()
- Never hardcode colours — always use Theme.of(context) or AppTheme constants
- Images always use CachedNetworkImage, never Image.network

## Environment variables (.env — never commit this file)
SUPABASE_URL=your_project_url_here
SUPABASE_PUBLISHABLE_KEY=sb_publishable_your_key_here

## .gitignore must include
.env
*.env
.env.*

## Supabase Edge Functions
Stored in /supabase/functions/
Written in TypeScript (Deno runtime)
Functions:
- send-invite: sends magic link email via Resend API
- send-push: sends push notifications via Expo Push API
- expire-fill-in-requests: pg_cron job, runs every 30 mins
- revoke-fill-in-access: pg_cron job, runs after event ends

## Do NOT build in Phase 1
- Web app or any web-specific UI
- Payment processing
- Live game scoring or statistics
- Video sharing
- Background check integration
- Admin dashboard charts (EP-08)
- Reporting and CSV export (EP-09)

## sprint progress
Sprint 1 — Foundation & Auth        [x]
Sprint 2 — Roster Management        [ ]
Sprint 3 — Events & Fill-in         [ ]
Sprint 4 — Chat & Notifications     [ ]
Sprint 5 — Polish & App Store Prep  [ ]

## Sprint 1 — what was built
### 1.1 Project scaffold
- Flutter project, pubspec.yaml (all deps), .env, .gitignore
- lib/core/supabase/supabase_client.dart — singleton getter
- lib/core/theme/app_theme.dart — AppColors.primary (#1E3A5F), AppColors.secondary (#2E75B6), Material 3 light + dark themes

### 1.2 Database schema
- supabase/migrations/001_core_schema.sql
  - Enums: user_role, membership_status, guardian_permission
  - Tables: clubs, divisions, teams, profiles, team_memberships, guardian_links
  - handle_new_user() trigger — SECURITY DEFINER SET search_path = public
  - generate_join_code() Postgres function
  - RLS enabled on all 6 tables, 16 policies
- lib/shared/models/ — Club, Division, Team, Profile, TeamMembership, GuardianLink (all with fromJson/toJson/copyWith)
- lib/shared/models/enums.dart — UserRole, MembershipStatus, GuardianPermission

### 1.3 Auth flow
- lib/features/auth/providers/auth_provider.dart — AuthNotifier (@riverpod AsyncNotifier): signIn, signUp (returns bool for email-confirm flow), signOut, sendPasswordResetEmail
- lib/core/router/app_router.dart — GoRouter with _AuthChangeNotifier refreshListenable, redirect logic (5 cases), StatefulShellRoute.indexedStack (4 tabs)
- lib/core/utils/validators.dart — email, password, fullName validators
- lib/core/utils/error_mapper.dart — AuthErrorMapper with contains() matching
- Screens: sign_in, sign_up (SegmentedButton role selector), forgot_password (two-view pattern)
- lib/shared/widgets/bottom_nav_shell.dart — 4-tab BottomNavigationBar

### 1.4 Onboarding flow
- lib/features/onboarding/providers/onboarding_provider.dart — OnboardingNotifier (@riverpod): createClub (client-side UUID, seeds Division 1 + Team 1), joinClub (ClubNotFoundException for inline error)
- lib/features/onboarding/screens/onboarding_screen.dart — DefaultTabController, two tabs, SquadSyncLogo, no AppBar
- lib/shared/widgets/squad_sync_logo.dart — size + showTagline params
- lib/features/profile/screens/profile_screen.dart — email, role, Sign Out (dev placeholder)
- supabase/migrations/002_fix_rls_recursion.sql — get_my_club_id() SECURITY DEFINER function, 10 policy fixes

## known pre-production cleanup
- Remove diagnostic print statements in onboarding_provider.dart before App Store submission
- Remove debug print in error_mapper.dart before App Store submission
- Profile screen role reads from JWT userMetadata (signup role) — replace with live DB fetch in Sprint 5
