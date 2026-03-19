import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/events/providers/events_providers.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/team.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key, this.teamId});

  final String? teamId;

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  EventType _eventType = EventType.game;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedTeamId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedTeamId = widget.teamId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(userTeamsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Team selector (when no team pre-selected) ─────
            if (widget.teamId == null) ...[
              teamsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => Text(
                  'Error loading teams: $e',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                ),
                data: (teams) => _buildTeamSelector(teams),
              ),
              const SizedBox(height: 12),
            ],

            // ── Event type ────────────────────────────────────
            _sectionCard([
              Text(
                'EVENT TYPE',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: EventType.values.map((type) {
                  final isSelected = _eventType == type;
                  return ChoiceChip(
                    label: Text(
                      type.label,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.accent,
                    backgroundColor: AppColors.background,
                    showCheckmark: false,
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : AppColors.border,
                    ),
                    onSelected: (_) => setState(() => _eventType = type),
                  );
                }).toList(),
              ),
            ]),

            const SizedBox(height: 12),

            // ── Title ─────────────────────────────────────────
            _sectionCard([
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: InputBorder.none,
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
            ]),

            const SizedBox(height: 12),

            // ── Date & time ───────────────────────────────────
            _sectionCard([
              Text(
                'DATE & TIME',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              _DateTimeTile(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: _selectedDate != null
                    ? DateFormat('EEE, d MMM yyyy').format(_selectedDate!)
                    : null,
                placeholder: 'Select date',
                onTap: _pickDate,
              ),
              const Divider(height: 1, color: AppColors.border),
              _DateTimeTile(
                icon: Icons.access_time_outlined,
                label: 'Start time',
                value: _startTime?.format(context),
                placeholder: 'Select start time',
                onTap: _pickStartTime,
              ),
              const Divider(height: 1, color: AppColors.border),
              _DateTimeTile(
                icon: Icons.access_time_outlined,
                label: 'End time (optional)',
                value: _endTime?.format(context),
                placeholder: 'Not set',
                onTap: _pickEndTime,
              ),
            ]),

            const SizedBox(height: 12),

            // ── Location ──────────────────────────────────────
            _sectionCard([
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location (optional)',
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.location_on_outlined,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ]),

            const SizedBox(height: 12),

            // ── Notes ─────────────────────────────────────────
            _sectionCard([
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: InputBorder.none,
                  alignLabelWithHint: true,
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ]),

            const SizedBox(height: 24),

            // ── Submit ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.primary,
                  disabledBackgroundColor:
                      AppColors.accent.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary,
                        ),
                      )
                    : const Text(
                        'Create Event',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamSelector(List<Team> teams) {
    if (teams.isEmpty) {
      return _sectionCard([
        Text(
          'No teams available. You must be part of a team to create events.',
          style: AppTextStyles.bodySmall,
        ),
      ]);
    }

    // Auto-select first team if none selected
    if (_selectedTeamId == null && teams.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedTeamId == null) {
          setState(() => _selectedTeamId = teams.first.id);
        }
      });
    }

    return _sectionCard([
      DropdownButtonFormField<String>(
        // ignore: deprecated_member_use
        value: _selectedTeamId,
        decoration: const InputDecoration(
          labelText: 'Team *',
          border: InputBorder.none,
          labelStyle: TextStyle(color: AppColors.textSecondary),
        ),
        items: teams
            .map(
              (t) => DropdownMenuItem(
                value: t.id,
                child: Text(
                  '${t.divisionName ?? 'Division'} · ${t.name}',
                ),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _selectedTeamId = v),
        validator: (v) => v == null ? 'Please select a team' : null,
      ),
    ]);
  }

  Widget _sectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            secondary: AppColors.accent,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final teamId = _selectedTeamId ?? widget.teamId;

    if (teamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a team')),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date')),
      );
      return;
    }

    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start time')),
      );
      return;
    }

    final date = _selectedDate!;
    final startsAt = DateTime(
      date.year,
      date.month,
      date.day,
      _startTime!.hour,
      _startTime!.minute,
    );
    final endsAt = _endTime != null
        ? DateTime(
            date.year,
            date.month,
            date.day,
            _endTime!.hour,
            _endTime!.minute,
          )
        : null;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(eventsRepositoryProvider);
      await repo.createEvent(
        teamId: teamId,
        title: _titleController.text.trim(),
        eventType: _eventType,
        startsAt: startsAt,
        endsAt: endsAt ?? startsAt.add(const Duration(hours: 2)),
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      ref.invalidate(upcomingEventsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created!')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create event: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textHint, size: 20),
            const SizedBox(width: 12),
            Text(label, style: AppTextStyles.bodySmall),
            const Spacer(),
            Text(
              value ?? placeholder,
              style: AppTextStyles.bodySmall.copyWith(
                color: value != null
                    ? AppColors.textPrimary
                    : AppColors.textHint,
                fontWeight:
                    value != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: AppColors.textHint,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
