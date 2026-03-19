import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/events/providers/events_providers.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/event.dart';
import 'package:squadsync/shared/models/event_roster_entry.dart';
import 'package:squadsync/shared/widgets/avatar_widget.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final myRsvpAsync = ref.watch(myRsvpProvider(eventId));
    final rsvpCountsAsync = ref.watch(rsvpCountsProvider(eventId));
    final rosterAsync = ref.watch(eventRosterProvider(eventId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: eventAsync.maybeWhen(
          data: (event) => Text(event?.title ?? 'Event'),
          orElse: () => const Text('Event'),
        ),
      ),
      body: eventAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(
          child:
              Text('Error loading event: $e', style: AppTextStyles.bodySmall),
        ),
        data: (event) {
          if (event == null) {
            return const Center(
              child:
                  Text('Event not found', style: AppTextStyles.bodySmall),
            );
          }
          final myRsvp =
              myRsvpAsync.whenOrNull(data: (r) => r?.status);
          final counts =
              rsvpCountsAsync.whenOrNull(data: (m) => m) ?? {};

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Primary hero header ────────────────────
                _buildHeroHeader(event),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── RSVP section ─────────────────────
                      _buildRsvpSection(
                          context, ref, myRsvp, counts),
                      const SizedBox(height: 16),

                      // ── Roster section ────────────────────
                      _buildRosterSection(rosterAsync),

                      // ── Notes section ─────────────────────
                      if (event.notes != null &&
                          event.notes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildNotesSection(event.notes!),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Hero header (primary bg, bottom radius 24) ────────────

  Widget _buildHeroHeader(Event event) {
    final isGame = event.eventType == EventType.game;
    final dateStr = DateFormat('EEE d MMM').format(event.startsAt.toLocal());
    final startStr = DateFormat('h:mm a').format(event.startsAt.toLocal());
    final endStr = event.endsAt != null
        ? '–${DateFormat('h:mm a').format(event.endsAt!.toLocal())}'
        : '';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type badge + status badge
          Row(
            children: [
              _EventTypeBadge(eventType: event.eventType, isGame: isGame),
              const Spacer(),
              if (event.status != EventStatus.scheduled)
                _EventStatusBadge(status: event.status),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            event.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Date & time
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: Colors.white70,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '$dateStr · $startStr$endStr',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),

          // Location
          if (event.location != null && event.location!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    event.location!,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── RSVP section ─────────────────────────────────────────

  Widget _buildRsvpSection(
    BuildContext context,
    WidgetRef ref,
    RsvpStatus? myRsvp,
    Map<RsvpStatus, int> counts,
  ) {
    return _SectionCard(
      children: [
        const Text('Are you going?', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        Row(
          children: [
            _RsvpOptionButton(
              label: 'Going',
              icon: Icons.check_circle_outline,
              value: RsvpStatus.going,
              selected: myRsvp == RsvpStatus.going,
              count: counts[RsvpStatus.going] ?? 0,
              eventId: eventId,
            ),
            const SizedBox(width: 8),
            _RsvpOptionButton(
              label: 'Maybe',
              icon: Icons.help_outline,
              value: RsvpStatus.maybe,
              selected: myRsvp == RsvpStatus.maybe,
              count: counts[RsvpStatus.maybe] ?? 0,
              eventId: eventId,
            ),
            const SizedBox(width: 8),
            _RsvpOptionButton(
              label: "Can't go",
              icon: Icons.cancel_outlined,
              value: RsvpStatus.notGoing,
              selected: myRsvp == RsvpStatus.notGoing,
              count: counts[RsvpStatus.notGoing] ?? 0,
              eventId: eventId,
            ),
          ],
        ),
      ],
    );
  }

  // ── Roster section ────────────────────────────────────────

  Widget _buildRosterSection(
      AsyncValue<List<EventRosterEntry>> rosterAsync) {
    return _SectionCard(
      children: [
        Row(
          children: [
            const Text('Roster', style: AppTextStyles.h3),
            const Spacer(),
            rosterAsync.maybeWhen(
              data: (entries) => Text(
                '${entries.length} player${entries.length == 1 ? '' : 's'}',
                style: AppTextStyles.bodySmall,
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        rosterAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.accent),
          ),
          error: (e, _) => Text(
            'Error loading roster',
            style:
                AppTextStyles.bodySmall.copyWith(color: AppColors.error),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return Text(
                'No players rostered',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint),
              );
            }
            return Column(
              children:
                  entries.map((e) => _RosterRow(entry: e)).toList(),
            );
          },
        ),
      ],
    );
  }

  // ── Notes section ─────────────────────────────────────────

  Widget _buildNotesSection(String notes) {
    return _SectionCard(
      children: [
        Row(
          children: [
            const Icon(Icons.notes_outlined,
                color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            const Text('Notes', style: AppTextStyles.h3),
          ],
        ),
        const SizedBox(height: 8),
        Text(notes, style: AppTextStyles.body),
      ],
    );
  }
}

// ── Section card ──────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ── RSVP option button (with count) ──────────────────────────

class _RsvpOptionButton extends ConsumerWidget {
  const _RsvpOptionButton({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.count,
    required this.eventId,
  });

  final String label;
  final IconData icon;
  final RsvpStatus value;
  final bool selected;
  final int count;
  final String eventId;

  Color get _activeColor {
    switch (value) {
      case RsvpStatus.going:
        return AppColors.activeGreen;
      case RsvpStatus.notGoing:
        return AppColors.error;
      case RsvpStatus.maybe:
        return AppColors.pendingAmber;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          try {
            await ref
                .read(rsvpNotifierProvider.notifier)
                .upsertRsvp(eventId: eventId, status: value);
          } catch (_) {}
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _activeColor : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _activeColor : AppColors.border,
              width: selected ? 0 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _activeColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : _activeColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: AppTextStyles.caption.copyWith(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Roster row ────────────────────────────────────────────────

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.entry});

  final EventRosterEntry entry;

  @override
  Widget build(BuildContext context) {
    final name = entry.profileFullName ?? 'Unknown';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          AvatarWidget(
            size: 36,
            fullName: name,
            avatarUrl: entry.profileAvatarUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.body),
                if (entry.isFillIn)
                  Text(
                    'Fill-in',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.accent,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Event type badge ──────────────────────────────────────────

class _EventTypeBadge extends StatelessWidget {
  const _EventTypeBadge({
    required this.eventType,
    required this.isGame,
  });

  final EventType eventType;
  final bool isGame;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGame ? Icons.sports_soccer : Icons.fitness_center,
            color: Colors.white,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            eventType.label.toUpperCase(),
            style: AppTextStyles.label.copyWith(
              color: Colors.white,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Event status badge ────────────────────────────────────────

class _EventStatusBadge extends StatelessWidget {
  const _EventStatusBadge({required this.status});

  final EventStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      EventStatus.cancelled => (
          'Cancelled',
          AppColors.errorSurface,
          AppColors.error,
        ),
      EventStatus.completed => (
          'Completed',
          AppColors.successSurface,
          AppColors.success,
        ),
      EventStatus.scheduled => (
          'Scheduled',
          AppColors.accentSurface,
          AppColors.accent,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
