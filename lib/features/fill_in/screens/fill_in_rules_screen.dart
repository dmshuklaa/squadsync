import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/fill_in/providers/fill_in_providers.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/shared/models/club.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/fill_in_rule.dart';
import 'package:squadsync/shared/widgets/empty_state_widget.dart';
import 'package:squadsync/shared/widgets/error_state_widget.dart';

class FillInRulesScreen extends ConsumerWidget {
  const FillInRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fill-in rules'),
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
          if (profile.role != UserRole.clubAdmin) {
            return const Center(
              child: Text(
                'Access denied.\nOnly club admins can manage fill-in rules.',
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
            );
          }
          final clubId = profile.clubId;
          if (clubId == null) {
            return const Center(
              child: Text('No club found.', style: AppTextStyles.bodySmall),
            );
          }
          return _RulesBody(clubId: clubId);
        },
      ),
    );
  }
}

class _RulesBody extends ConsumerWidget {
  const _RulesBody({required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(fillInRulesProvider(clubId));

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add rule',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: () => _showAddRuleSheet(context, ref, clubId),
      ),
      body: Column(
        children: [
          _FillInModeCard(clubId: clubId),
          Expanded(
            child: rulesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => ErrorStateWidget(
          message: 'Failed to load rules.',
          onRetry: () => ref.invalidate(fillInRulesProvider(clubId)),
        ),
        data: (rules) {
          if (rules.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.swap_horiz,
              title: 'No fill-in rules',
              subtitle:
                  'Add rules to allow players from lower divisions to fill in for higher division games',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _RuleCard(
              rule: rules[i],
              onToggle: (val) async {
                await ref
                    .read(fillInRepositoryProvider)
                    .toggleRule(rules[i].id, val);
                ref.invalidate(fillInRulesProvider(clubId));
              },
              onDelete: () async {
                await ref
                    .read(fillInRepositoryProvider)
                    .deleteRule(rules[i].id);
                ref.invalidate(fillInRulesProvider(clubId));
              },
            ),
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddRuleSheet(
    BuildContext context,
    WidgetRef ref,
    String clubId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddRuleSheet(clubId: clubId),
    );
    ref.invalidate(fillInRulesProvider(clubId));
  }
}

// ── Fill-in mode toggle card ─────────────────────────────────

class _FillInModeCard extends ConsumerWidget {
  const _FillInModeCard({required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubAsync = ref.watch(clubProvider(clubId));
    return clubAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (Club? club) {
        final isOpen = club?.isOpenMode ?? false;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 40,
                decoration: BoxDecoration(
                  color: isOpen ? AppColors.accent : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open fill-in mode',
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      isOpen
                          ? 'Any club member can fill in for any team'
                          : 'Only players matching rules below can fill in',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                value: isOpen,
                onChanged: (val) async {
                  try {
                    await ref
                        .read(fillInModeNotifierProvider.notifier)
                        .setMode(
                          clubId: clubId,
                          mode: val ? 'open' : 'restricted',
                        );
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Failed to update fill-in mode')),
                    );
                  }
                },
                activeThumbColor: AppColors.accent,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onToggle,
    required this.onDelete,
  });

  final FillInRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(rule.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                color: rule.enabled ? AppColors.accent : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${rule.sourceDivisionName ?? rule.sourceDivisionId} → ${rule.targetDivisionName ?? rule.targetDivisionId}',
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (rule.minAge != null)
                    Text(
                      'Min age: ${rule.minAge}',
                      style: AppTextStyles.bodySmall,
                    ),
                ],
              ),
            ),
            Switch(
              value: rule.enabled,
              onChanged: onToggle,
              activeThumbColor: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddRuleSheet extends ConsumerStatefulWidget {
  const _AddRuleSheet({required this.clubId});

  final String clubId;

  @override
  ConsumerState<_AddRuleSheet> createState() => _AddRuleSheetState();
}

class _AddRuleSheetState extends ConsumerState<_AddRuleSheet> {
  String? _sourceDivisionId;
  String? _targetDivisionId;
  final _minAgeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _minAgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add fill-in rule', style: AppTextStyles.h3),
          const SizedBox(height: 20),
          _DivisionsDropdowns(
            clubId: widget.clubId,
            sourceId: _sourceDivisionId,
            targetId: _targetDivisionId,
            onSourceChanged: (v) => setState(() => _sourceDivisionId = v),
            onTargetChanged: (v) => setState(() => _targetDivisionId = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _minAgeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Min age (optional)',
              border: OutlineInputBorder(),
              labelStyle: TextStyle(color: AppColors.textSecondary),
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
              onPressed: _isLoading ? null : _addRule,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Text(
                      'Add rule',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addRule() async {
    final src = _sourceDivisionId;
    final tgt = _targetDivisionId;
    if (src == null || tgt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both source and target divisions'),
        ),
      );
      return;
    }
    if (src == tgt) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source and target divisions must be different'),
        ),
      );
      return;
    }
    final minAge = int.tryParse(_minAgeController.text.trim());
    setState(() => _isLoading = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(fillInRepositoryProvider).createRule(
            clubId: widget.clubId,
            sourceDivisionId: src,
            targetDivisionId: tgt,
            minAge: minAge,
          );
      if (mounted) navigator.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to add rule: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _DivisionsDropdowns extends ConsumerWidget {
  const _DivisionsDropdowns({
    required this.clubId,
    required this.sourceId,
    required this.targetId,
    required this.onSourceChanged,
    required this.onTargetChanged,
  });

  final String clubId;
  final String? sourceId;
  final String? targetId;
  final ValueChanged<String?> onSourceChanged;
  final ValueChanged<String?> onTargetChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final divisionsAsync = ref.watch(clubDivisionsProvider);

    return divisionsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.accent,
        ),
      ),
      error: (e, _) => const Text(
        'Failed to load divisions',
        style: TextStyle(color: AppColors.error),
      ),
      data: (divs) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: sourceId,
            decoration: const InputDecoration(
              labelText: 'Players FROM',
              border: OutlineInputBorder(),
              labelStyle: TextStyle(color: AppColors.textSecondary),
            ),
            items: divs
                .map(
                  (d) => DropdownMenuItem(
                    value: d.id,
                    child: Text(d.name),
                  ),
                )
                .toList(),
            onChanged: onSourceChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: targetId,
            decoration: const InputDecoration(
              labelText: 'Can fill in FOR',
              border: OutlineInputBorder(),
              labelStyle: TextStyle(color: AppColors.textSecondary),
            ),
            items: divs
                .map(
                  (d) => DropdownMenuItem(
                    value: d.id,
                    child: Text(d.name),
                  ),
                )
                .toList(),
            onChanged: onTargetChanged,
          ),
        ],
      ),
    );
  }
}
