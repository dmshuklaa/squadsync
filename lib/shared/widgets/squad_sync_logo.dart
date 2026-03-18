import 'package:flutter/material.dart';

import 'package:squadsync/core/theme/app_theme.dart';

/// Reusable SquadSync "SS" logo circle.
///
/// [size] controls the diameter of the inner circle.
/// [showTagline] renders "SquadSync" text below the circle.
/// [taglineColor] controls the tagline text colour — use [Colors.white]
/// when the logo is placed on a dark (navy) background.
class SquadSyncLogo extends StatelessWidget {
  const SquadSyncLogo({
    super.key,
    this.size = 64,
    this.showTagline = false,
    this.taglineColor = AppColors.textSecondary,
  });

  final double size;
  final bool showTagline;
  final Color taglineColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size + 6, // outer ring padding
          height: size + 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'SS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.39,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showTagline) ...[
          SizedBox(height: size * 0.22),
          Text(
            'SquadSync',
            style: TextStyle(
              fontSize: size * 0.39,
              fontWeight: FontWeight.bold,
              color: taglineColor,
            ),
          ),
        ],
      ],
    );
  }
}
