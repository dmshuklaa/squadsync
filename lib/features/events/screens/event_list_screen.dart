import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/events/providers/events_providers.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/shared/models/event.dart';
import 'package:squadsync/shared/widgets/empty_state_widget.dart';
import 'package:squadsync/shared/widgets/error_state_widget.dart';
import 'package:squadsync/features/events/screens/widgets/event_card.dart';

class EventListScreen extends ConsumerWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(userTeamsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All events'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: teamsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => ErrorStateWidget(
          message: 'Failed to load teams.',
          onRetry: () => ref.invalidate(userTeamsProvider),
        ),
        data: (teams) {
          if (teams.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.event_outlined,
              title: 'No teams yet',
              subtitle: 'Join or create a club to see events',
            );
          }
          return _TeamEventsList(teamIds: teams.map((t) => t.id).toList());
        },
      ),
    );
  }
}

class _TeamEventsList extends ConsumerWidget {
  const _TeamEventsList({required this.teamIds});

  final List<String> teamIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final futures = teamIds.map((id) => ref.watch(teamEventsProvider(id)));
    final hasLoading = futures.any((a) => a.isLoading);
    final hasError = futures.any((a) => a.hasError);

    if (hasLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (hasError) {
      return ErrorStateWidget(
        message: 'Failed to load events.',
        onRetry: () {
          for (final id in teamIds) {
            ref.invalidate(teamEventsProvider(id));
          }
        },
      );
    }

    final allEvents = futures
        .expand((a) => a.valueOrNull ?? <Event>[])
        .toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

    if (allEvents.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.event_outlined,
        title: 'No events',
        subtitle: 'Events will appear here when a coach adds them',
      );
    }

    final now = DateTime.now();
    final upcoming = allEvents.where((e) => e.startsAt.isAfter(now)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final past = allEvents.where((e) => !e.startsAt.isAfter(now)).toList();

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async {
        for (final id in teamIds) {
          ref.invalidate(teamEventsProvider(id));
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (upcoming.isNotEmpty) ...[
            _sectionHeader('Upcoming'),
            const SizedBox(height: 8),
            ...upcoming.map(
              (e) => EventCard(
                event: e,
                onTap: () => context.push('/events/${e.id}'),
              ),
            ),
          ],
          if (past.isNotEmpty) ...[
            const SizedBox(height: 8),
            _sectionHeader('Past'),
            const SizedBox(height: 8),
            ...past.map(
              (e) => EventCard(
                event: e,
                onTap: () => context.push('/events/${e.id}'),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.h3),
      ],
    );
  }
}
