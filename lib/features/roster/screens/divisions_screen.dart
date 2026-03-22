import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/roster/data/roster_repository.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/shared/models/division.dart';
import 'package:squadsync/shared/models/team.dart';

class DivisionsScreen extends ConsumerStatefulWidget {
  const DivisionsScreen({super.key});

  @override
  ConsumerState<DivisionsScreen> createState() => _DivisionsScreenState();
}

class _DivisionsScreenState extends ConsumerState<DivisionsScreen> {
  // Map divisionId → list of teams (loaded on first expansion)
  final Map<String, List<Team>> _teams = {};
  final Map<String, bool> _loadingTeams = {};

  Future<String?> _getClubId() async {
    final profile = await ref.read(currentProfileProvider.future);
    return profile.clubId;
  }

  Future<void> _loadTeams(String divisionId) async {
    if (_teams.containsKey(divisionId)) return;
    setState(() => _loadingTeams[divisionId] = true);
    try {
      final teams = await ref
          .read(rosterRepositoryProvider)
          .getTeamsForDivision(divisionId);
      if (mounted) setState(() => _teams[divisionId] = teams);
    } catch (_) {
      if (mounted) setState(() => _teams[divisionId] = []);
    } finally {
      if (mounted) setState(() => _loadingTeams.remove(divisionId));
    }
  }

  Future<void> _showAddDivisionSheet(String clubId) async {
    final divController = TextEditingController();
    final teamController = TextEditingController();
    final repo = ref.read(rosterRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add division', style: AppTextStyles.h3),
              const SizedBox(height: 20),
              TextFormField(
                controller: divController,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Division name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: teamController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'First team name (optional)'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final divName = divController.text.trim();
                  if (divName.isEmpty) return;
                  try {
                    await repo.createDivision(
                      clubId: clubId,
                      name: divName,
                      firstTeamName: teamController.text.trim().isEmpty
                          ? null
                          : teamController.text.trim(),
                    );
                    ref.invalidate(userTeamsProvider);
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    setState(() => _teams.clear());
                    messenger.showSnackBar(
                      SnackBar(content: Text('Division "$divName" created')),
                    );
                  } catch (e) {
                    if (!ctx.mounted) return;
                    messenger.showSnackBar(
                        SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTeamSheet(String divisionId) async {
    final teamController = TextEditingController();
    final repo = ref.read(rosterRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add team', style: AppTextStyles.h3),
              const SizedBox(height: 20),
              TextFormField(
                controller: teamController,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Team name'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final name = teamController.text.trim();
                  if (name.isEmpty) return;
                  try {
                    await repo.createTeam(
                        divisionId: divisionId, name: name);
                    ref.invalidate(userTeamsProvider);
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    setState(() => _teams.remove(divisionId));
                    await _loadTeams(divisionId);
                    messenger.showSnackBar(
                      SnackBar(content: Text('Team "$name" created')),
                    );
                  } catch (e) {
                    if (!ctx.mounted) return;
                    messenger.showSnackBar(
                        SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renameItem({
    required String label,
    required String current,
    required Future<void> Function(String name) onSave,
  }) async {
    final ctrl = TextEditingController(text: current);
    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rename $label', style: AppTextStyles.h3),
              const SizedBox(height: 20),
              TextFormField(
                controller: ctrl,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                decoration: InputDecoration(labelText: label),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final name = ctrl.text.trim();
                  if (name.isEmpty) return;
                  try {
                    await onSave(name);
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                  } catch (e) {
                    if (!ctx.mounted) return;
                    messenger.showSnackBar(
                        SnackBar(content: Text('Error: $e')));
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete({
    required String name,
    required String warning,
    required Future<void> Function() onConfirm,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: Text(warning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await onConfirm();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _getClubId(),
      builder: (context, clubSnap) {
        if (!clubSnap.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Divisions & Teams'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            body: const Center(
                child: CircularProgressIndicator(color: AppColors.accent)),
          );
        }

        final clubId = clubSnap.data;
        if (clubId == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Divisions & Teams'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            body: const Center(child: Text('No club found')),
          );
        }

        return _buildBody(clubId);
      },
    );
  }

  Widget _buildBody(String clubId) {
    return FutureBuilder<List<Division>>(
      future: ref.read(rosterRepositoryProvider).getDivisionsForClub(clubId),
      builder: (context, snap) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Divisions & Teams'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: snap.connectionState == ConnectionState.waiting
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accent))
              : snap.hasError
                  ? Center(child: Text('Error: ${snap.error}'))
                  : snap.data!.isEmpty
                      ? const Center(
                          child: Text('No divisions yet. Tap + to add one.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: snap.data!.length,
                          itemBuilder: (_, i) =>
                              _buildDivisionCard(snap.data![i], clubId),
                        ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.primary,
            icon: const Icon(Icons.add),
            label: const Text('Add division',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () async {
              await _showAddDivisionSheet(clubId);
              if (mounted) setState(() {});
            },
          ),
        );
      },
    );
  }

  Widget _buildDivisionCard(Division division, String clubId) {
    // Load teams when first rendered
    if (!_teams.containsKey(division.id) &&
        !(_loadingTeams[division.id] ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadTeams(division.id));
    }

    final teams = _teams[division.id] ?? [];
    final loading = _loadingTeams[division.id] ?? false;
    final repo = ref.read(rosterRepositoryProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Division header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(division.name, style: AppTextStyles.h3),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.textSecondary),
                  tooltip: 'Rename division',
                  onPressed: () async {
                    await _renameItem(
                      label: 'Division',
                      current: division.name,
                      onSave: (name) async {
                        await repo.renameDivision(
                            divisionId: division.id, name: name);
                        ref.invalidate(userTeamsProvider);
                        if (mounted) setState(() {});
                      },
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.error),
                  tooltip: 'Delete division',
                  onPressed: () async {
                    await _confirmDelete(
                      name: division.name,
                      warning:
                          'This will also delete all teams in this division. This cannot be undone.',
                      onConfirm: () async {
                        await repo.deleteDivision(division.id);
                        ref.invalidate(userTeamsProvider);
                        if (mounted) {
                          setState(() => _teams.remove(division.id));
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            ...teams.map((team) => _buildTeamRow(team, division.id, repo)),
            // Add team button
            TextButton.icon(
              onPressed: () async {
                await _showAddTeamSheet(division.id);
              },
              icon: const Icon(Icons.add, size: 16, color: AppColors.accent),
              label: const Text('Add team',
                  style: TextStyle(color: AppColors.accent, fontSize: 13)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                alignment: Alignment.centerLeft,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamRow(Team team, String divisionId, RosterRepository repo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.group_outlined,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(team.name,
                style: const TextStyle(color: AppColors.textPrimary)),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                size: 16, color: AppColors.textSecondary),
            tooltip: 'Rename team',
            onPressed: () async {
              await _renameItem(
                label: 'Team',
                current: team.name,
                onSave: (name) async {
                  await repo.renameTeam(teamId: team.id, name: name);
                  ref.invalidate(userTeamsProvider);
                  setState(() => _teams.remove(divisionId));
                  await _loadTeams(divisionId);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 16, color: AppColors.error),
            tooltip: 'Delete team',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await _confirmDelete(
                name: team.name,
                warning:
                    'Deleting this team will remove all player memberships. This cannot be undone.',
                onConfirm: () async {
                  await repo.deleteTeam(team.id);
                  ref.invalidate(userTeamsProvider);
                  setState(() => _teams.remove(divisionId));
                  await _loadTeams(divisionId);
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('"${team.name}" deleted')),
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
