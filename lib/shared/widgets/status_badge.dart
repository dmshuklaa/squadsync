import 'package:flutter/material.dart';

import 'package:squadsync/core/theme/app_theme.dart';
import 'package:squadsync/shared/models/enums.dart';

/// Small coloured pill that displays a [MembershipStatus] label.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final MembershipStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  String get _label {
    switch (status) {
      case MembershipStatus.active:
        return 'Active';
      case MembershipStatus.inactive:
        return 'Inactive';
      case MembershipStatus.archived:
        return 'Archived';
      case MembershipStatus.pending:
        return 'Pending';
    }
  }

  Color get _surfaceColor {
    switch (status) {
      case MembershipStatus.active:
        return AppColors.activeSurface;
      case MembershipStatus.inactive:
        return AppColors.inactiveSurface;
      case MembershipStatus.archived:
        return AppColors.archivedSurface;
      case MembershipStatus.pending:
        return AppColors.pendingSurface;
    }
  }

  Color get _textColor {
    switch (status) {
      case MembershipStatus.active:
        return AppColors.activeGreen;
      case MembershipStatus.inactive:
        return AppColors.inactiveGrey;
      case MembershipStatus.archived:
        return AppColors.archivedRed;
      case MembershipStatus.pending:
        return AppColors.pendingAmber;
    }
  }
}
