import 'package:flutter/material.dart';

import 'package:squadsync/core/theme/app_theme.dart';

/// Create event screen — Sprint 3.2.
class CreateEventScreen extends StatelessWidget {
  const CreateEventScreen({super.key, this.teamId});

  final String? teamId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create event'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: const Center(
        child: Text('Create event — coming soon', style: AppTextStyles.bodySmall),
      ),
    );
  }
}
