import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/events/providers/events_providers.dart';
import 'package:squadsync/features/fill_in/providers/fill_in_providers.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/widgets/avatar_widget.dart';

class RespondFillInScreen extends ConsumerStatefulWidget {
  const RespondFillInScreen({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  ConsumerState<RespondFillInScreen> createState() =>
      _RespondFillInScreenState();
}

class _RespondFillInScreenState extends ConsumerState<RespondFillInScreen> {
  bool _isResponding = false;

  @override
  Widget build(BuildContext context) {
    final requestAsync =
        ref.watch(fillInRequestByIdProvider(widget.requestId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fill-in request'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: requestAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(
          child: Text('Error loading request: $e',
              style: AppTextStyles.bodySmall),
        ),
        data: (request) {
          if (request == null) {
            return const Center(
              child: Text(
                'Request not found',
                style: AppTextStyles.bodySmall,
              ),
            );
          }

          final isPending = request.status == FillInRequestStatus.pending;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Player card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      AvatarWidget(
                        fullName:
                            request.playerFullName ?? 'Player',
                        avatarUrl: request.playerAvatarUrl,
                        size: 64,
                        showRing: true,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        request.playerFullName ?? 'Unknown player',
                        style: AppTextStyles.h3,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      _StatusBadge(status: request.status),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Request details card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 16,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                              'REQUEST DETAILS', style: AppTextStyles.label),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _DetailRow(
                        icon: Icons.event_outlined,
                        label: 'Event',
                        value: request.eventTitle ?? '—',
                      ),
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: 'Requested by',
                        value: request.coachFullName ?? '—',
                      ),
                      if (request.positionNeeded != null &&
                          request.positionNeeded!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.sports_outlined,
                          label: 'Position needed',
                          value: request.positionNeeded!,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _DetailRow(
                        icon: Icons.schedule_outlined,
                        label: 'Requested at',
                        value: DateFormat('EEE d MMM, h:mm a')
                            .format(request.requestedAt.toLocal()),
                      ),
                      if (request.respondedAt != null) ...[
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.check_circle_outline,
                          label: 'Responded at',
                          value: DateFormat('EEE d MMM, h:mm a')
                              .format(request.respondedAt!.toLocal()),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons (only shown when pending)
                if (isPending) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _isResponding
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text(
                        'Accept',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: _isResponding
                          ? null
                          : () => _respond(
                                context,
                                ref,
                                FillInRequestStatus.accepted,
                                request.eventId,
                              ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(
                            color: AppColors.error, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text(
                        'Decline',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      onPressed: _isResponding
                          ? null
                          : () => _respond(
                                context,
                                ref,
                                FillInRequestStatus.declined,
                                request.eventId,
                              ),
                    ),
                  ),
                ],

                SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 16,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    FillInRequestStatus status,
    String eventId,
  ) async {
    setState(() => _isResponding = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(fillInRepositoryProvider).respondToRequest(
            requestId: widget.requestId,
            status: status,
          );
      ref.invalidate(fillInRequestByIdProvider(widget.requestId));
      ref.invalidate(rsvpCountsProvider(eventId));
      ref.invalidate(myRsvpProvider(eventId));
      ref.invalidate(eventRsvpsProvider(eventId));
      if (mounted) {
        final label =
            status == FillInRequestStatus.accepted ? 'accepted' : 'declined';
        messenger.showSnackBar(
          SnackBar(
            content: Text('Request $label.'),
            backgroundColor: status == FillInRequestStatus.accepted
                ? AppColors.success
                : AppColors.error,
          ),
        );
        navigator.pop(true);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to respond: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResponding = false);
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(value, style: AppTextStyles.body),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final FillInRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      FillInRequestStatus.pending => (
          'Pending',
          AppColors.pendingSurface,
          AppColors.pendingAmber,
        ),
      FillInRequestStatus.accepted => (
          'Accepted',
          AppColors.activeSurface,
          AppColors.activeGreen,
        ),
      FillInRequestStatus.declined => (
          'Declined',
          AppColors.errorSurface,
          AppColors.error,
        ),
      FillInRequestStatus.expired => (
          'Expired',
          AppColors.inactiveSurface,
          AppColors.inactiveGrey,
        ),
      FillInRequestStatus.cancelled => (
          'Cancelled',
          AppColors.inactiveSurface,
          AppColors.inactiveGrey,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
