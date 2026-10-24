// lib/widgets/skeleton_spinner.dart
// Drop-in skeleton replacement for CircularProgressIndicator. The app no
// longer shows spinners anywhere: every loading state renders shimmer
// skeleton sketches instead. The constructor keeps the spinner's named
// parameters so existing call sites compile unchanged (they are ignored).

import 'package:flutter/material.dart';

import 'widgets.dart' show ShimmerLine;

class SkeletonSpinner extends StatelessWidget {
  final double? value;
  final double strokeWidth;
  final Color? color;
  final Color? backgroundColor;
  final Animation<Color?>? valueColor;
  final String? semanticsLabel;
  final String? semanticsValue;

  const SkeletonSpinner({
    super.key,
    this.value,
    this.strokeWidth = 4,
    this.color,
    this.backgroundColor,
    this.valueColor,
    this.semanticsLabel,
    this.semanticsValue,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final small = !c.hasBoundedWidth ||
          c.maxWidth <= 64 ||
          (c.hasBoundedHeight && c.maxHeight <= 64);
      if (small) {
        final w = c.hasBoundedWidth ? c.maxWidth.clamp(0.0, 28.0) : 24.0;
        final h = c.hasBoundedHeight ? c.maxHeight.clamp(0.0, 14.0) : 12.0;
        return Center(child: ShimmerLine(width: w, height: h));
      }
      return Center(
        child: SizedBox(
          width: c.maxWidth.clamp(0.0, 260.0),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerLine(height: 16),
              SizedBox(height: 10),
              ShimmerLine(height: 12),
              SizedBox(height: 10),
              ShimmerLine(width: 160, height: 12),
            ],
          ),
        ),
      );
    });
  }
}
