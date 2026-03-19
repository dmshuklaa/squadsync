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
      app_theme.dart         AppColors (24 constants), AppTextStyles (7 styles), MaterialTheme
    utils/
      validators.dart        Zod-equivalent validation helpers
      date_helpers.dart      Date formatting utilities
      error_mapper.dart      Maps Supabase errors to user-friendly messages
      permission_helper.dart Static role-gate utility (canEditRoster, canArchivePlayer, etc.)
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
      data/                  roster_repository.dart
      providers/             roster_providers.dart, player_profile_provider.dart
      screens/               roster_list, player_profile, add_player,
                             add_guardian, import_csv
                             widgets/roster_list_item.dart
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
    widgets/                 squad_sync_logo, bottom_nav_shell, avatar_widget,
                             status_badge, loading_shimmer, empty_state_widget,
                             error_state_widget, save_toast
    models/                  Club, Division, Team, Profile, TeamMembership,
                             GuardianLink, PendingPlayer, RosterEntry (all fromJson/toJson)
    extensions/              Dart extension methods

## Design system
All colours and text styles live in lib/core/theme/app_theme.dart.
Never hardcode colours — always use AppColors constants or Theme.of(context).

### AppColors (24 constants)
- primary         #1E3A5F  deep navy (primary brand, AppBar, headers)
- primaryLight    #2E75B6  mid navy (avatar palette slot)
- secondary       #2E75B6  alias for primaryLight
- accent          #00D4AA  electric teal (buttons, FAB, active indicators)
- accentSurface   #E0FAF4  teal wash (nav indicator, chip selected bg)
- background      #F5F7FA  off-white page bg
- surface         #FFFFFF  card / form bg
- border          #E2E8F0  dividers, card borders
- textPrimary     #0F1923  headings
- textSecondary   #526070  subtitles, labels
- textHint        #9EB0BF  placeholder text
- activeGreen     #00C48C  active status badge text
- activeSurface   #E6FBF6  active status badge bg
- pendingAmber    #FFB020  pending status badge text
- pendingSurface  #FFF8E7  pending status badge bg
- inactiveRed     #E53E3E  inactive status badge text
- inactiveSurface #FEECEC  inactive status badge bg
- success         #00C48C  success icon/snackbar
- warning         #FFB020  warning icon
- error           #E53E3E  destructive actions, error text
- navyText        #FFFFFF  white text on navy bg
- divider         #E2E8F0  same as border (semantic alias)
- overlay         rgba(0,0,0,0.4)  modal scrim
- shadow          rgba(0,0,0,0.07) card box shadow

### AppTextStyles (7 static TextStyle constants)
- h1    28px, w800, textPrimary, -0.5 tracking
- h2    22px, w700, textPrimary, -0.3 tracking
- h3    18px, w600, textPrimary
- body  15px, w400, textPrimary, 1.4 height
- bodySmall  13px, w400, textSecondary, 1.4 height
- label 12px, w600, textSecondary, 0.5 tracking (ALL CAPS labels)
- caption 11px, w400, textHint

### Shared widget conventions
- AvatarWidget: circular avatar with CachedNetworkImage fallback to initials.
  showRing: true draws a 2.5 px teal border ring (use on profile banner headers).
  Initials use curated 6-colour palette (primary, accent, primaryLight, purple, coral, green).
- StatusBadge: pill badge for MembershipStatus. Uses semantic AppColors pairs.
- SaveToast: OverlayEntry-based fade toast (not SnackBar) for auto-save confirmation.
- LoadingShimmer / RosterShimmer: shimmer with baseColor=border, highlight=accentSurface.
- SquadSyncLogo: size + showTagline + taglineColor params. 3px teal ring, glow shadow.
  Use taglineColor: Colors.white on dark/navy backgrounds.
- NavigationBar (Material 3): indicatorColor=accentSurface, selected icon colour=accent.
- Section cards use a 3px wide teal left accent bar Container beside section title.

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
- Pending player: invited player with no auth account yet (pending_players table).
- RosterEntry: unified display model — wraps either a TeamMembership or PendingPlayer.
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
- Async-after-dialog pattern: capture GoRouter.of(context) and ref.read(notifier)
  BEFORE opening the dialog; use dialogContext for Navigator.of(dialogContext).pop();
  then perform async work using captured references; check mounted before any UI.
- All Supabase responses must be null-checked and error-handled
- Error states must always be shown — never leave screen blank on error
- Loading states must always be shown — use shimmer or CircularProgressIndicator
- All user-facing strings in English for now (i18n-ready structure)
- Use Riverpod providers for ALL data fetching — no raw FutureBuilder
  calling Supabase directly from widgets
- Navigator must never be called directly — always use GoRouter context.go()
  or context.push()
- Never hardcode colours — always use AppColors constants
- Images always use CachedNetworkImage, never Image.network
- Container must never have both color: and decoration: — put color inside BoxDecoration

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
Sprint 2 — Roster Management        [x]
Sprint 3 — Events & Fill-in         [x]
Sprint 4 — Chat & Notifications     [ ]
Sprint 5 — Polish & App Store Prep  [ ]

## Sprint 1 — what was built
### 1.1 Project scaffold
- Flutter project, pubspec.yaml (all deps), .env, .gitignore
- lib/core/supabase/supabase_client.dart — singleton getter
- lib/core/theme/app_theme.dart — initial AppColors.primary (#1E3A5F), AppColors.secondary (#2E75B6)

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

## Sprint 2 — what was built
### 2.1 Roster list screen
- lib/features/roster/data/roster_repository.dart — fetchTeamRoster() joins team_memberships + profiles + pending_players; returns List<RosterEntry>
- lib/features/roster/providers/roster_providers.dart — userTeamsProvider, teamRosterProvider (family), currentProfileProvider
- lib/features/roster/screens/roster_list_screen.dart — team picker chips in AppBar bottom, status filter bar (All/Active/Inactive/Pending), roster list with RefreshIndicator, FAB for admins/coaches
- lib/shared/models/roster_entry.dart — unified RosterEntry wrapping TeamMembership or PendingPlayer; fromPendingPlayer guards email-as-name data (displays email local-part only)
- lib/shared/widgets/empty_state_widget.dart — icon + title + subtitle (no action button — FAB is sole CTA)
- lib/shared/widgets/error_state_widget.dart — message + onRetry callback
- lib/shared/widgets/loading_shimmer.dart — RosterShimmer with card-style shimmer rows
- lib/features/roster/screens/widgets/roster_list_item.dart — card-style GestureDetector row with AvatarWidget + StatusBadge
- supabase/migrations/003_roster_rls.sql — RLS policies for team_memberships read access

### 2.2 Add player / invite flow
- lib/features/roster/screens/add_player_screen.dart — TabBar: "Existing User" (join-code lookup) + "Invite" (send magic link email); form validation; role/position/jersey fields
- lib/features/roster/screens/import_csv_screen.dart — CSV picker, preview table, bulk import via roster_repository
- lib/shared/models/pending_player.dart — PendingPlayer model with fromJson/toJson
- supabase/migrations/004_pending_players.sql — pending_players table, RLS policies
- supabase/functions/send-invite — Edge Function: validates input, inserts pending_player row, sends magic link via Resend API; fallback stores email as full_name when name not provided
- supabase/migrations/005_guardian_links_rls.sql — guardian_links RLS policies

### 2.3 Player profile screen
- lib/features/roster/providers/player_profile_provider.dart — PlayerProfileNotifier (@riverpod AsyncNotifier): loads profile+memberships+guardians, updateMembership, archivePlayer, deletePendingPlayer, addGuardian, removeGuardian; auto-saves on field change
- lib/features/roster/screens/player_profile_screen.dart — navy curved banner header with AvatarWidget(showRing:true), real-profile view (editable position/jersey/status, guardians section), pending-player view (pending badge, delete action); SaveToast for auto-save feedback; _sectionCard with teal accent bar
- lib/features/roster/screens/add_guardian_screen.dart — search existing profile by email, link as guardian with permission level selector
- lib/core/utils/permission_helper.dart — PermissionHelper static utility: canEditRoster, canArchivePlayer, canManageGuardians, isOwnProfile
- lib/shared/widgets/save_toast.dart — OverlayEntry fade toast (not SnackBar) for auto-save confirmation
- lib/shared/widgets/avatar_widget.dart — showRing param, curated 6-colour palette, CachedNetworkImage with initials fallback
- lib/shared/widgets/status_badge.dart — semantic AppColors status pairs
- GoRouter: kPlayerProfileRoute ('/roster/player/:id') with PlayerProfileArgs(id, isPending, teamId) via state.extra

### 2.4 Design upgrade (all screens)
- lib/core/theme/app_theme.dart — complete rewrite: 24 AppColors, 7 AppTextStyles, CardThemeData (not CardTheme), 11 component themes
- lib/shared/widgets/bottom_nav_shell.dart — BottomNavigationBar replaced with NavigationBar (Material 3); indicatorColor=accentSurface; selected icon teal
- lib/shared/widgets/squad_sync_logo.dart — taglineColor param, 3px teal ring, glow BoxShadow
- lib/shared/widgets/avatar_widget.dart — showRing bool, curated palette (primary/accent/primaryLight/purple/coral/green), teal ring Container with BoxDecoration
- lib/features/auth/screens/sign_in_screen.dart — curved navy header, SquadSyncLogo, form card with shadow, teal Sign In button
- lib/features/auth/screens/sign_up_screen.dart — navy AppBar, form card with shadow, teal Create Account button
- lib/features/auth/screens/forgot_password_screen.dart — navy AppBar, success icon AppColors.success
- lib/features/onboarding/screens/onboarding_screen.dart — curved navy header, TabBar indicatorColor=accent, tab forms in white cards
- lib/features/profile/screens/profile_screen.dart — navy curved banner, AvatarWidget(showRing:true), section cards with teal accent bars, sign-out row AppColors.error
- lib/features/roster/screens/roster_list_screen.dart — RawChip team picker (showCheckmark:false, avatar:null), FilterChip status bar (showCheckmark:false, border on unselected), teal extended FAB
- lib/features/roster/screens/player_profile_screen.dart — navy curved banner, teal accent bars on section cards, pending view navy banner

## known pre-production cleanup
- Remove diagnostic print statements in onboarding_provider.dart before App Store submission
- Remove debug print in error_mapper.dart before App Store submission
- Remove debug print statements in roster_list_screen.dart before App Store submission
- Profile screen role reads from JWT userMetadata (signup role) — replace with live DB fetch in Sprint 5
- send-invite Edge Function stores email as full_name when name is not provided — fix function to leave full_name null; RosterEntry.fromPendingPlayer has a defensive guard in the meantime
