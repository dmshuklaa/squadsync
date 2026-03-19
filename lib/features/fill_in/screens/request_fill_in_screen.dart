import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/fill_in/providers/fill_in_providers.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/shared/models/profile.dart';
import 'package:squadsync/shared/widgets/avatar_widget.dart';
import 'package:squadsync/shared/widgets/empty_state_widget.dart';
import 'package:squadsync/shared/widgets/error_state_widget.dart';

/// Arguments for the request fill-in screen.
class RequestFillInArgs {
  const RequestFillInArgs({
    required this.eventId,
    required this.eventTitle,
    required this.targetDivisionId,
  });

  final String eventId;
  final String eventTitle;
  final String targetDivisionId;
}

class RequestFillInScreen extends ConsumerStatefulWidget {
  const RequestFillInScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.targetDivisionId,
  });

  final String eventId;
  final String eventTitle;
  final String targetDivisionId;

  @override
  ConsumerState<RequestFillInScreen> createState() =>
      _RequestFillInScreenState();
}

class _RequestFillInScreenState extends ConsumerState<RequestFillInScreen> {
  String? _selectedPlayerId;
  final _positionController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request fill-in'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e', style: AppTextStyles.bodySmall),
        ),
        data: (profile) {
          final clubId = profile.clubId;
          if (clubId == null) {
            return const Center(
              child: Text('No club found.', style: AppTextStyles.bodySmall),
            );
          }
          return _buildBody(context, ref, profile.id, clubId);
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    String coachId,
    String clubId,
  ) {
    final eligibleAsync = ref.watch(
      eligiblePlayersProvider(
        clubId: clubId,
        targetDivisionId: widget.targetDivisionId,
        eventId: widget.eventId,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Event info header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.primary,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.eventTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Select an eligible player to send a fill-in request',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),

        // Position field
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _positionController,
            decoration: const InputDecoration(
              labelText: 'Position needed (optional)',
              prefixIcon:
                  Icon(Icons.sports, color: AppColors.accent),
            ),
          ),
        ),

        // Section label
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
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
              const Text('ELIGIBLE PLAYERS', style: AppTextStyles.label),
            ],
          ),
        ),

        // Player list
        Expanded(
          child: eligibleAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
            error: (e, _) => ErrorStateWidget(
              message: 'Failed to load eligible players.',
              onRetry: () => ref.invalidate(
                eligiblePlayersProvider(
                  clubId: clubId,
                  targetDivisionId: widget.targetDivisionId,
                  eventId: widget.eventId,
                ),
              ),
            ),
            data: (players) {
              if (players.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.person_off_outlined,
                  title: 'No eligible players',
                  subtitle:
                      'No players from lower divisions are available or have fill-in rules set up',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: players.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
                itemBuilder: (context, i) => _PlayerSelectCard(
                  player: players[i],
                  isSelected: _selectedPlayerId == players[i].id,
                  onTap: () => setState(
                    () => _selectedPlayerId = players[i].id == _selectedPlayerId
                        ? null
                        : players[i].id,
                  ),
                  eventId: widget.eventId,
                ),
              );
            },
          ),
        ),

        // Send button
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed:
                  (_selectedPlayerId == null || _isSending)
                      ? null
                      : () => _sendRequest(context, ref, coachId),
              child: _isSending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Text(
                      'Send fill-in request',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _sendRequest(
    BuildContext context,
    WidgetRef ref,
    String coachId,
  ) async {
    final playerId = _selectedPlayerId;
    if (playerId == null) return;

    setState(() => _isSending = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(fillInRepositoryProvider).createRequest(
            eventId: widget.eventId,
            playerId: playerId,
            requestingCoachId: coachId,
            positionNeeded: _positionController.text.trim(),
          );
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Fill-in request sent!'),
            backgroundColor: AppColors.success,
          ),
        );
        navigator.pop(true);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to send request: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

class _PlayerSelectCard extends ConsumerWidget {
  const _PlayerSelectCard({
    required this.player,
    required this.isSelected,
    required this.onTap,
    required this.eventId,
  });

  final Profile player;
  final bool isSelected;
  final VoidCallback onTap;
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            AvatarWidget(
              fullName: player.fullName,
              avatarUrl: player.avatarUrl,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.fullName,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  _FillInCountLabel(
                    playerId: player.id,
                    clubId: player.clubId ?? '',
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.accent,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

class _FillInCountLabel extends StatefulWidget {
  const _FillInCountLabel({
    required this.playerId,
    required this.clubId,
  });

  final String playerId;
  final String clubId;

  @override
  State<_FillInCountLabel> createState() => _FillInCountLabelState();
}

class _FillInCountLabelState extends State<_FillInCountLabel> {
  int? _count;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final year = DateTime.now().year;
      final response = await supabase
          .from('fill_in_log')
          .select('id')
          .eq('player_id', widget.playerId)
          .gte('created_at', '$year-01-01T00:00:00Z');
      if (mounted) {
        setState(() => _count = (response as List).length);
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_count == null) return const SizedBox.shrink();
    return Text(
      '$_count fill-in${_count == 1 ? '' : 's'} this season',
      style: AppTextStyles.caption,
    );
  }
}
