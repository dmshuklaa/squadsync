import 'package:flutter/material.dart';

import 'package:squadsync/core/theme/app_theme.dart';

/// Full event list screen — Sprint 3.2.
class EventListScreen extends StatelessWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: const Center(
        child: Text('Events list — coming soon', style: AppTextStyles.bodySmall),
      ),
    );
  }
}
