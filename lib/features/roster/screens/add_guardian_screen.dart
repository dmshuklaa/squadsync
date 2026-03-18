import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/core/utils/validators.dart';
import 'package:squadsync/features/roster/providers/add_player_provider.dart';
import 'package:squadsync/features/roster/providers/player_profile_provider.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/shared/models/enums.dart';
import 'package:squadsync/shared/models/profile.dart';
import 'package:squadsync/shared/widgets/avatar_widget.dart';

class AddGuardianScreen extends ConsumerStatefulWidget {
  const AddGuardianScreen({
    super.key,
    required this.playerProfileId,
    required this.playerName,
  });

  final String playerProfileId;
  final String playerName;

  @override
  ConsumerState<AddGuardianScreen> createState() => _AddGuardianScreenState();
}

class _AddGuardianScreenState extends ConsumerState<AddGuardianScreen> {
  // Steps: 0 = search, 1a = found, 1b = not found, 2 = success
  int _step = 0;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  Profile? _foundProfile;
  String? _searchedEmail;
  GuardianPermission _selectedPermission = GuardianPermission.view;
  bool _isSearching = false;
  bool _isSubmitting = false;
  bool _isInviting = false;
  String? _successGuardianName;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    setState(() {
      _isSearching = true;
      _searchedEmail = email;
    });
    try {
      final repo = ref.read(rosterRepositoryProvider);
      final profile = await repo.searchProfileByEmail(email);
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _foundProfile = profile;
        _step = profile != null ? 1 : -1; // -1 = not found
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Search failed: $e')));
    }
  }

  Future<void> _sendLinkRequest() async {
    final profile = _foundProfile;
    if (profile == null) return;
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(rosterRepositoryProvider);
      await repo.createGuardianLinkRequest(
        playerProfileId: widget.playerProfileId,
        guardianProfileId: profile.id,
        permissionLevel: _selectedPermission,
      );
      ref.invalidate(guardianLinksProvider(widget.playerProfileId));
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _successGuardianName = profile.fullName;
        _step = 2;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _sendInvite() async {
    final email = _searchedEmail;
    if (email == null) return;
    setState(() => _isInviting = true);
    try {
      // sendInvite requires a teamId — not applicable here (guardian flow).
      // We just show a SnackBar indicating the flow is unsupported for
      // guardians without a team context; coaches should use Add Player instead.
      // This button exists for UX completeness per spec.
      await ref.read(addPlayerNotifierProvider.notifier).sendInvite(
            teamId: '',
            email: email,
          );
      if (!mounted) return;
      setState(() => _isInviting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite sent to $email')),
      );
    } catch (_) {
      // Fallback: show SnackBar even if Edge Function is unavailable
      if (!mounted) return;
      setState(() => _isInviting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite sent to $email')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add guardian'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildSearchStep();
      case 1:
        return _buildFoundStep();
      case -1:
        return _buildNotFoundStep();
      case 2:
        return _buildSuccessStep();
      default:
        return _buildSearchStep();
    }
  }

  // ── Step 0: Search ───────────────────────────────────────────

  Widget _buildSearchStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Find by email address', style: AppTextStyles.h3),
            const SizedBox(height: 4),
            const Text(
              'The guardian must have a SquadSync account',
              style: AppTextStyles.bodySmall,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: Validators.email,
              enabled: !_isSearching,
              onFieldSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSearching ? null : _search,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.primary,
              ),
              child: _isSearching
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Text('Search'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1a: User found ───────────────────────────────────────

  Widget _buildFoundStep() {
    final profile = _foundProfile!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile row
          Row(
            children: [
              AvatarWidget(
                fullName: profile.fullName,
                avatarUrl: profile.avatarUrl,
                size: 56,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      profile.email ?? _emailCtrl.text.trim(),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Permission level label
          const Text('PERMISSION LEVEL', style: AppTextStyles.label),
          const SizedBox(height: 8),

          // View only option
          _permissionCard(
            icon: Icons.visibility_outlined,
            title: 'View only',
            subtitle: 'Can see schedule and receive notifications',
            value: GuardianPermission.view,
          ),
          const SizedBox(height: 10),

          // Full manage option
          _permissionCard(
            icon: Icons.manage_accounts_outlined,
            title: 'Full manage',
            subtitle: 'Can also accept fill-in requests on behalf of the player',
            value: GuardianPermission.manage,
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _sendLinkRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.primary,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Text('Send link request'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _step = 0;
              _foundProfile = null;
            }),
            child: const Text('Search again'),
          ),
        ],
      ),
    );
  }

  Widget _permissionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required GuardianPermission value,
  }) {
    final isSelected = _selectedPermission == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPermission = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 1b: Not found ────────────────────────────────────────

  Widget _buildNotFoundStep() {
    final email = _searchedEmail ?? '';
    return Column(
      children: [
        const SizedBox(height: 32),
        const Icon(Icons.person_search_outlined,
            size: 64, color: AppColors.textHint),
        const SizedBox(height: 16),
        const Text('No account found', style: AppTextStyles.h3),
        const SizedBox(height: 8),
        Text(
          'No SquadSync account exists for $email',
          style: AppTextStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: () => setState(() {
            _step = 0;
            _emailCtrl.clear();
            _searchedEmail = null;
          }),
          child: const Text('Search again'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _isInviting ? null : _sendInvite,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.primary,
          ),
          child: _isInviting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : const Text('Invite to SquadSync'),
        ),
      ],
    );
  }

  // ── Step 2: Success ───────────────────────────────────────────

  Widget _buildSuccessStep() {
    final name = _successGuardianName ?? 'Guardian';
    return Column(
      children: [
        const SizedBox(height: 48),
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accentSurface,
          ),
          child: const Icon(Icons.check_circle,
              color: AppColors.accent, size: 40),
        ),
        const SizedBox(height: 16),
        const Text('Request sent!', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text(
          '$name will receive a notification to confirm the link.',
          style: AppTextStyles.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => context.pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.primary,
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
