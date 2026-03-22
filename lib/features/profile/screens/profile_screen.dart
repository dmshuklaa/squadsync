import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadsync/core/router/app_router.dart';
import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/auth/providers/auth_provider.dart';
import 'package:squadsync/features/fill_in/providers/fill_in_providers.dart';
import 'package:squadsync/features/roster/providers/guardian_provider.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/profile.dart';
import 'package:squadsync/shared/models/team.dart';
import 'package:squadsync/shared/widgets/avatar_widget.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _signOut() async {
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign out failed. Please try again.')),
      );
    }
  }

  Future<void> _showEditProfileSheet(Profile profile) async {
    final nameController = TextEditingController(text: profile.fullName);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit profile', style: AppTextStyles.h3),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      try {
        await supabase
            .from('profiles')
            .update({'full_name': nameController.text.trim()})
            .eq('id', profile.id);
        ref.invalidate(currentProfileProvider);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update name: $e')),
        );
      }
    }
    nameController.dispose();
  }

  Future<void> _showSquadSettingsSheet(Team team) async {
    int squadSize = team.squadSize ?? 0;
    int playingXi = team.playingXiSize ?? 0;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Squad settings — ${team.name}',
                  style: AppTextStyles.h3),
              const SizedBox(height: 20),
              _CounterRow(
                label: 'Squad size',
                value: squadSize,
                onDecrement: squadSize > 0
                    ? () => setModalState(() => squadSize--)
                    : null,
                onIncrement: () => setModalState(() => squadSize++),
              ),
              const SizedBox(height: 16),
              _CounterRow(
                label: 'Playing XI / Starting lineup',
                value: playingXi,
                onDecrement: playingXi > 0
                    ? () => setModalState(() => playingXi--)
                    : null,
                onIncrement: () => setModalState(() => playingXi++),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await ref
            .read(rosterRepositoryProvider)
            .updateTeamSquadSize(
              teamId: team.id,
              squadSize: squadSize > 0 ? squadSize : null,
              playingXiSize: playingXi > 0 ? playingXi : null,
            );
        ref.invalidate(userTeamsProvider);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final profileAsync = ref.watch(currentProfileProvider);
    final requestsAsync = ref.watch(pendingGuardianRequestsProvider);
    final pendingCount =
        requestsAsync.whenOrNull(data: (list) => list.length) ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(
          child: Text('Error loading profile: $e',
              style: AppTextStyles.bodySmall),
        ),
        data: (profile) =>
            _buildBody(context, profile, pendingCount, isLoading),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    Profile profile,
    int pendingCount,
    bool isLoading,
  ) {
    final roleLabel = _formatRole(profile.role);
    final isAdmin = profile.role == UserRole.clubAdmin;
    final teamsAsync = ref.watch(userTeamsProvider);
    final memberCountAsync = profile.clubId != null
        ? ref.watch(memberCountProvider(profile.clubId!))
        : null;

    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Navy banner header ───────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 32, 16, 28),
                    child: Column(
                      children: [
                        AvatarWidget(
                          fullName: profile.fullName,
                          avatarUrl: profile.avatarUrl,
                          size: 80,
                          showRing: true,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          profile.fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    AppColors.accent.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            roleLabel,
                            style: const TextStyle(
                              color: AppColors.accentLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Edit button in top-right corner of banner
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: Colors.white70, size: 20),
                      onPressed: () => _showEditProfileSheet(profile),
                      tooltip: 'Edit name',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Guardian requests banner ─────────────────────────
          if (pendingCount > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_alt_outlined,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$pendingCount guardian request${pendingCount == 1 ? '' : 's'} waiting for your response',
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push(kGuardianRequestsRoute),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Review'),
                  ),
                ],
              ),
            ),

          if (pendingCount > 0) const SizedBox(height: 12),

          // ── Account section ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('ACCOUNT'),
                  ListTile(
                    leading: const Icon(Icons.email_outlined,
                        color: AppColors.accent),
                    title: const Text('Email'),
                    subtitle: Text(profile.email ?? '—'),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.badge_outlined,
                        color: AppColors.accent),
                    title: const Text('Role'),
                    subtitle: Text(roleLabel),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Club section (admin only) ────────────────────────
          if (isAdmin && profile.clubId != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('CLUB SETTINGS'),
                    ListTile(
                      leading: const Icon(Icons.sports_outlined,
                          color: AppColors.accent),
                      title: const Text('Sport type'),
                      subtitle: ref
                          .watch(clubProvider(profile.clubId!))
                          .when(
                            loading: () => const Text('Loading…'),
                            error: (e, _) => const Text('—'),
                            data: (club) => Text(club?.sportType ?? '—'),
                          ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.group_outlined,
                          color: AppColors.accent),
                      title: const Text('Active members'),
                      subtitle: memberCountAsync == null
                          ? const Text('—')
                          : memberCountAsync.when(
                              loading: () => const Text('Loading…'),
                              error: (e, _) => const Text('—'),
                              data: (count) =>
                                  Text('$count member${count == 1 ? '' : 's'}'),
                            ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    teamsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (e, _) => const SizedBox.shrink(),
                      data: (teams) => teams.isEmpty
                          ? const SizedBox.shrink()
                          : ListTile(
                              leading: const Icon(Icons.tune_outlined,
                                  color: AppColors.accent),
                              title: const Text('Squad settings'),
                              subtitle: Text(
                                teams.length == 1
                                    ? teams.first.name
                                    : '${teams.length} teams',
                              ),
                              trailing: const Icon(Icons.chevron_right,
                                  color: AppColors.textHint),
                              onTap: () => teams.length == 1
                                  ? _showSquadSettingsSheet(teams.first)
                                  : _showTeamPickerForSquadSettings(
                                      context, teams),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Actions section ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('ACTIONS'),
                  ListTile(
                    leading: const Icon(Icons.family_restroom,
                        color: AppColors.accent),
                    title: const Text('Guardian requests'),
                    trailing: pendingCount > 0
                        ? Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.warning,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              pendingCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : null,
                    onTap: () => context.push(kGuardianRequestsRoute),
                  ),
                  if (isAdmin) ...[
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.swap_horiz,
                          color: AppColors.accent),
                      title: const Text('Fill-in rules'),
                      subtitle: const Text('Configure cross-division fill-ins'),
                      trailing: const Icon(Icons.chevron_right,
                          color: AppColors.textHint),
                      onTap: () => context.push(kFillInRulesRoute),
                    ),
                  ],
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.error),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(color: AppColors.error),
                    ),
                    onTap: isLoading ? null : _signOut,
                    trailing: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showTeamPickerForSquadSettings(
      BuildContext context, List<Team> teams) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: const Text('Select team', style: AppTextStyles.h3),
            ),
            ...teams.map(
              (team) => ListTile(
                title: Text(team.name),
                subtitle: team.divisionName != null
                    ? Text(team.divisionName!)
                    : null,
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showSquadSettingsSheet(team);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
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
          Text(label, style: AppTextStyles.label),
        ],
      ),
    );
  }

  String _formatRole(UserRole role) {
    switch (role) {
      case UserRole.clubAdmin:
        return 'Club Admin';
      case UserRole.coach:
        return 'Coach';
      case UserRole.player:
        return 'Player';
      case UserRole.parent:
        return 'Parent';
    }
  }
}

// ── Counter row for squad settings ───────────────────────────

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.label,
    required this.value,
    required this.onIncrement,
    this.onDecrement,
  });

  final String label;
  final int value;
  final VoidCallback onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: AppTextStyles.body),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline,
              color: AppColors.accent),
          onPressed: onDecrement,
        ),
        SizedBox(
          width: 36,
          child: Text(
            value == 0 ? '—' : '$value',
            style: AppTextStyles.h3.copyWith(color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
          onPressed: onIncrement,
        ),
      ],
    );
  }
}
