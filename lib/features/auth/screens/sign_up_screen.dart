import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadsync/core/router/app_router.dart';
import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/core/utils/error_mapper.dart';
import 'package:squadsync/core/utils/validators.dart';
import 'package:squadsync/features/auth/providers/auth_provider.dart';
import 'package:squadsync/shared/models/enums.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  UserRole _selectedRole = UserRole.player;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final hasSession = await ref.read(authNotifierProvider.notifier).signUp(
            _emailController.text,
            _passwordController.text,
            _fullNameController.text,
            _selectedRole,
          );
      if (!mounted) return;
      // No immediate session means email confirmation is required.
      if (!hasSession) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Check your email to confirm.'),
            duration: Duration(seconds: 6),
          ),
        );
        context.go(kSignInRoute);
      }
      // If hasSession == true, GoRouter redirect fires automatically.
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Create account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Join your club on SquadSync',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                // Full name
                TextFormField(
                  controller: _fullNameController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: Validators.fullName,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),
                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: Validators.email,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),
                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: Validators.password,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),
                // Confirm password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signUp(),
                  decoration: InputDecoration(
                    labelText: 'Confirm password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                          () => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  enabled: !isLoading,
                ),
                const SizedBox(height: 24),
                // Role selector
                Text(
                  'I am a...',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                SegmentedButton<UserRole>(
                  segments: const [
                    ButtonSegment(
                      value: UserRole.player,
                      label: Text('Player'),
                    ),
                    ButtonSegment(
                      value: UserRole.coach,
                      label: Text('Coach'),
                    ),
                    ButtonSegment(
                      value: UserRole.parent,
                      label: Text('Parent'),
                    ),
                  ],
                  selected: {_selectedRole},
                  multiSelectionEnabled: false,
                  onSelectionChanged: isLoading
                      ? null
                      : (Set<UserRole> selection) =>
                          setState(() => _selectedRole = selection.first),
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? Colors.white
                          : AppColors.primary,
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? AppColors.primary
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Create account button
                ElevatedButton(
                  onPressed: isLoading ? null : _signUp,
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
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 16),
                // Sign in link
                Center(
                  child: TextButton(
                    onPressed: isLoading ? null : () => context.go(kSignInRoute),
                    child: const Text('Already have an account? Sign in'),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
