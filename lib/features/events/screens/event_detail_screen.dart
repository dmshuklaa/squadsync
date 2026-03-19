import 'package:flutter/material.dart';

import 'package:squadsync/core/theme/app_theme.dart';

/// Event detail screen — Sprint 3.2.
class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Event'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppColors.background,
      body: const Center(
        child: Text('Event detail — coming soon', style: AppTextStyles.bodySmall),
      ),
    );
  }
}
