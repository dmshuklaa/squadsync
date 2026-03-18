import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadsync/core/router/app_router.dart';
import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/features/roster/screens/widgets/roster_list_item.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/roster_entry.dart';
import 'package:squadsync/shared/models/team.dart';
import 'package:squadsync/shared/widgets/empty_state_widget.dart';
import 'package:squadsync/shared/widgets/error_state_widget.dart';
import 'package:squadsync/shared/widgets/loading_shimmer.dart';

class RosterListScreen extends ConsumerStatefulWidget {
  const RosterListScreen({super.key});

  @override
  ConsumerState<RosterListScreen> createState() => _RosterListScreenState();
}

class _RosterListScreenState extends ConsumerState<RosterListScreen> {
  String? _selectedTeamId;
  MembershipStatus? _statusFilter;

  List<RosterEntry> _applyFilter(List<RosterEntry> all) {
    if (_statusFilter == null) return all;
    return all.where((e) => e.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(userTeamsProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    // Auto-select first team when teams first arrive
    ref.listen<AsyncValue<List<Team>>>(userTeamsProvider, (_, next) {
      next.whenData((teams) {
        // ignore: avoid_print
        print('[RosterListScreen] userTeams loaded: ${teams.map((t) => '${t.name} (${t.id})').toList()}');
        if (_selectedTeamId == null && teams.isNotEmpty) {
          // ignore: avoid_print
          print('[RosterListScreen] auto-selecting team: ${teams.first.id}');
          setState(() => _selectedTeamId = teams.first.id);
        }
      });
    });

    final canManageRoster = profileAsync.whenOrNull(
          data: (profile) =>
              profile.role == UserRole.clubAdmin ||
              profile.role == UserRole.coach,
        ) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Squad'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        // ── Team picker in AppBar bottom ──────────────────────
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: teamsAsync.when(
            loading: () => const SizedBox(
              height: 52,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            error: (_, _) => const SizedBox(height: 52),
            data: (teams) => _buildTeamPicker(teams),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Status filter bar ────────────────────────────────
          _buildFilterBar(),
          // ── Roster list ──────────────────────────────────────
          Expanded(child: _buildRosterBody()),
        ],
      ),
      floatingActionButton: canManageRoster && _selectedTeamId != null
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add),
              label: const Text(
                'Add Player',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: () => context.push(
                kRosterAddPlayerRoute,
                extra: _selectedTeamId,
              ),
            )
          : null,
    );
  }

  Widget _buildTeamPicker(List<Team> teams) {
    if (teams.isEmpty) return const SizedBox(height: 52);

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: teams.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final team = teams[i];
          final isSelected = team.id == _selectedTeamId;
          final label = team.divisionName != null
              ? '${team.divisionName} · ${team.name}'
              : team.name;

          return RawChip(
            label: Text(label),
            selected: isSelected,
            showCheckmark: false,
            avatar: null,
            deleteIcon: null,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            selectedColor: AppColors.accent,
            side: isSelected
                ? BorderSide.none
                : BorderSide(
                    color: Colors.white.withValues(alpha: 0.4)),
            labelStyle: TextStyle(
              color: isSelected ? AppColors.primary : Colors.white,
              fontWeight:
                  isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
            onSelected: (_) {
              setState(() => _selectedTeamId = team.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    const filters = [
      (label: 'All', value: null),
      (label: 'Active', value: MembershipStatus.active),
      (label: 'Inactive', value: MembershipStatus.inactive),
      (label: 'Pending', value: MembershipStatus.pending),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: filters.map((f) {
            final isSelected = _statusFilter == f.value;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f.label),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                checkmarkColor: Colors.white,
                showCheckmark: false,
                side: isSelected
                    ? BorderSide.none
                    : const BorderSide(color: AppColors.border),
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                onSelected: (_) {
                  setState(() => _statusFilter = f.value);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRosterBody() {
    final teamId = _selectedTeamId;

    if (teamId == null) {
      return const EmptyStateWidget(
        icon: Icons.group_outlined,
        title: 'No team selected',
        subtitle: 'Select a team above to view its roster',
      );
    }

    // ignore: avoid_print
    print('[RosterListScreen] watching roster for teamId: $teamId');
    final rosterAsync = ref.watch(teamRosterProvider(teamId));

    return rosterAsync.when(
      loading: () => const RosterShimmer(),
      error: (e, stackTrace) {
        // ignore: avoid_print
        print('[RosterListScreen] roster error: $e');
        // ignore: avoid_print
        print('[RosterListScreen] roster error type: ${e.runtimeType}');
        // ignore: avoid_print
        print('[RosterListScreen] roster stackTrace: $stackTrace');
        return ErrorStateWidget(
          message: 'Failed to load roster.\nPlease try again.',
          onRetry: () => ref.invalidate(teamRosterProvider(teamId)),
        );
      },
      data: (entries) {
        final filtered = _applyFilter(entries);

        if (entries.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.group_outlined,
            title: 'No players yet',
            subtitle: 'Tap the button below to add your first player',
          );
        }

        if (filtered.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.filter_list_off,
            title: 'No players match this filter',
            subtitle: 'Try a different status filter',
          );
        }

        return RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () async {
            ref.invalidate(teamRosterProvider(teamId));
            await ref.read(teamRosterProvider(teamId).future);
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final entry = filtered[i];
              final playerId =
                  entry.isPending ? entry.id : entry.profileId;
              return RosterListItem(
                entry: entry,
                onTap: () => context.push(
                  kPlayerProfileRoute.replaceFirst(':id', playerId),
                  extra: PlayerProfileArgs(
                    id: playerId,
                    isPending: entry.isPending,
                    teamId: teamId,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
