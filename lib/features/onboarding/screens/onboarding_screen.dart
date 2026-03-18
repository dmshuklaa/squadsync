import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/core/utils/error_mapper.dart';
import 'package:squadsync/features/onboarding/providers/onboarding_provider.dart';
import 'package:squadsync/shared/widgets/squad_sync_logo.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // ── Create club ────────────────────────────────────────────
  final _createFormKey = GlobalKey<FormState>();
  final _clubNameController = TextEditingController();
  String? _selectedSport;

  // ── Join club ──────────────────────────────────────────────
  final _joinFormKey = GlobalKey<FormState>();
  final _joinCodeController = TextEditingController();
  String? _joinCodeError;

  static const _sportTypes = [
    'Football',
    'Cricket',
    'Netball',
    'Basketball',
    'Rugby League',
    'Rugby Union',
    'Hockey',
    'Volleyball',
    'Swimming',
    'Athletics',
    'Tennis',
    'Other',
  ];

  @override
  void dispose() {
    _clubNameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  Future<void> _createClub() async {
    if (!_createFormKey.currentState!.validate()) return;
    try {
      await ref.read(onboardingNotifierProvider.notifier).createClub(
            _clubNameController.text.trim(),
            _selectedSport!,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthErrorMapper.map(e))),
      );
    }
  }

  Future<void> _joinClub() async {
    setState(() => _joinCodeError = null);
    if (!_joinFormKey.currentState!.validate()) return;
    try {
      await ref.read(onboardingNotifierProvider.notifier).joinClub(
            _joinCodeController.text.trim(),
          );
    } on ClubNotFoundException {
      if (!mounted) return;
      setState(() {
        _joinCodeError = 'Invalid code. Please check with your club admin.';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthErrorMapper.map(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(onboardingNotifierProvider).isLoading;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            // ── Navy header ──────────────────────────────────
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
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Column(
                    children: [
                      const SquadSyncLogo(size: 60),
                      const SizedBox(height: 16),
                      const Text(
                        'Welcome to SquadSync',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set up your club or join an existing one',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── TabBar ───────────────────────────────────────
            Container(
              color: AppColors.surface,
              child: const TabBar(
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.accent,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'Create club'),
                  Tab(text: 'Join club'),
                ],
              ),
            ),

            // ── TabBarView ───────────────────────────────────
            Expanded(
              child: TabBarView(
                children: [
                  _buildCreateClubTab(isLoading),
                  _buildJoinClubTab(isLoading),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateClubTab(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Form(
          key: _createFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Club details', style: AppTextStyles.h3),
              const SizedBox(height: 20),
              // Club name
              TextFormField(
                controller: _clubNameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                enabled: !isLoading,
                decoration: const InputDecoration(
                  labelText: 'Club name',
                  hintText: 'e.g. Northside FC',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Club name is required';
                  }
                  if (value.trim().length < 3) {
                    return 'Club name must be at least 3 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Sport type
              DropdownButtonFormField<String>(
                initialValue: _selectedSport,
                decoration:
                    const InputDecoration(labelText: 'Sport type'),
                items: _sportTypes
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: isLoading
                    ? null
                    : (v) => setState(() => _selectedSport = v),
                validator: (value) =>
                    value == null ? 'Please select a sport type' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: isLoading ? null : _createClub,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Club'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJoinClubTab(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Form(
          key: _joinFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Join your club', style: AppTextStyles.h3),
              const SizedBox(height: 8),
              const Text(
                'Ask your club admin for the 6-character join code',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 20),
              // Join code field
              TextFormField(
                controller: _joinCodeController,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                enabled: !isLoading,
                onChanged: (_) {
                  if (_joinCodeError != null) {
                    setState(() => _joinCodeError = null);
                  }
                },
                onFieldSubmitted: (_) => _joinClub(),
                decoration: const InputDecoration(
                  labelText: 'Club code',
                  hintText: 'e.g. AB3X7K',
                  counterText: '',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Club code is required';
                  }
                  if (value.trim().length != 6) {
                    return 'Club code must be exactly 6 characters';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9]+$')
                      .hasMatch(value.trim())) {
                    return 'Club code must contain letters and numbers only';
                  }
                  return null;
                },
              ),
              if (_joinCodeError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _joinCodeError!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: isLoading ? null : _joinClub,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Join Club'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
