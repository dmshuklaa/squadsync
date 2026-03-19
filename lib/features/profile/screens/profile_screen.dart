import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadsync/core/router/app_router.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/auth/providers/auth_provider.dart';
import 'package:squadsync/features/roster/providers/guardian_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    final user = supabase.auth.currentUser;
    final email = user?.email ?? '—';
    final fullName =
        (user?.userMetadata?['full_name'] as String?) ?? email;
    final role = _formatRole(
        (user?.userMetadata?['role'] as String?) ?? '');

    // Guardian requests — only watch when logged in
    final requestsAsync = ref.watch(pendingGuardianRequestsProvider);
    final pendingCount =
        requestsAsync.whenOrNull(data: (list) => list.length) ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Navy banner header ─────────────────────────────
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 28),
                  child: Column(
                    children: [
                      AvatarWidget(
                        fullName: fullName,
                        size: 80,
                        showRing: true,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (role.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppColors.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.accent
                                    .withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              color: AppColors.accentLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Guardian requests banner (shown when pending > 0) ──
            if (pendingCount > 0)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningSurface,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.warning, width: 1),
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
                      onPressed: () =>
                          context.push(kGuardianRequestsRoute),
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

            // ── Account section ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 12, 8, 4),
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
                          const Text('ACCOUNT', style: AppTextStyles.label),
                        ],
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.email_outlined,
                          color: AppColors.accent),
                      title: const Text('Email'),
                      subtitle: Text(email),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.badge_outlined,
                          color: AppColors.accent),
                      title: const Text('Role'),
                      subtitle: Text(role.isNotEmpty ? role : '—'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Actions section ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 12, 8, 4),
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
                          const Text('ACTIONS', style: AppTextStyles.label),
                        ],
                      ),
                    ),
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
                      onTap: () =>
                          context.push(kGuardianRequestsRoute),
                    ),
                    if ((user?.userMetadata?['role'] as String?) ==
                        UserRole.clubAdmin.toJson()) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.swap_horiz,
                            color: AppColors.accent),
                        title: const Text('Fill-in rules'),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textHint),
                        onTap: () =>
                            context.push(kFillInRulesRoute),
                      ),
                    ],
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.logout,
                          color: AppColors.error),
                      title: const Text(
                        'Sign Out',
                        style: TextStyle(color: AppColors.error),
                      ),
                      onTap: isLoading ? null : _signOut,
                      trailing: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
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
      ),
    );
  }

  String _formatRole(String raw) {
    switch (raw) {
      case 'club_admin':
        return 'Club Admin';
      case 'coach':
        return 'Coach';
      case 'player':
        return 'Player';
      case 'parent':
        return 'Parent';
      default:
        return raw;
    }
  }
}
