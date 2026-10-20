// lib/features/magazine/magazine_search_page.dart
import 'package:flutter/material.dart';
import '../../core/debouncer.dart';
import '../../models/app_user.dart';
import '../../models/magazine_article.dart';
import '../../repositories/magazine_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_background.dart';
import '../../widgets/application_shell.dart';
import '../../widgets/widgets.dart';
import 'article_reader_page.dart';
import 'author_profile_page.dart';
import 'magazine_feed_page.dart' show ArticleListCard;

class MagazineSearchPage extends StatefulWidget {
  final AppUser? user;
  const MagazineSearchPage({super.key, this.user});

  @override
  State<MagazineSearchPage> createState() => _MagazineSearchPageState();
}

class _MagazineSearchPageState extends State<MagazineSearchPage> {
  final _ctrl = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 350);
  String _query = '';
  bool _loading = false;
  List<MagazineArticle>? _results;

  @override
  void dispose() {
    _ctrl.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _query = v);
    if (v.trim().isEmpty) {
      _debouncer.cancel();
      setState(() {
        _results = null;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debouncer.run(() => _runSearch(v));
  }

  Future<void> _runSearch(String v) async {
    final results = await MagazineRepository.instance.searchArticles(v);
    if (!mounted || v != _query) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return ApplicationShell(
      user: widget.user,
      currentTitle: 'Search Magazine',
      subtitle: 'Find articles by title, topic, category, or writer',
      currentDestination: AppNavDestination.magazine,
      breadcrumbs: [
        ShellBreadcrumb(
          label: 'Magazine',
          icon: Icons.article_outlined,
          onTap: () => Navigator.of(context).pop(),
        ),
        const ShellBreadcrumb(label: 'Search'),
      ],
      bottomHeader: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: ac.surf2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ac.bdr),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: ac.muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onChanged,
                style: AppText.bodySm.copyWith(color: ac.txt),
                decoration: InputDecoration(
                  hintText: 'Search articles, topics, writers…',
                  hintStyle: AppText.bodySm.copyWith(
                    color: ac.muted,
                    fontSize: 12.5,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_query.isNotEmpty)
              InkWell(
                onTap: () {
                  _ctrl.clear();
                  _onChanged('');
                },
                child: Icon(Icons.close_rounded, size: 16, color: ac.muted),
              ),
          ],
        ),
      ),
      child: AppBackground(child: _body(ac)),
    );
  }

  Widget _body(AppColors ac) {
    if (_query.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_rounded, size: 44, color: ac.muted),
              const SizedBox(height: 12),
              Text(
                'Search the Magazine',
                style: AppText.title.copyWith(fontSize: 15, color: ac.txt),
              ),
              const SizedBox(height: 6),
              Text(
                'Find articles by title, topic, category, or writer.',
                style: AppText.bodySm.copyWith(color: ac.txt2),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    if (_loading && _results == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          4,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ShimmerBlock(height: 84),
          ),
        ),
      );
    }
    final results = _results ?? const <MagazineArticle>[];
    if (results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches for "$_query"',
        subtitle: 'Search covers the most recent articles — try a different word.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: results.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ArticleListCard(
          article: results[i],
          currentUser: widget.user,
          onOpen: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ArticleReaderPage(
                article: results[i],
                currentUser: widget.user,
              ),
            ),
          ),
          onOpenAuthor: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AuthorProfilePage(
                authorId: results[i].authorId,
                currentUser: widget.user,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
