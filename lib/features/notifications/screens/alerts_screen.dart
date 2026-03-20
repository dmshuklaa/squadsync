import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:squadsync/core/router/app_router.dart';
import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/fill_in/data/fill_in_repository.dart';
import 'package:squadsync/features/notifications/providers/notifications_providers.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/fill_in_request.dart';
import 'package:squadsync/shared/models/notification_item.dart';
import 'package:squadsync/shared/widgets/empty_state_widget.dart';
import 'package:squadsync/shared/widgets/error_state_widget.dart';
import 'package:squadsync/shared/widgets/loading_shimmer.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      _subscription = supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('profile_id', userId)
          .listen((_) {
            ref.invalidate(notificationsProvider);
            ref.invalidate(unreadCountProvider);
          });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Alerts'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () async {
                final userId = supabase.auth.currentUser?.id;
                if (userId == null) return;
                final repo = ref.read(notificationsRepositoryProvider);
                await repo.markAllAsRead(userId);
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadCountProvider);
              },
              child: const Text(
                'Mark all read',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Fill-in requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _AllNotificationsTab(),
          const _FillInRequestsTab(),
        ],
      ),
    );
  }
}

// ── Tab 1: All notifications ───────────────────────────────────────────────

class _AllNotificationsTab extends ConsumerWidget {
  const _AllNotificationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return notificationsAsync.when(
      loading: () => const RosterShimmer(),
      error: (e, _) => ErrorStateWidget(
        message: 'Error loading alerts: $e',
        onRetry: () => ref.invalidate(notificationsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.notifications_none,
            title: 'No alerts yet',
            subtitle:
                'Fill-in requests, guardian links, and event reminders will appear here',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          separatorBuilder: (context, _) =>
              const Divider(height: 1, indent: 72, endIndent: 16),
          itemBuilder: (context, i) =>
              _NotificationTile(notification: items[i]),
        );
      },
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final NotificationItem notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _typeColor(notification.type);
    final icon = _typeIcon(notification.type);

    return ListTile(
      tileColor:
          notification.read ? null : AppColors.accent.withValues(alpha: 0.05),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight:
              notification.read ? FontWeight.normal : FontWeight.bold,
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notification.body, style: AppTextStyles.bodySmall),
          const SizedBox(height: 2),
          Text(
            _timeAgo(notification.createdAt),
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
      trailing: notification.read
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
      isThreeLine: true,
      onTap: () async {
        // ignore: avoid_print
        print('[Alerts] tapped notification: ${notification.id} read=${notification.read}');
        if (!notification.read) {
          final repo = ref.read(notificationsRepositoryProvider);
          await repo.markAsRead(notification.id);
          ref.invalidate(notificationsProvider);
          ref.invalidate(unreadCountProvider);
        }
        if (!context.mounted) return;
        _navigateToRelated(context, ref, notification);
      },
    );
  }

  void _navigateToRelated(
      BuildContext context, WidgetRef ref, NotificationItem n) {
    switch (n.type) {
      case NotificationType.fillInRequest:
        if (n.relatedId != null) {
          context.push('/fill-in/respond/${n.relatedId}');
        }
      case NotificationType.guardianRequest:
        context.push(kGuardianRequestsRoute);
      case NotificationType.eventReminder:
        if (n.relatedId != null) {
          context.push('/events/${n.relatedId}');
        }
      default:
        break;
    }
  }

  IconData _typeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.fillInRequest:
        return Icons.sports;
      case NotificationType.fillInAccepted:
        return Icons.check_circle_outline;
      case NotificationType.fillInDeclined:
        return Icons.cancel_outlined;
      case NotificationType.guardianRequest:
        return Icons.family_restroom;
      case NotificationType.guardianAccepted:
        return Icons.verified_user_outlined;
      case NotificationType.eventReminder:
        return Icons.event_outlined;
      case NotificationType.general:
        return Icons.notifications_outlined;
    }
  }

  Color _typeColor(NotificationType type) {
    switch (type) {
      case NotificationType.fillInRequest:
        return AppColors.accent;
      case NotificationType.fillInAccepted:
        return AppColors.success;
      case NotificationType.fillInDeclined:
        return AppColors.error;
      case NotificationType.guardianRequest:
        return AppColors.warning;
      case NotificationType.guardianAccepted:
        return AppColors.success;
      case NotificationType.eventReminder:
        return AppColors.primary;
      case NotificationType.general:
        return AppColors.textSecondary;
    }
  }
}

// ── Tab 2: Fill-in requests ────────────────────────────────────────────────

class _FillInRequestsTab extends ConsumerWidget {
  const _FillInRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myPendingFillInRequestsProvider);

    return requestsAsync.when(
      loading: () => const RosterShimmer(),
      error: (e, _) => ErrorStateWidget(
        message: 'Error loading requests: $e',
        onRetry: () => ref.invalidate(myPendingFillInRequestsProvider),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.sports,
            title: 'No pending fill-in requests',
            subtitle:
                'When a coach requests you as a fill-in player it will appear here',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (context, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _FillInRequestCard(request: requests[i]),
        );
      },
    );
  }
}

class _FillInRequestCard extends ConsumerStatefulWidget {
  const _FillInRequestCard({required this.request});

  final FillInRequest request;

  @override
  ConsumerState<_FillInRequestCard> createState() =>
      _FillInRequestCardState();
}

class _FillInRequestCardState extends ConsumerState<_FillInRequestCard> {
  bool _loading = false;

  Future<void> _respond(FillInRequestStatus status) async {
    setState(() => _loading = true);
    try {
      await const FillInRepository().respondToRequest(
        requestId: widget.request.id,
        status: status,
      );
      ref.invalidate(myPendingFillInRequestsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == FillInRequestStatus.accepted
                ? 'Fill-in accepted!'
                : 'Fill-in declined',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Event info ────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    req.eventTitle ?? 'Event',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Requested by ${req.coachFullName ?? 'Coach'}',
                    style: AppTextStyles.bodySmall,
                  ),
                  if (req.positionNeeded != null &&
                      req.positionNeeded!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Position: ${req.positionNeeded}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Time + actions ────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeAgo(req.requestedAt),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () =>
                            _respond(FillInRequestStatus.declined),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Decline',
                            style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            _respond(FillInRequestStatus.accepted),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          elevation: 0,
                        ),
                        child: const Text('Accept',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return DateFormat('d MMM').format(dt);
}
