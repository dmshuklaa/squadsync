import 'package:flutter/material.dart';

import 'package:squadsync/core/theme/app_theme.dart';

/// Reusable SquadSync "SS" logo circle.
///
/// [size] controls the diameter of the circle.
/// [showTagline] also renders "SquadSync" text below the circle.
class SquadSyncLogo extends StatelessWidget {
  const SquadSyncLogo({super.key, this.size = 64, this.showTagline = false});

  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
                // 0.39 keeps "SS" proportional — yields ~28 px at size 72
                fontSize: size * 0.39,
                fontWeight: FontWeight.bold,
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
              color: AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }
}
