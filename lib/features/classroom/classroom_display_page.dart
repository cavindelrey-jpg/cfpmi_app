// lib/features/classroom/classroom_display_page.dart
// Classroom Projector / Large Screen Display View.
// High-contrast, full-bleed presentation space for classroom laptops connected
// to projectors or large TVs.
// Reuses the application's pdfrx PDF reader for multi-page presentations.
// Supports keyboard navigation (arrows, spacebar, page up/down) and floating
// presentation controls (Previous, Next, Page X of Y, Fullscreen, Exit).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../models/classroom.dart';
import '../../repositories/classroom_repository.dart';
import '../../widgets/web_embed/web_embed.dart';
import 'classroom_slide.dart';

import '../../widgets/skeleton_spinner.dart';
class ClassroomDisplayPage extends StatefulWidget {
  final String sessionId;
  const ClassroomDisplayPage({super.key, required this.sessionId});

  @override
  State<ClassroomDisplayPage> createState() => _ClassroomDisplayPageState();
}

class _ClassroomDisplayPageState extends State<ClassroomDisplayPage> {
  final FocusNode _focusNode = FocusNode();
  PdfViewerController? _pdfController;
  bool _isFullscreen = false;
  bool _showControls = true;
  int _lastKnownSlide = 0;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _onKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      _nextSlide();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      _prevSlide();
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_isFullscreen) {
        _toggleFullscreen();
      } else {
        Navigator.of(context).maybePop();
      }
    }
  }

  void _nextSlide([ClassroomSession? s]) {
    if (_pdfController != null && _pdfController!.isReady) {
      final current = _pdfController!.pageNumber ?? 1;
      if (current < _pdfController!.pageCount) {
        _pdfController!.goToPage(pageNumber: current + 1);
        ClassroomRepository.instance.setCurrentSlide(widget.sessionId, current);
      }
      return;
    }
    if (s != null && s.currentSlide < s.slideCount - 1) {
      ClassroomRepository.instance.setCurrentSlide(widget.sessionId, s.currentSlide + 1);
    }
  }

  void _prevSlide([ClassroomSession? s]) {
    if (_pdfController != null && _pdfController!.isReady) {
      final current = _pdfController!.pageNumber ?? 1;
      if (current > 1) {
        _pdfController!.goToPage(pageNumber: current - 1);
        ClassroomRepository.instance.setCurrentSlide(widget.sessionId, current - 2);
      }
      return;
    }
    if (s != null && s.currentSlide > 0) {
      ClassroomRepository.instance.setCurrentSlide(widget.sessionId, s.currentSlide - 1);
    }
  }

  Widget _buildPresentationViewer(ClassroomSession s) {
    final orig = s.originalFile ?? '';
    final origExt = orig.contains('.')
        ? orig.split('.').last.toLowerCase().split('?').first
        : '';
    final slideUrl = s.currentSlideUrl ?? '';
    final slideExt = slideUrl.contains('.')
        ? slideUrl.split('.').last.toLowerCase().split('?').first
        : '';

    final isPdf = origExt == 'pdf' || slideExt == 'pdf';
    final pdfUrl = origExt == 'pdf' ? orig : (slideExt == 'pdf' ? slideUrl : '');

    // 1. Multi-page PDF Presentation (using proven pdfrx viewer from Academic Library)
    if (isPdf && pdfUrl.isNotEmpty) {
      // Sync PDF page if changed remotely by teacher
      if (_pdfController != null &&
          _pdfController!.isReady &&
          s.currentSlide != _lastKnownSlide) {
        _lastKnownSlide = s.currentSlide;
        final targetPage = s.currentSlide + 1;
        if (_pdfController!.pageNumber != targetPage &&
            targetPage <= _pdfController!.pageCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pdfController!.isReady) {
              _pdfController!.goToPage(pageNumber: targetPage);
            }
          });
        }
      }

      return Container(
        color: const Color(0xFF0F1117),
        child: PdfViewer.uri(
          Uri.parse(pdfUrl),
          controller: _pdfController,
          params: PdfViewerParams(
            backgroundColor: const Color(0xFF0F1117),
            onPageChanged: (page) {
              if (page != null) {
                _lastKnownSlide = page - 1;
                if (s.currentSlide != page - 1) {
                  ClassroomRepository.instance.setCurrentSlide(widget.sessionId, page - 1);
                }
              }
            },
            errorBannerBuilder: (ctx, err, stack, ref) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Presentation document could not be loaded. Check connection.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          ),
          initialPageNumber: s.currentSlide + 1,
        ),
      );
    }

    // 2. PowerPoint Presentation
    final isPptx = origExt == 'pptx' || origExt == 'ppt' || slideExt == 'pptx' || slideExt == 'ppt';
    final pptUrl = (origExt == 'pptx' || origExt == 'ppt') ? orig : slideUrl;
    if (isPptx && pptUrl.isNotEmpty) {
      if (kIsWeb) {
        return WebDocEmbed(url: officeViewerUrl(pptUrl));
      }
      return WebDocEmbed(url: pptUrl);
    }

    // 3. Slide image collection
    if (s.slideUrls.isNotEmpty) {
      return Container(
        color: const Color(0xFF0F1117),
        child: ClassroomSlide(
          url: s.currentSlideUrl,
          index: s.currentSlide,
          total: s.slideCount,
          topic: s.topic,
          large: true,
        ),
      );
    }

    // 4. Standby / Neutral state — restrained, NO bright blue screen
    return Container(
      color: const Color(0xFF0F1117),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E222B),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF2C3240)),
                ),
                child: const Icon(
                  Icons.cast_for_education_rounded,
                  size: 56,
                  color: Color(0xFFE5A93C),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                s.topic.isNotEmpty ? s.topic : '${s.classLevel} · ${s.subject}',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Waiting for teacher presentation to start…',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1117),
        body: StreamBuilder<ClassroomSession?>(
          stream: ClassroomRepository.instance.watchSession(widget.sessionId),
          builder: (context, snap) {
            final s = snap.data;
            if (s == null) {
              return const Center(
                child: SkeletonSpinner(
                  strokeWidth: 2.5,
                  color: Colors.white38,
                ),
              );
            }

            final pdfPages = _pdfController?.isReady == true ? _pdfController!.pageCount : 0;
            final totalPages = pdfPages > 0 ? pdfPages : (s.slideCount > 0 ? s.slideCount : 1);
            final currentPage = _pdfController?.isReady == true
                ? (_pdfController!.pageNumber ?? 1)
                : (s.currentSlide + 1);

            return MouseRegion(
              onHover: (_) {
                if (!_showControls) setState(() => _showControls = true);
              },
              child: Stack(
                children: [
                  // Full-bleed presentation canvas
                  Positioned.fill(
                    child: _buildPresentationViewer(s),
                  ),

                  // Minimal lesson banner (top-left)
                  Positioned(
                    top: 16,
                    left: 20,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showControls ? 1.0 : 0.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE5A93C),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${s.classLevel} · ${s.subject}${s.topic.isEmpty ? '' : ' — ${s.topic}'}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Exit button (top-right)
                  Positioned(
                    top: 16,
                    right: 20,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _showControls ? 1.0 : 0.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                          tooltip: 'Exit Projector Display',
                          onPressed: () {
                            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                            Navigator.of(context).maybePop();
                          },
                        ),
                      ),
                    ),
                  ),

                  // Floating projector controls (bottom-center)
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _showControls ? 1.0 : 0.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161922).withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 16,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Previous Slide
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
                                tooltip: 'Previous slide (Left Arrow)',
                                onPressed: currentPage > 1 ? () => _prevSlide(s) : null,
                              ),
                              const SizedBox(width: 8),

                              // Page Indicator
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Page $currentPage / $totalPages',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Next Slide
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
                                tooltip: 'Next slide (Right Arrow / Space)',
                                onPressed: currentPage < totalPages ? () => _nextSlide(s) : null,
                              ),
                              const SizedBox(width: 12),
                              Container(width: 1, height: 20, color: Colors.white24),
                              const SizedBox(width: 12),

                              // Fullscreen Toggle
                              IconButton(
                                icon: Icon(
                                  _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                                  color: Colors.white70,
                                  size: 22,
                                ),
                                tooltip: _isFullscreen ? 'Exit Fullscreen' : 'Fullscreen (Projector Mode)',
                                onPressed: _toggleFullscreen,
                              ),

                              // Exit Presentation
                              IconButton(
                                icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white70, size: 20),
                                tooltip: 'Exit presentation',
                                onPressed: () {
                                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                                  Navigator.of(context).maybePop();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
