import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Full-screen shimmer placeholder for roster list loading state.
class RosterShimmer extends StatelessWidget {
  const RosterShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 6,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, _) => const _ShimmerRow(),
      ),
    );
  }
}

class _ShimmerRow extends StatelessWidget {
  const _ShimmerRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Avatar placeholder
          const CircleAvatar(radius: 22, backgroundColor: Colors.white),
          const SizedBox(width: 12),
          // Text placeholders
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  color: Colors.white,
                ),
                const SizedBox(height: 6),
                Container(height: 12, width: 120, color: Colors.white),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Badge placeholder
          Container(
            height: 20,
            width: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
}
