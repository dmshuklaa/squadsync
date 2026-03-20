import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/features/notifications/providers/notifications_providers.dart';

/// Persistent bottom navigation shell shared by all main tabs.
class BottomNavShell extends ConsumerWidget {
  const BottomNavShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadCountProvider);
    final unread = unreadAsync.whenOrNull(data: (n) => n) ?? 0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accentSurface,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.accent),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group, color: AppColors.accent),
            label: 'Team',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(
                '$unread',
                style: const TextStyle(fontSize: 10),
              ),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text(
                '$unread',
                style: const TextStyle(fontSize: 10),
              ),
              child: const Icon(Icons.notifications, color: AppColors.accent),
            ),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.accent),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
