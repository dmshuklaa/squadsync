import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:squadsync/core/router/app_router.dart';
import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/core/utils/permission_helper.dart';
import 'package:squadsync/features/roster/providers/player_profile_provider.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/guardian_link.dart';
import 'package:squadsync/shared/models/pending_player.dart';
import 'package:squadsync/shared/models/profile.dart';
import 'package:squadsync/shared/models/team_membership.dart';
import 'package:squadsync/shared/widgets/avatar_widget.dart';
import 'package:squadsync/shared/widgets/save_toast.dart';
import 'package:squadsync/shared/widgets/status_badge.dart';

class PlayerProfileScreen extends ConsumerStatefulWidget {
  const PlayerProfileScreen({
    super.key,
    required this.playerId,
    required this.isPending,
    required this.teamId,
  });

  /// profileId for real players; pendingPlayerId for pending players.
  final String playerId;
  final bool isPending;
  final String teamId;

  @override
  ConsumerState<PlayerProfileScreen> createState() =>
      _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends ConsumerState<PlayerProfileScreen> {
  // ── Editable field controllers (real profile only) ────────────
  final _positionCtrl = TextEditingController();
  final _jerseyCtrl = TextEditingController();
  late final FocusNode _positionFocus;
  late final FocusNode _jerseyFocus;
  bool _membershipsInitialised = false;

  @override
  void initState() {
    super.initState();
    _positionFocus = FocusNode()..addListener(_onPositionFocusChange);
    _jerseyFocus = FocusNode()..addListener(_onJerseyFocusChange);
  }

  @override
  void dispose() {
    _positionCtrl.dispose();
    _jerseyCtrl.dispose();
    _positionFocus.dispose();
    _jerseyFocus.dispose();
    super.dispose();
  }

  // ── Auto-save helpers ─────────────────────────────────────────

  void _onPositionFocusChange() {
    if (!_positionFocus.hasFocus) _savePosition();
  }

  void _onJerseyFocusChange() {
    if (!_jerseyFocus.hasFocus) _saveJersey();
  }

  Future<void> _savePosition() async {
    final membership = ref
        .read(teamMembershipForPlayerProvider(widget.playerId, widget.teamId))
        .valueOrNull;
    if (membership == null) return;

    final newPosition = _positionCtrl.text.trim().isEmpty
        ? null
        : _positionCtrl.text.trim();
    if (newPosition == membership.position) return;

    try {
      await ref
          .read(playerProfileNotifierProvider.notifier)
          .updateMembershipDetails(
            membershipId: membership.id,
            position: newPosition,
            jerseyNumber: int.tryParse(_jerseyCtrl.text.trim()),
            profileId: widget.playerId,
            teamId: widget.teamId,
          );
      if (!mounted) return;
      SaveToast.show(context, 'Saved');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _saveJersey() async {
    final membership = ref
        .read(teamMembershipForPlayerProvider(widget.playerId, widget.teamId))
        .valueOrNull;
    if (membership == null) return;

    final newJersey = int.tryParse(_jerseyCtrl.text.trim());
    if (newJersey == membership.jerseyNumber) return;

    try {
      await ref
          .read(playerProfileNotifierProvider.notifier)
          .updateMembershipDetails(
            membershipId: membership.id,
            position: _positionCtrl.text.trim().isEmpty
                ? null
                : _positionCtrl.text.trim(),
            jerseyNumber: newJersey,
            profileId: widget.playerId,
            teamId: widget.teamId,
          );
      if (!mounted) return;
      SaveToast.show(context, 'Saved');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  // ── URL launch ────────────────────────────────────────────────

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return widget.isPending ? _buildPendingView() : _buildRealProfileView();
  }

  // ══════════════════════════════════════════════════════════════
  // PENDING PLAYER VIEW
  // ══════════════════════════════════════════════════════════════

  Widget _buildPendingView() {
    final pendingAsync = ref.watch(pendingPlayerByIdProvider(widget.playerId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: pendingAsync.whenOrNull(
              data: (p) => p != null ? Text(p.fullName) : null,
            ) ??
            const Text('Player'),
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (pending) {
          if (pending == null) {
            return const Center(child: Text('Player not found'));
          }
          return _buildPendingBody(pending);
        },
      ),
    );
  }

  Widget _buildPendingBody(PendingPlayer pending) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Navy banner
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
            child: Column(
              children: [
                AvatarWidget(
                    fullName: pending.fullName, size: 72, showRing: true),
                const SizedBox(height: 14),
                Text(
                  pending.fullName,
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
                    color: AppColors.pendingAmber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                            AppColors.pendingAmber.withValues(alpha: 0.5)),
                  ),
                  child: const Text(
                    'Pending invitation',
                    style: TextStyle(
                      color: AppColors.pendingAmber,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pending.email != null && pending.email!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.email_outlined,
                        color: AppColors.accent),
                    title: Text(pending.email!),
                    onTap: () => _launch('mailto:${pending.email}'),
                  ),
                if (pending.phone != null && pending.phone!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.phone_outlined,
                        color: AppColors.accent),
                    title: Text(pending.phone!),
                    onTap: () => _launch('tel:${pending.phone}'),
                  ),
                if (pending.position != null &&
                    pending.position!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.sports_outlined,
                        color: AppColors.accent),
                    title: Text(pending.position!),
                    subtitle: const Text('Position'),
                  ),
                if (pending.jerseyNumber != null)
                  ListTile(
                    leading: const Icon(Icons.tag,
                        color: AppColors.accent),
                    title: Text('#${pending.jerseyNumber}'),
                    subtitle: const Text('Jersey number'),
                  ),
                // Join code section
                if (pending.joinCode != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.accentSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Join code',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            )),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              pending.joinCode!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 2,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy_outlined,
                                  color: AppColors.accent),
                              tooltip: 'Copy code',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Join code copied: ${pending.joinCode}'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const Text(
                          'Share this code so the player can join using the app.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Resend invite'),
                  onPressed: () => _handleResendInvite(pending),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _confirmRemovePending(pending),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.error),
                  child: const Text('Remove from team'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleResendInvite(PendingPlayer pending) async {
    try {
      await ref
          .read(playerProfileNotifierProvider.notifier)
          .resendInviteEmail(
            teamId: widget.teamId,
            email: pending.email ?? '',
            fullName: pending.fullName,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite resent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _confirmRemovePending(PendingPlayer pending) async {
    // Capture context-dependent references BEFORE the dialog opens so they
    // remain valid after the dialog is dismissed.
    final router = GoRouter.of(context);
    final notifier = ref.read(playerProfileNotifierProvider.notifier);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove player?'),
        content: Text(
          'Remove ${pending.fullName} from the team? '
          'Their invitation will be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              // 1. Close the dialog using its own context — no stale refs.
              Navigator.of(dialogContext).pop();

              // 2. Async work — context is gone; use captured references.
              try {
                await notifier.deletePendingPlayer(
                  pendingPlayerId: pending.id,
                  teamId: widget.teamId,
                );
                // mounted = screen's mounted (ConsumerStatefulWidget), safe here.
                if (mounted) router.pop();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // REAL PROFILE VIEW
  // ══════════════════════════════════════════════════════════════

  Widget _buildRealProfileView() {
    final profileAsync = ref.watch(profileByIdProvider(widget.playerId));
    final membershipAsync = ref.watch(
        teamMembershipForPlayerProvider(widget.playerId, widget.teamId));
    final currentProfileAsync = ref.watch(currentProfileProvider);

    // Initialise edit controllers once membership loads (only once)
    ref.listen<AsyncValue<TeamMembership?>>(
      teamMembershipForPlayerProvider(widget.playerId, widget.teamId),
      (_, next) {
        if (!_membershipsInitialised) {
          next.whenData((m) {
            if (m != null) {
              _membershipsInitialised = true;
              _positionCtrl.text = m.position ?? '';
              _jerseyCtrl.text = m.jerseyNumber?.toString() ?? '';
            }
          });
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: profileAsync.whenOrNull(
              data: (p) => p != null ? Text(p.fullName) : null,
            ) ??
            const Text('Player Profile'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }

          final currentProfile = currentProfileAsync.valueOrNull;
          final canEdit = PermissionHelper.canEditRoster(
              currentProfile?.role ?? UserRole.player);
          final canArchive = PermissionHelper.canArchivePlayer(
              currentProfile?.role ?? UserRole.player);
          final currentUserId = supabase.auth.currentUser?.id;
          final isOwn = currentUserId != null &&
              PermissionHelper.isOwnProfile(currentUserId, profile.id);

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(profile),
                const SizedBox(height: 8),
                _buildContactSection(profile),
                const SizedBox(height: 8),
                _buildSquadDetailsSection(
                  membershipAsync: membershipAsync,
                  canEdit: canEdit,
                  canArchive: canArchive,
                  profile: profile,
                ),
                const SizedBox(height: 8),
                _buildAvailabilitySection(
                  profile: profile,
                  isOwn: isOwn,
                ),
                if (profile.role == UserRole.player) ...[
                  const SizedBox(height: 8),
                  _buildGuardiansSection(
                    profileId: profile.id,
                    canManage: PermissionHelper.canManageGuardians(
                        currentProfile?.role ?? UserRole.player),
                  ),
                ],
                const SizedBox(height: 8),
                _buildFillInHistorySection(profile.id),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Section 1 — Header ────────────────────────────────────────

  Widget _buildHeader(Profile profile) {
    final teamsAsync = ref.watch(userTeamsProvider);
    String? teamDisplayName;
    teamsAsync.whenData((teams) {
      try {
        final team = teams.firstWhere((t) => t.id == widget.teamId);
        teamDisplayName = team.divisionName != null
            ? '${team.divisionName} · ${team.name}'
            : team.name;
      } catch (_) {}
    });

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
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
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.5)),
            ),
            child: Text(
              _roleName(profile.role),
              style: const TextStyle(
                color: AppColors.accentLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (teamDisplayName != null) ...[
            const SizedBox(height: 6),
            Text(
              teamDisplayName!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Section 2 — Contact ───────────────────────────────────────

  Widget _buildContactSection(Profile profile) {
    return _sectionCard(
      children: [
        ListTile(
          leading: const Icon(Icons.phone_outlined),
          title: (profile.phone != null && profile.phone!.isNotEmpty)
              ? Text(profile.phone!)
              : Text('Not provided',
                  style: TextStyle(color: Colors.grey[500])),
          onTap:
              (profile.phone != null && profile.phone!.isNotEmpty)
                  ? () => _launch('tel:${profile.phone}')
                  : null,
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          leading: const Icon(Icons.email_outlined),
          title: (profile.email != null && profile.email!.isNotEmpty)
              ? Text(profile.email!)
              : Text('Not provided',
                  style: TextStyle(color: Colors.grey[500])),
          onTap:
              (profile.email != null && profile.email!.isNotEmpty)
                  ? () => _launch('mailto:${profile.email}')
                  : null,
        ),
      ],
    );
  }

  // ── Section 3 — Squad details ─────────────────────────────────

  Widget _buildSquadDetailsSection({
    required AsyncValue<TeamMembership?> membershipAsync,
    required bool canEdit,
    required bool canArchive,
    required Profile profile,
  }) {
    return _sectionCard(
      title: 'Squad details',
      children: [
        membershipAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not load squad details: $e'),
          ),
          data: (membership) {
            if (membership == null) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Not a member of this team'),
              );
            }
            return Column(
              children: [
                _detailRow(
                  label: 'Position',
                  child: canEdit
                      ? TextField(
                          controller: _positionCtrl,
                          focusNode: _positionFocus,
                          textCapitalization:
                              TextCapitalization.words,
                          decoration: const InputDecoration(
                            hintText: 'e.g. Forward',
                            isDense: true,
                            border: InputBorder.none,
                          ),
                          textInputAction: TextInputAction.next,
                          onEditingComplete: _positionFocus.unfocus,
                        )
                      : Text(membership.position ?? '—'),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _detailRow(
                  label: 'Jersey #',
                  child: canEdit
                      ? TextField(
                          controller: _jerseyCtrl,
                          focusNode: _jerseyFocus,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: 'e.g. 10',
                            isDense: true,
                            border: InputBorder.none,
                          ),
                          textInputAction: TextInputAction.done,
                          onEditingComplete: _jerseyFocus.unfocus,
                        )
                      : Text(membership.jerseyNumber != null
                          ? '#${membership.jerseyNumber}'
                          : '—'),
                ),
                if (canEdit) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text('Status',
                              style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13)),
                        ),
                        Expanded(
                          child: _buildStatusButton(
                            membership: membership,
                            canArchive: canArchive,
                            profile: profile,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    dense: true,
                    title: Text('Status',
                        style: TextStyle(
                            color: Colors.grey[700], fontSize: 13)),
                    trailing: StatusBadge(membership.status),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _detailRow({required String label, required Widget child}) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: Colors.grey[700], fontSize: 13)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildStatusButton({
    required TeamMembership membership,
    required bool canArchive,
    required Profile profile,
  }) {
    final segments = <ButtonSegment<MembershipStatus>>[
      const ButtonSegment(
          value: MembershipStatus.active, label: Text('Active')),
      const ButtonSegment(
          value: MembershipStatus.inactive, label: Text('Inactive')),
      if (canArchive)
        const ButtonSegment(
            value: MembershipStatus.archived, label: Text('Archive')),
    ];

    // Clamp displayed value: coaches can't toggle to archived, so show active
    final displayed =
        (!canArchive && membership.status == MembershipStatus.archived)
            ? MembershipStatus.active
            : membership.status == MembershipStatus.pending
                ? MembershipStatus.active
                : membership.status;

    return SegmentedButton<MembershipStatus>(
      segments: segments,
      selected: {displayed},
      showSelectedIcon: false,
      style: ButtonStyle(
        textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12)),
      ),
      onSelectionChanged: (sel) =>
          _handleStatusChange(sel.first, membership, profile),
    );
  }

  Future<void> _handleStatusChange(
    MembershipStatus newStatus,
    TeamMembership membership,
    Profile profile,
  ) async {
    if (newStatus == membership.status) return;

    if (newStatus == MembershipStatus.archived) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Archive player?'),
          content: Text(
            'Archive ${profile.fullName}? '
            'They will no longer appear in the active roster.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    try {
      await ref
          .read(playerProfileNotifierProvider.notifier)
          .updateMembershipStatus(
            membershipId: membership.id,
            status: newStatus,
            profileId: widget.playerId,
            teamId: widget.teamId,
          );
      if (!mounted) return;
      SaveToast.show(context, 'Status updated');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ── Section 4 — Availability ──────────────────────────────────

  Widget _buildAvailabilitySection({
    required Profile profile,
    required bool isOwn,
  }) {
    return _sectionCard(
      title: 'Availability',
      children: [
        SwitchListTile(
          title: const Text('Available this week'),
          subtitle: Text(
            'Shown to coaches for fill-in requests',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          value: profile.availabilityThisWeek,
          activeThumbColor: AppColors.primary,
          onChanged: isOwn
              ? (value) => _handleAvailabilityChange(value, profile)
              : null,
        ),
        const Divider(height: 1, indent: 16, endIndent: 16),
        SwitchListTile(
          title: const Text('Default availability'),
          subtitle: const Text(
            'When off, marked unavailable each week automatically',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          value: profile.defaultAvailability,
          activeThumbColor: AppColors.primary,
          onChanged: isOwn
              ? (value) => _handleDefaultAvailabilityChange(value, profile)
              : null,
        ),
      ],
    );
  }

  Future<void> _handleAvailabilityChange(
      bool available, Profile profile) async {
    try {
      await ref
          .read(playerProfileNotifierProvider.notifier)
          .updateAvailability(
            profileId: profile.id,
            available: available,
            teamId: widget.teamId,
          );
      if (!mounted) return;
      SaveToast.show(context, 'Saved');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleDefaultAvailabilityChange(
      bool available, Profile profile) async {
    try {
      await ref
          .read(rosterRepositoryProvider)
          .updateDefaultAvailability(
            profileId: profile.id,
            defaultAvailable: available,
          );
      ref.invalidate(profileByIdProvider(profile.id));
      if (!mounted) return;
      SaveToast.show(context, 'Saved');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ── Section 5 — Guardians ─────────────────────────────────────

  Widget _buildGuardiansSection({
    required String profileId,
    required bool canManage,
  }) {
    final guardiansAsync = ref.watch(guardianLinksProvider(profileId));

    return _sectionCard(
      title: 'Guardians',
      trailing: canManage
          ? IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'Add guardian',
              onPressed: () {
                final profileData = ref
                    .read(profileByIdProvider(profileId))
                    .valueOrNull;
                final displayName =
                    profileData?.fullName ?? widget.playerId;
                context.push(
                  '/roster/player/${widget.playerId}/add-guardian',
                  extra: AddGuardianArgs(
                    playerProfileId: profileId,
                    playerName: displayName,
                  ),
                );
              },
            )
          : null,
      children: [
        guardiansAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not load guardians',
                style: TextStyle(color: Colors.grey[500])),
          ),
          data: (links) => links.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No guardians linked',
                      style: TextStyle(color: Colors.grey[500])),
                )
              : Column(
                  children: links.map(_buildGuardianRow).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildGuardianRow(GuardianLink g) {
    final name = g.guardianFullName ?? 'Guardian';
    final isCan = g.permissionLevel == GuardianPermission.manage;

    return ListTile(
      leading: AvatarWidget(
          fullName: name, avatarUrl: g.guardianAvatarUrl, size: 36),
      title: Text(name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _chip(
            isCan ? 'Can manage' : 'View only',
            isCan ? Colors.blue[100]! : Colors.grey[200]!,
            isCan ? Colors.blue[800]! : Colors.grey[700]!,
          ),
          const SizedBox(width: 6),
          _chip(
            g.confirmed ? 'Confirmed' : 'Pending',
            g.confirmed ? Colors.green[100]! : Colors.amber[100]!,
            g.confirmed ? Colors.green[800]! : Colors.amber[900]!,
          ),
        ],
      ),
    );
  }

  // ── Section 6 — Fill-in history ───────────────────────────────

  Widget _buildFillInHistorySection(String profileId) {
    final historyAsync = ref.watch(fillInHistoryProvider(profileId));

    return _sectionCard(
      title: 'Fill-in history',
      children: [
        historyAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Could not load history',
                style: TextStyle(color: Colors.grey[500])),
          ),
          data: (rows) => rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No fill-in history',
                      style: TextStyle(color: Colors.grey[500])),
                )
              : Column(
                  children: rows.map((row) {
                    final gameName = row['game_name'] as String? ?? '';
                    final dateRaw = row['event_date'];
                    String dateStr = '';
                    if (dateRaw != null) {
                      try {
                        dateStr = DateFormat('d MMM y').format(
                            DateTime.parse(dateRaw.toString()));
                      } catch (_) {
                        dateStr = dateRaw.toString();
                      }
                    }
                    final divName =
                        row['target_division_name'] as String? ?? '';
                    return ListTile(
                      title: Text(gameName),
                      subtitle: Text(dateStr),
                      trailing: Text(
                        '→ $divName',
                        style: TextStyle(
                            color: Colors.blue[700], fontSize: 13),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  // ── Shared layout helpers ─────────────────────────────────────

  Widget _sectionCard({
    String? title,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    // Teal left accent bar
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: AppTextStyles.label,
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg)),
    );
  }

  String _roleName(UserRole role) {
    switch (role) {
      case UserRole.clubAdmin:
        return 'Club admin';
      case UserRole.coach:
        return 'Coach';
      case UserRole.player:
        return 'Player';
      case UserRole.parent:
        return 'Parent';
    }
  }
}
