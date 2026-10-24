// lib/features/classroom/classroom_slide.dart
// Shared slide renderer. Shows the current slide image; when no image is set
// (or it fails to load offline) it falls back to a clean numbered placeholder
// so the lesson still works. Slide rendering only — not a PowerPoint clone.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/skeleton_spinner.dart';
class ClassroomSlide extends StatelessWidget {
  final String? url;
  final int index;
  final int total;
  final String topic;
  final bool large;
  const ClassroomSlide({
    super.key,
    required this.url,
    required this.index,
    required this.total,
    this.topic = '',
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF11141B), // Neutral dark canvas - avoids bright blue frame
        borderRadius: BorderRadius.circular(large ? 0 : 14),
      ),
      child: (url != null && url!.isNotEmpty)
          ? Image.network(
              url!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _placeholder(),
              loadingBuilder: (c, child, p) =>
                  p == null ? child : const Center(child: SkeletonSpinner(strokeWidth: 2, color: Colors.white38)),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.slideshow_rounded, size: large ? 96 : 48, color: Colors.white.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text(
              total == 0 ? 'No slides added' : 'Slide ${index + 1} of $total',
              style: GoogleFonts.inter(
                  fontSize: large ? 34 : 18, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            if (topic.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(topic,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: large ? 20 : 13, color: Colors.white.withValues(alpha: 0.75))),
            ],
          ],
        ),
      );
}
