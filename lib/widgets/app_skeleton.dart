// lib/widgets/app_skeleton.dart
// Lightweight skeleton-loader placeholders that mirror the final layout
// instead of a bare spinner — feels more responsive/professional (per the
// web-design notes). AppSkeleton is one shimmering bar; SkeletonList is a
// ready-made "loading rows" placeholder for list/registry screens.

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const AppSkeleton({super.key, this.width, this.height = 14, this.radius = 8});

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (ctx, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: ac.bdr.withValues(alpha: 0.35 + 0.35 * _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A placeholder list of card-shaped rows shown while real data loads.
class SkeletonList extends StatelessWidget {
  final int count;
  final EdgeInsets padding;
  const SkeletonList({super.key, this.count = 7, this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16)});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ListView.separated(
      padding: padding,
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ac.surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ac.bdr),
        ),
        child: Row(
          children: const [
            AppSkeleton(width: 42, height: 42, radius: 10),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(width: 150, height: 13),
                  SizedBox(height: 8),
                  AppSkeleton(width: 90, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
