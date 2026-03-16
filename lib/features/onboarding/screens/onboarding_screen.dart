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
      // GoRouter redirect to /home fires automatically via _AuthChangeNotifier.
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
      // GoRouter redirect to /home fires automatically via _AuthChangeNotifier.
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
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                child: Column(
                  children: [
                    const SquadSyncLogo(size: 64),
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome to SquadSync',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Set up your club or join an existing one',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              // ── TabBar ───────────────────────────────────────
              const TabBar(
                labelColor: AppColors.primary,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: 'Create club'),
                  Tab(text: 'Join club'),
                ],
              ),
              // ── TabBarView (takes remaining space) ───────────
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
      ),
    );
  }

  Widget _buildCreateClubTab(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _createFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
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
              decoration: const InputDecoration(labelText: 'Sport type'),
              items: _sportTypes
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged:
                  isLoading ? null : (v) => setState(() => _selectedSport = v),
              validator: (value) =>
                  value == null ? 'Please select a sport type' : null,
            ),
            const SizedBox(height: 32),
            // Create Club button
            ElevatedButton(
              onPressed: isLoading ? null : _createClub,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
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
    );
  }

  Widget _buildJoinClubTab(bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _joinFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Ask your club admin for the 6-character join code',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
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
                counterText: '', // hide the maxLength counter
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Club code is required';
                }
                if (value.trim().length != 6) {
                  return 'Club code must be exactly 6 characters';
                }
                if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value.trim())) {
                  return 'Club code must contain letters and numbers only';
                }
                return null;
              },
            ),
            // Inline "club not found" error — NOT a SnackBar
            if (_joinCodeError != null) ...[
              const SizedBox(height: 6),
              Text(
                _joinCodeError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            // Join Club button
            ElevatedButton(
              onPressed: isLoading ? null : _joinClub,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
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
    );
  }
}
