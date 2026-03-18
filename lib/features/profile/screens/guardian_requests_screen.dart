import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/roster/providers/guardian_provider.dart';
import 'package:squadsync/features/roster/providers/player_profile_provider.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/guardian_link.dart';
import 'package:squadsync/shared/widgets/avatar_widget.dart';
import 'package:squadsync/shared/widgets/empty_state_widget.dart';

class GuardianRequestsScreen extends ConsumerWidget {
  const GuardianRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingGuardianRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian requests'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: requestsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (requests) {
          if (requests.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.people_outline,
              title: 'No pending requests',
              subtitle: 'Guardian link requests will appear here',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, i) =>
                _RequestCard(link: requests[i]),
          );
        },
      ),
    );
  }
}

class _RequestCard extends ConsumerStatefulWidget {
  const _RequestCard({required this.link});
  final GuardianLink link;

  @override
  ConsumerState<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends ConsumerState<_RequestCard> {
  bool _isAccepting = false;
  bool _isDeclining = false;

  // In pending requests the join is profiles!player_profile_id,
  // so guardianFullName/guardianAvatarUrl hold the player's data.
  String get playerName =>
      widget.link.guardianFullName ?? 'Player';
  String? get playerAvatar => widget.link.guardianAvatarUrl;

  String _permissionLabel(GuardianPermission p) {
    switch (p) {
      case GuardianPermission.view:
        return 'View only — see schedule and receive notifications';
      case GuardianPermission.manage:
        return 'Full manage — can accept fill-in requests on their behalf';
    }
  }

  Future<void> _accept() async {
    setState(() => _isAccepting = true);
    try {
      final repo = ref.read(rosterRepositoryProvider);
      await repo.confirmGuardianLink(widget.link.id);
      ref.invalidate(pendingGuardianRequestsProvider);
      ref.invalidate(guardianLinksProvider(widget.link.playerProfileId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'You are now linked as a guardian for $playerName'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAccepting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _decline() async {
    // Capture linkId and playerProfileId before the dialog opens
    final linkId = widget.link.id;
    final playerProfileId = widget.link.playerProfileId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline this request?'),
        content: Text(
            'You will not be linked as a guardian for $playerName.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isDeclining = true);
    try {
      final repo = ref.read(rosterRepositoryProvider);
      await repo.declineGuardianLink(linkId);
      ref.invalidate(pendingGuardianRequestsProvider);
      ref.invalidate(guardianLinksProvider(playerProfileId));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeclining = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Player row
            Row(
              children: [
                AvatarWidget(
                  fullName: playerName,
                  avatarUrl: playerAvatar,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(playerName, style: AppTextStyles.body),
                      const SizedBox(height: 2),
                      const Text(
                        'wants to link you as a guardian',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Permission level badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 16, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _permissionLabel(widget.link.permissionLevel),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.accentDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_isDeclining || _isAccepting)
                        ? null
                        : _decline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: _isDeclining
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.error,
                            ),
                          )
                        : const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isAccepting || _isDeclining)
                        ? null
                        : _accept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.primary,
                    ),
                    child: _isAccepting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
