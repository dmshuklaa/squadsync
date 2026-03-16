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
      screens/               join_club, create_club
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
    widgets/                 Reusable UI widgets used across features
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
Sprint 1 — Foundation & Auth        [ ]
Sprint 2 — Roster Management        [ ]
Sprint 3 — Events & Fill-in         [ ]
Sprint 4 — Chat & Notifications     [ ]
Sprint 5 — Polish & App Store Prep  [ ]
