import 'package:flutter/material.dart';
import 'package:squadsync/core/theme/app_theme.dart';

/// Temporary placeholder sign-in screen.
/// Will be replaced with full auth UI in Prompt 1.3.
class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SquadSync')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SquadSync',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sports club roster management',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: null, // TODO: implement in Prompt 1.3
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
