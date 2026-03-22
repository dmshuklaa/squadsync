import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadsync/core/router/app_router.dart';
import 'package:squadsync/core/supabase/supabase_client.dart';
import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/roster/providers/roster_providers.dart';
import 'package:squadsync/shared/widgets/squad_sync_logo.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (e, _) => Center(
            child: Text('Error: $e',
                style: AppTextStyles.body.copyWith(color: Colors.white)),
          ),
          data: (profile) => _WelcomeBody(clubId: profile.clubId),
        ),
      ),
    );
  }
}

class _WelcomeBody extends StatefulWidget {
  const _WelcomeBody({required this.clubId});

  final String? clubId;

  @override
  State<_WelcomeBody> createState() => _WelcomeBodyState();
}

class _WelcomeBodyState extends State<_WelcomeBody> {
  String? _joinCode;

  @override
  void initState() {
    super.initState();
    if (widget.clubId != null) _loadJoinCode();
  }

  Future<void> _loadJoinCode() async {
    try {
      final data = await supabase
          .from('clubs')
          .select('join_code')
          .eq('id', widget.clubId!)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _joinCode = data?['join_code'] as String?;
        });
      }
    } catch (_) {}
  }

  void _copyCode() {
    final code = _joinCode;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Join code copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SquadSyncLogo(size: 72, showTagline: false),
            const SizedBox(height: 32),
            const Text(
              'Your club is ready!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Share this code with your players so they can join.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // ── Join code display ────────────────────────────
            Text(
              'CLUB JOIN CODE',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Text(
                _joinCode ?? '······',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                  letterSpacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _joinCode != null ? _copyCode : null,
              icon: const Icon(Icons.copy_outlined, size: 16),
              label: const Text('Copy code'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
              ),
            ),

            const SizedBox(height: 40),

            // ── CTA ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () => context.go(kHomeRoute),
                child: const Text(
                  'Go to my club',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
