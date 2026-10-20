// lib/features/academic_content/content_details_page.dart
// Shows full details of a content item. Tracks views. Supports download.
//
// Design pass: named AppText scale, reading-appropriate line-height on
// the description, haptic on download.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_user.dart';
import '../../models/academic_content.dart';
import '../../repositories/academic_content_repository.dart';
import '../../core/result.dart';
import '../../widgets/widgets.dart' show showToast, ShimmerCard, EmptyState;
import '../../widgets/application_shell.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import 'content_edit_page.dart';
import 'content_delete_dialog.dart';
import 'content_viewer_page.dart';

import '../../widgets/app_background.dart';
class ContentDetailsPage extends StatefulWidget {
  final String contentId;
  final AppUser user;

  const ContentDetailsPage({
    super.key,
    required this.contentId,
    required this.user,
  });

  @override
  State<ContentDetailsPage> createState() => _ContentDetailsPageState();
}

class _ContentDetailsPageState extends State<ContentDetailsPage> {
  bool _viewTracked = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AcademicContent?>(
      stream: AcademicContentRepository.instance.watchOne(widget.contentId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return ApplicationShell(
            user: widget.user,
            currentTitle: 'Document Details',
            currentDestination: AppNavDestination.academicLibrary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: const [
                ShimmerCard(height: 190),
                SizedBox(height: 16),
                ShimmerCard(height: 280),
              ],
            ),
          );
        }
        final item = snap.data;
        if (item == null) {
          return ApplicationShell(
            user: widget.user,
            currentTitle: 'Not Found',
            currentDestination: AppNavDestination.academicLibrary,
            child: const EmptyState(
              icon: Icons.find_in_page_outlined,
              title: 'Content no longer exists',
              subtitle: 'This item may have been moved or removed by its author.',
            ),
          );
        }

        if (!_viewTracked) {
          _viewTracked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            AcademicContentRepository.instance.incrementViews(item.id);
            AcademicContentRepository.instance.recordView(item.id, widget.user.id);
          });
        }

        final canEdit = widget.user.canUploadContent ||
            item.uploadedBy == widget.user.id;
        final ac = AppColors.of(context);
        final isPastPaper = item.contentType == ContentType.pastPaper;

        return ApplicationShell(
          user: widget.user,
          currentTitle: item.title,
          subtitle: item.contentType.label,
          currentDestination: isPastPaper
              ? AppNavDestination.pastQuestions
              : AppNavDestination.academicLibrary,
          contextualPanel: BookDetailsContextualPanel(
            content: item,
            user: widget.user,
          ),
          headerActions: [
            IconButton(
              icon: Icon(Icons.copy_rounded, color: ac.txt2, size: 20),
              tooltip: 'Copy title & description',
              onPressed: () {
                HapticFeedback.selectionClick();
                final buf = StringBuffer(item.title);
                if (item.description.trim().isNotEmpty) {
                  buf.write('\n\n${item.description.trim()}');
                }
                if ((item.fileUrl ?? '').isNotEmpty) {
                  buf.write('\n\n${item.fileUrl}');
                }
                Clipboard.setData(ClipboardData(text: buf.toString()));
                showToast(context, 'Copied to clipboard.');
              },
            ),
            StreamBuilder<bool>(
              stream: AcademicContentRepository.instance
                  .watchIsSaved(item.id, widget.user.id),
              builder: (context, savedSnap) {
                final saved = savedSnap.data ?? false;
                return IconButton(
                  icon: Icon(
                    saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: saved ? ac.gold : ac.txt2,
                  ),
                  tooltip: saved ? 'Saved' : 'Save for offline',
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final wasSaved = saved;
                    await AcademicContentRepository.instance
                        .toggleSave(item.id, widget.user.id);
                    if (wasSaved) {
                      await AcademicContentRepository.instance
                          .removeOfflineFile(item.id);
                    } else if ((item.fileUrl ?? '').isNotEmpty) {
                      showToast(context, 'Downloading for offline…');
                      final res = await AcademicContentRepository.instance
                          .downloadForOffline(item);
                      if (!context.mounted) return;
                      showToast(
                        context,
                        res is Failure<String>
                            ? res.message
                            : 'Saved — available offline in your Library.',
                        isError: res is Failure<String>,
                      );
                    }
                  },
                );
              },
            ),
            if (canEdit) ...[
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ContentEditPage(content: item, user: widget.user),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: ac.red),
                tooltip: 'Delete',
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ContentDeleteDialog(
                    content: item,
                    onDeleted: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ],
          child: Column(
            children: [
              Expanded(
                child: SelectionArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail with frosted type badge overlay (Mistake 1 & 2)
                  Stack(
                    children: [
                      if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(Rad.lg),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Image.network(
                              item.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _PlaceholderThumbnail(type: item.contentType),
                            ),
                          ),
                        )
                      else
                        _PlaceholderThumbnail(type: item.contentType),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                          ),
                          child: Text(
                            item.contentType.label.toUpperCase(),
                            style: AppText.label.copyWith(
                              color: Colors.white,
                              letterSpacing: 0.8,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Improvement 1 (Scrollable card container): soft rounded card
                  // with subtle shadow, consistent 20px internal alignment (Mistake 3).
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ac.surf,
                      borderRadius: BorderRadius.circular(Rad.lg),
                      border: Border.all(color: ac.bdr.withValues(alpha: 0.7), width: 0.8),
                      boxShadow: Shad.card,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Scannable classification badges (Mistake 6)
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _TypeBadge(type: item.contentType),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: ac.bluBg, borderRadius: BorderRadius.circular(8)),
                            child: Text(item.subject,
                                style: AppText.label.copyWith(fontSize: 10.5, letterSpacing: 0.6, color: ac.blu)),
                          ),
                          if (item.level.isNotEmpty && item.level != 'All Levels')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: ac.grnBg, borderRadius: BorderRadius.circular(8)),
                              child: Text(item.level,
                                  style: AppText.label.copyWith(fontSize: 10.5, letterSpacing: 0.6, color: ac.grn)),
                            ),
                          if (item.examBoard.isNotEmpty && item.examBoard != 'N/A')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: ac.goldBg, borderRadius: BorderRadius.circular(8)),
                              child: Text(item.year != null ? '${item.examBoard} ${item.year}' : item.examBoard,
                                  style: AppText.label.copyWith(fontSize: 10.5, letterSpacing: 0.6, color: ac.gold)),
                            ),
                        ]),
                        const SizedBox(height: 12),

                        // Balanced title hierarchy (Mistake 7)
                        Text(
                          item.title,
                          style: AppText.h1.copyWith(fontSize: 22, height: 1.25, color: ac.txt),
                        ),
                        const SizedBox(height: 10),

                        // Trust signals right next to title (Mistake 9 & 10)
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: [
                            _Stat(icon: Icons.visibility_outlined, value: '${item.views} views'),
                            _Stat(icon: Icons.download_outlined, value: '${item.downloads} downloads'),
                            _Stat(icon: Icons.calendar_today_outlined, value: _formatDate(item.uploadDate)),
                          ],
                        ),

                        // Description with relaxed line-height & softer contrast (Mistake 8, 11, 12)
                        if (item.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Divider(height: 1, thickness: 0.8, color: ac.bdr.withValues(alpha: 0.7)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Overview', style: AppText.title.copyWith(fontSize: 14)),
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: item.description));
                                  showToast(context, 'Description copied to clipboard.');
                                },
                                icon: Icon(Icons.copy_rounded, size: 14, color: ac.primary),
                                label: Text('Copy', style: AppText.caption.copyWith(color: ac.primary, fontWeight: FontWeight.w700)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.description,
                            style: AppText.body.copyWith(fontSize: 14.5, height: 1.65, color: ac.txt2),
                          ),
                        ],

                        // Tags
                        if (item.tags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Divider(height: 1, thickness: 0.8, color: ac.bdr.withValues(alpha: 0.7)),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: item.tags.map((t) => _Tag(label: t)).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if ((item.fileUrl ?? '').isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: ac.surf,
              border: Border(
                top: BorderSide(color: ac.bdr.withValues(alpha: 0.7), width: 0.8),
              ),
              boxShadow: Shad.sm,
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: _DownloadButton(item: item, user: widget.user),
          ),
      ],
    ),
  );
},
);
}

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _PlaceholderThumbnail extends StatelessWidget {
  final ContentType type;
  const _PlaceholderThumbnail({required this.type});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ac.primary.withValues(alpha: 0.88), ac.navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Rad.lg),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
          ),
          child: Text(type.emoji, style: const TextStyle(fontSize: 32)),
        ),
        const SizedBox(height: 10),
        Text(
          type.label,
          style: AppText.subtitle.copyWith(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
        ),
      ]),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final ContentType type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: ac.purBg, borderRadius: BorderRadius.circular(8)),
      child: Text(type.label,
          style: AppText.label.copyWith(fontSize: 10.5, letterSpacing: 0.6, color: ac.pur)),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  const _Stat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: ac.muted),
      const SizedBox(width: 5),
      Text(value, style: AppText.caption.copyWith(fontSize: 12, color: ac.txt2)),
    ]);
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ac.surf2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ac.bdr.withValues(alpha: 0.7), width: 0.8),
      ),
      child: Text('#$label', style: AppText.caption.copyWith(fontSize: 11, color: ac.txt2)),
    );
  }
}

class _DownloadButton extends StatefulWidget {
  final AcademicContent item;
  final AppUser user;
  const _DownloadButton({required this.item, required this.user});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _loading = false;

  ViewableFileKind? get _viewableKind {
    final byUrl = viewableKindFor(widget.item.fileUrl ?? '');
    if (byUrl != null) return byUrl;
    if (widget.item.contentType == ContentType.video) return ViewableFileKind.video;
    if (widget.item.contentType == ContentType.pastPaper ||
        widget.item.contentType == ContentType.book ||
        widget.item.contentType == ContentType.note) {
      return ViewableFileKind.pdf;
    }
    return null;
  }

  Future<void> _openFile() async {
    // Images, PDFs, video, .docx, .epub, and .txt render in-app instead of
    // handing off to whatever external app the OS picks.
    final kind = _viewableKind;
    if (kind != null) {
      await AcademicContentRepository.instance.incrementDownloads(widget.item.id);
      String? localPath;
      try {
        localPath = await AcademicContentRepository.instance.offlineFilePath(widget.item.id);
      } catch (_) {}
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ContentViewerPage(
          content: widget.item,
          user: widget.user,
          fileUrl: widget.item.fileUrl!,
          localFilePath: localPath,
          title: widget.item.title,
          kind: kind,
          contentId: widget.item.id,
          userId: widget.user.id,
        ),
      ));
      return;
    }
    final uri = Uri.tryParse(widget.item.fileUrl!);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      await AcademicContentRepository.instance.incrementDownloads(widget.item.id);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open file.')),
      );
    }
  }

  Future<void> _download() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);

    try {
      await _openFile();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _download,
        style: ElevatedButton.styleFrom(
          backgroundColor: ac.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: _loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(_viewableKind != null ? Icons.menu_book_rounded : Icons.download_rounded),
        label: Text(
            _loading
                ? 'Opening…'
                : (_viewableKind != null ? 'Read / Open File' : 'Download / Open'),
            style: AppText.button.copyWith(fontSize: 15)),
      ),
    );
  }
}
