// lib/features/classroom/classroom_display_page.dart
// Classroom Display View — the TV/projector output. Shows ONLY the current
// slide, full-bleed, no teacher controls. The teacher opens this from the
// control panel and moves this window/tab onto the HDMI screen. It follows
// the same live session stream, so it changes slides automatically.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/classroom.dart';
import '../../repositories/classroom_repository.dart';
import 'classroom_slide.dart';

class ClassroomDisplayPage extends StatelessWidget {
  final String sessionId;
  const ClassroomDisplayPage({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<ClassroomSession?>(
        stream: ClassroomRepository.instance.watchSession(sessionId),
        builder: (context, snap) {
          final s = snap.data;
          if (s == null) {
            return const Center(child: CircularProgressIndicator(color: Colors.white54));
          }
          return Stack(
            children: [
              Positioned.fill(
                child: ClassroomSlide(
                  url: s.currentSlideUrl,
                  index: s.currentSlide,
                  total: s.slideCount,
                  topic: s.topic,
                  large: true,
                ),
              ),
              // Minimal lesson banner, top-left, so a late arrival can orient.
              Positioned(
                top: 16,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${s.classLevel} · ${s.subject}${s.topic.isEmpty ? '' : ' — ${s.topic}'}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              // A discreet exit affordance (not shown on-slide content).
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close_fullscreen_rounded, color: Colors.white54),
                  tooltip: 'Exit display',
                  onPressed: () {
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                    Navigator.of(context).maybePop();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
