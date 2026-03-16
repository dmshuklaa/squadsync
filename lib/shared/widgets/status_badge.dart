import 'package:flutter/material.dart';

import 'package:squadsync/shared/models/enums.dart';

/// Small coloured pill that displays a [MembershipStatus] label.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final MembershipStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
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

  Color get _backgroundColor {
    switch (status) {
      case MembershipStatus.active:
        return const Color(0xFFD1FAE5); // green-100
      case MembershipStatus.inactive:
        return const Color(0xFFFEF3C7); // amber-100
      case MembershipStatus.archived:
        return const Color(0xFFF3F4F6); // gray-100
      case MembershipStatus.pending:
        return const Color(0xFFDBEAFE); // blue-100
    }
  }

  Color get _foregroundColor {
    switch (status) {
      case MembershipStatus.active:
        return const Color(0xFF065F46); // green-800
      case MembershipStatus.inactive:
        return const Color(0xFF92400E); // amber-800
      case MembershipStatus.archived:
        return const Color(0xFF374151); // gray-700
      case MembershipStatus.pending:
        return const Color(0xFF1E40AF); // blue-800
    }
  }
}
