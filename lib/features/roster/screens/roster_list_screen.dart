import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadsync/core/router/app_router.dart';
import 'package:squadsync/core/supabase/supabase_client.dart';
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
  void initState() {
    super.initState();
    // If teams are already cached when the screen opens, ref.listen won't fire
    // for the initial value. Use a post-frame callback so we can safely call
    // ref.read and setState after the first build completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final teams = ref.read(userTeamsProvider).valueOrNull;
      if (teams != null && teams.isNotEmpty && _selectedTeamId == null) {
        setState(() => _selectedTeamId = teams.first.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(userTeamsProvider);
    final profileAsync = ref.watch(currentProfileProvider);

    // Auto-select first team when teams first arrive
    ref.listen<AsyncValue<List<Team>>>(userTeamsProvider, (_, next) {
      next.whenData((teams) {
        if (_selectedTeamId == null && teams.isNotEmpty) {
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

    final isAdmin =
        profileAsync.whenOrNull(data: (p) => p.role == UserRole.clubAdmin) ??
            false;

    // Compute selected team name for chat navigation
    final allTeams = teamsAsync.valueOrNull ?? [];
    final selectedTeam = allTeams.cast<Team?>().firstWhere(
          (t) => t?.id == _selectedTeamId,
          orElse: () => null,
        );
    final chatTeamName = selectedTeam != null
        ? '${selectedTeam.divisionName ?? 'Division'} · ${selectedTeam.name}'
        : 'Team Chat';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Squad'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isAdmin && selectedTeam != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              tooltip: 'Edit team',
              onPressed: () =>
                  _showEditTeamSheet(context, ref, selectedTeam),
            ),
          if (_selectedTeamId != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Team chat',
              onPressed: () => context.push(
                '/chat/$_selectedTeamId',
                extra: chatTeamName,
              ),
            ),
        ],
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

  Future<void> _showEditTeamSheet(
      BuildContext context, WidgetRef ref, Team team) async {
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          // Controllers live inside the builder — tied to sheet lifecycle
          final divController =
              TextEditingController(text: team.divisionName ?? '');
          final teamController = TextEditingController(text: team.name);

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit team', style: AppTextStyles.h3),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: divController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Division name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: teamController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Team name',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final divName = divController.text.trim();
                      final teamName = teamController.text.trim();
                      if (divName.isEmpty || teamName.isEmpty) return;

                      try {
                        await supabase
                            .from('divisions')
                            .update({'name': divName})
                            .eq('id', team.divisionId);
                        await supabase
                            .from('teams')
                            .update({'name': teamName})
                            .eq('id', team.id);
                        ref.invalidate(userTeamsProvider);
                        if (!sheetContext.mounted) return;
                        Navigator.of(sheetContext).pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Team updated')),
                        );
                      } catch (e) {
                        if (!sheetContext.mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed: $e')),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
          final divName = team.divisionName ?? 'Division';
          final teamName = team.name;

          return RawChip(
            label: Text(
              '$divName · $teamName',
              style: TextStyle(
                color: isSelected ? AppColors.primary : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            selected: isSelected,
            showCheckmark: false,
            avatar: null,
            deleteIcon: null,
            backgroundColor: isSelected
                ? AppColors.accent
                : Colors.white.withValues(alpha: 0.2),
            selectedColor: AppColors.accent,
            side: BorderSide(
              color: isSelected
                  ? Colors.transparent
                  : Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

    final rosterAsync = ref.watch(teamRosterProvider(teamId));

    return rosterAsync.when(
      loading: () => const RosterShimmer(),
      error: (e, _) => ErrorStateWidget(
        message: 'Failed to load roster.\nPlease try again.',
        onRetry: () => ref.invalidate(teamRosterProvider(teamId)),
      ),
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
