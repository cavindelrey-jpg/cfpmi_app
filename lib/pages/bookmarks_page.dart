// lib/pages/bookmarks_page.dart
// "My Bookmarks" — the missing other half of the Like/Bookmark work.
// watchBookmarkedCourses() and watchBookmarkedArticles() already existed
// in their repositories but had zero UI consumer anywhere; this is that
// consumer. Two tabs, both backed by real Firestore streams, no demo data.

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/public_course.dart';
import '../repositories/public_course_repository.dart';
import '../repositories/magazine_repository.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../features/courses_marketplace/course_lessons_page.dart';
import '../features/magazine/article_reader_page.dart';

import '../widgets/app_background.dart';
import '../widgets/application_shell.dart';
import '../widgets/widgets.dart';

class BookmarksPage extends StatefulWidget {
  final AppUser user;
  const BookmarksPage({super.key, required this.user});
  @override State<BookmarksPage> createState() => _BookmarksPageState();
}

class _BookmarksPageState extends State<BookmarksPage> with SingleTickerProviderStateMixin {
  late final TabController _tc = TabController(length: 2, vsync: this);

  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => const ShimmerCard(height: 76),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ApplicationShell(
      user: widget.user,
      currentTitle: 'Bookmarks & Saved Items',
      subtitle: 'Quick access to your bookmarked courses and articles',
      currentDestination: AppNavDestination.bookmarks,
      contextualPanel: LibraryContextualPanel(user: widget.user),
      bottomHeader: TabBar(
        controller: _tc,
        labelColor: ac.primary,
        unselectedLabelColor: ac.txt2,
        indicatorColor: ac.primary,
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_outlined, size: 18),
                SizedBox(width: 6),
                Text('Courses'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_outlined, size: 18),
                SizedBox(width: 6),
                Text('Magazine'),
              ],
            ),
          ),
        ],
      ),
      child: AppBackground(child: TabBarView(controller: _tc, children: [
        StreamBuilder<List<PublicCourse>>(
          stream: PublicCourseRepository.instance.watchBookmarkedCourses(widget.user.id),
          builder: (context, snap) {
            if (!snap.hasData) return _buildSkeletonList();
            final courses = snap.data!;
            if (courses.isEmpty) {
              return const EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: 'No saved courses yet',
                subtitle: 'Tap the bookmark icon on any course to save it here for quick access.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = courses[i];
                return _BookmarkTile(
                  title: c.title, subtitle: c.creatorName, imageUrl: c.coverImageUrl,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CourseLessonsPage(course: c, currentUser: widget.user))),
                );
              },
            );
          },
        ),
        StreamBuilder<List<MagazineArticle>>(
          stream: MagazineRepository.instance.watchBookmarkedArticles(widget.user.id),
          builder: (context, snap) {
            if (!snap.hasData) return _buildSkeletonList();
            final articles = snap.data!;
            if (articles.isEmpty) {
              return const EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: 'No saved articles yet',
                subtitle: 'Bookmark articles in the Magazine to build your personal reading list.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: articles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final a = articles[i];
                return _BookmarkTile(
                  title: a.title, subtitle: a.authorName, imageUrl: a.thumbnailUrl,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ArticleReaderPage(article: a, currentUser: widget.user))),
                );
              },
            );
          },
        ),
      ])),
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  final String title, subtitle;
  final String? imageUrl;
  final VoidCallback onTap;
  const _BookmarkTile({required this.title, required this.subtitle, this.imageUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    // Nested radius rule: outer radius (Rad.md = 16) = inner radius (8) + padding (8)
    final outerRadius = BorderRadius.circular(Rad.md);
    return Material(
      color: Colors.transparent,
      borderRadius: outerRadius,
      child: InkWell(
        borderRadius: outerRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: outerRadius,
            border: Border.all(color: ac.bdr.withValues(alpha: 0.7), width: 0.8),
            boxShadow: Shad.card,
          ),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Rad.xs),
              child: (imageUrl ?? '').isNotEmpty
                  ? Image.network(
                      imageUrl!,
                      width: 56, height: 56, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackThumb(ac),
                    )
                  : _fallbackThumb(ac),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.subtitle.copyWith(color: ac.txt), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.person_outline_rounded, size: 12, color: ac.muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(subtitle, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: ac.muted),
          ]),
        ),
      ),
    );
  }

  Widget _fallbackThumb(AppColors ac) => Container(
    width: 56, height: 56,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [ac.primary.withValues(alpha: .85), ac.navy.withValues(alpha: .95)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    alignment: Alignment.center,
    child: Icon(Icons.menu_book_rounded, color: Colors.white.withValues(alpha: .9), size: 24),
  );
}
