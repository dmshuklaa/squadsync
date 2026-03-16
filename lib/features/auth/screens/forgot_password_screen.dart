import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadsync/core/router/app_router.dart';
import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/core/utils/error_mapper.dart';
import 'package:squadsync/core/utils/validators.dart';
import 'package:squadsync/features/auth/providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .sendPasswordResetEmail(_emailController.text);
      if (!mounted) return;
      setState(() => _emailSent = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthErrorMapper.map(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _emailSent ? _SuccessView() : _FormView(
            formKey: _formKey,
            emailController: _emailController,
            isLoading: isLoading,
            onSubmit: _sendReset,
          ),
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    required this.formKey,
    required this.emailController,
    required this.isLoading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Reset password',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Enter your email address and we'll send you a link to reset your password.",
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            decoration: const InputDecoration(labelText: 'Email'),
            validator: Validators.email,
            enabled: !isLoading,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
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
                : const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 72),
        const SizedBox(height: 24),
        const Text(
          'Email sent!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'Check your inbox for a password reset link.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        TextButton(
          onPressed: () => context.go(kSignInRoute),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}
