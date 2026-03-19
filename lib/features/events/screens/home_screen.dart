import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/events/providers/events_providers.dart';
import 'package:squadsync/features/events/screens/widgets/event_card.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/shared/widgets/empty_state_widget.dart';
import 'package:squadsync/shared/widgets/loading_shimmer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final upcomingAsync = ref.watch(upcomingEventsProvider);
    final teamsAsync = ref.watch(userTeamsProvider);

    final greeting = _greeting();
    final firstName = profileAsync.whenOrNull(
      data: (p) => p.fullName.split(' ').first,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Navy curved header ─────────────────────────────
          SliverToBoxAdapter(
            child: _buildHeader(greeting, firstName),
          ),

          // ── Quick stats ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _QuickStats(
                teamsAsync: teamsAsync,
                upcomingAsync: upcomingAsync,
              ),
            ),
          ),

          // ── Upcoming events ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
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
                  const Text('Upcoming events', style: AppTextStyles.h3),
                ],
              ),
            ),
          ),

          upcomingAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: HomeEventShimmer(),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text('Error: $e', style: AppTextStyles.bodySmall)),
              ),
            ),
            data: (events) {
              if (events.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: EmptyStateWidget(
                      icon: Icons.event_outlined,
                      title: 'No upcoming events',
                      subtitle: 'Events will appear here when a coach adds them',
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.builder(
                  itemCount: events.length,
                  itemBuilder: (_, i) => EventCard(event: events[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String greeting, String? firstName) {
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstName != null ? '$greeting, $firstName' : greeting,
            style: AppTextStyles.h2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            today,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ── Quick stats row ───────────────────────────────────────────

class _QuickStats extends StatelessWidget {
  const _QuickStats({
    required this.teamsAsync,
    required this.upcomingAsync,
  });

  final AsyncValue<dynamic> teamsAsync;
  final AsyncValue<dynamic> upcomingAsync;

  @override
  Widget build(BuildContext context) {
    final teamCount = teamsAsync.whenOrNull(data: (t) => (t as List).length) ?? 0;
    final eventCount = upcomingAsync.whenOrNull(data: (e) => (e as List).length) ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.group_outlined,
            value: '$teamCount',
            label: teamCount == 1 ? 'Team' : 'Teams',
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.event_outlined,
            value: '$eventCount',
            label: 'Upcoming',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.accentSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.accent, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppTextStyles.h3.copyWith(color: AppColors.primary),
                ),
                Text(label, style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
