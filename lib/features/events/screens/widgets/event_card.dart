import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/events/providers/events_providers.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/event.dart';

class EventCard extends ConsumerWidget {
  const EventCard({
    super.key,
    required this.event,
    this.onTap,
  });

  final Event event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myRsvpAsync = ref.watch(myRsvpProvider(event.id));
    final myRsvp = myRsvpAsync.whenOrNull(data: (r) => r?.status);

    final isGame = event.eventType == EventType.game;
    final isCancelled = event.status == EventStatus.cancelled;
    final dateStr = DateFormat('E d MMM').format(event.startsAt.toLocal());
    final timeStr = DateFormat('h:mm a').format(event.startsAt.toLocal());
    final headerColor = isCancelled
        ? AppColors.textSecondary
        : (isGame ? AppColors.primary : AppColors.primaryLight);

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isCancelled ? 0.65 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header bar ──────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: headerColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCancelled
                          ? Icons.cancel_outlined
                          : (isGame
                              ? Icons.sports_soccer
                              : Icons.fitness_center),
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isCancelled
                          ? 'CANCELLED'
                          : event.eventType.label.toUpperCase(),
                      style: AppTextStyles.label.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateStr,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title,
                        style: AppTextStyles.body
                            .copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_outlined,
                            size: 14, color: AppColors.textHint),
                        const SizedBox(width: 4),
                        Text(timeStr, style: AppTextStyles.bodySmall),
                        if (event.location != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.location_on_outlined,
                              size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: AppTextStyles.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── RSVP buttons (hidden when cancelled) ──
                    if (!isCancelled)
                      Row(
                        children: [
                          _RsvpButton(
                            label: 'Going',
                            icon: Icons.check_circle_outline,
                            value: RsvpStatus.going,
                            selected: myRsvp == RsvpStatus.going,
                            eventId: event.id,
                          ),
                          const SizedBox(width: 8),
                          _RsvpButton(
                            label: 'Maybe',
                            icon: Icons.help_outline,
                            value: RsvpStatus.maybe,
                            selected: myRsvp == RsvpStatus.maybe,
                            eventId: event.id,
                          ),
                          const SizedBox(width: 8),
                          _RsvpButton(
                            label: "Can't go",
                            icon: Icons.cancel_outlined,
                            value: RsvpStatus.notGoing,
                            selected: myRsvp == RsvpStatus.notGoing,
                            eventId: event.id,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RsvpButton extends ConsumerWidget {
  const _RsvpButton({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.eventId,
  });

  final String label;
  final IconData icon;
  final RsvpStatus value;
  final bool selected;
  final String eventId;

  Color get _selectedColor {
    switch (value) {
      case RsvpStatus.going:
        return AppColors.activeGreen;
      case RsvpStatus.notGoing:
        return AppColors.error;
      case RsvpStatus.maybe:
        return AppColors.pendingAmber;
    }
  }

  Color get _selectedSurface {
    switch (value) {
      case RsvpStatus.going:
        return AppColors.activeSurface;
      case RsvpStatus.notGoing:
        return AppColors.inactiveSurface;
      case RsvpStatus.maybe:
        return AppColors.pendingSurface;
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
          } catch (_) {
            // error handled by provider
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _selectedSurface : AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? _selectedColor : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? _selectedColor : AppColors.textHint,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: selected ? _selectedColor : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
