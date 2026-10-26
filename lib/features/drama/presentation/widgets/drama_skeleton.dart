import 'package:flutter/material.dart';

import '../../../../core/widgets/skeleton.dart';

/// Placeholder for the discover feed. Mirrors the real layout (hero poster, a
/// section title, two rows of cards) so switching sources never jumps the page.
class DramaDiscoverSkeleton extends StatelessWidget {
  const DramaDiscoverSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SkeletonBlock(height: 236, radius: 27),
      const SizedBox(height: 28),
      Row(
        children: const [
          SkeletonBlock(width: 92, height: 18, radius: 9),
          Spacer(),
          SkeletonBlock(width: 56, height: 10, radius: 5),
        ],
      ),
      const SizedBox(height: 16),
      for (var row = 0; row < 2; row++) ...[
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: DramaCardSkeleton()),
            SizedBox(width: 14),
            Expanded(child: DramaCardSkeleton()),
          ],
        ),
        if (row == 0) const SizedBox(height: 22),
      ],
    ],
  );
}

class DramaCardSkeleton extends StatelessWidget {
  const DramaCardSkeleton({super.key, this.posterHeight = 196});
  final double posterHeight;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SkeletonBlock(height: posterHeight, radius: 19),
      const SizedBox(height: 10),
      const FractionallySizedBox(
        widthFactor: .82,
        child: SkeletonBlock(height: 12, radius: 6),
      ),
      const SizedBox(height: 7),
      const FractionallySizedBox(
        widthFactor: .5,
        child: SkeletonBlock(height: 9, radius: 5),
      ),
    ],
  );
}

/// Placeholder for two-column result grids (search).
class DramaGridSkeleton extends StatelessWidget {
  const DramaGridSkeleton({super.key, this.rows = 3});
  final int rows;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var row = 0; row < rows; row++) ...[
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: DramaCardSkeleton(posterHeight: 165)),
            SizedBox(width: 14),
            Expanded(child: DramaCardSkeleton(posterHeight: 165)),
          ],
        ),
        if (row != rows - 1) const SizedBox(height: 22),
      ],
    ],
  );
}

/// Placeholder for the stacked rows used by the personal library.
class DramaRowListSkeleton extends StatelessWidget {
  const DramaRowListSkeleton({super.key, this.rows = 3});
  final int rows;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var row = 0; row < rows; row++) ...[
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EAF0)),
          ),
          child: Row(
            children: [
              const SkeletonBlock(width: 69, height: 94, radius: 12),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBlock(height: 14, radius: 7),
                    SizedBox(height: 10),
                    FractionallySizedBox(
                      widthFactor: .55,
                      child: SkeletonBlock(height: 10, radius: 5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const SkeletonBlock(width: 21, height: 21, radius: 11),
            ],
          ),
        ),
        if (row != rows - 1) const SizedBox(height: 15),
      ],
    ],
  );
}
