// lib/features/courses_marketplace/hierarchy_browse_scaffold.dart
// Shared desktop-ready shell for every "browse one level of the hierarchy" screen
// (Subjects-in-Level, Topics-in-Subject, Courses-in-Topic, Lessons-in-Course,
// Library folders). Integrates with ApplicationShell so the persistent left
// navigation rail, global top bar, breadcrumbs, sorting, grid/list toggle,
// and contextual right sidebar remain consistent across all hierarchy depths.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/app_user.dart';
import '../../services/courses_view_mode_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/application_shell.dart';
import '../../widgets/widgets.dart';

enum HierarchySortOrder {
  natural,
  nameAsc,
  nameDesc,
}

class HierarchyBrowseScaffold<T> extends StatefulWidget {
  final AppUser? user;
  final AppNavDestination navDestination;
  final String title;
  final String? subtitle;
  final String searchHint;
  final bool loading;
  final List<T> items;
  final String Function(T item) searchableText;
  final Widget Function(BuildContext context, T item) gridTileBuilder;
  final Widget Function(BuildContext context, T item) listTileBuilder;
  final String emptyMessage;
  final Widget? floatingActionButton;
  final List<ShellBreadcrumb>? breadcrumbs;
  final Widget? contextualPanel;
  final bool showRightPanel;

  // Multi-select support
  final bool isSelecting;
  final String? selectionTitle;
  final List<Widget>? selectionActions;
  final VoidCallback? onCancelSelection;

  final List<Widget>? actions;
  final Widget? headerWidget;

  const HierarchyBrowseScaffold({
    super.key,
    this.user,
    this.navDestination = AppNavDestination.academicCourses,
    required this.title,
    this.subtitle,
    required this.searchHint,
    required this.loading,
    required this.items,
    required this.searchableText,
    required this.gridTileBuilder,
    required this.listTileBuilder,
    this.emptyMessage = 'Nothing here yet.',
    this.floatingActionButton,
    this.breadcrumbs,
    this.contextualPanel,
    this.showRightPanel = true,
    this.actions,
    this.headerWidget,
    this.isSelecting = false,
    this.selectionTitle,
    this.selectionActions,
    this.onCancelSelection,
  });

  @override
  State<HierarchyBrowseScaffold<T>> createState() =>
      _HierarchyBrowseScaffoldState<T>();
}

class _HierarchyBrowseScaffoldState<T>
    extends State<HierarchyBrowseScaffold<T>> {
  String _query = '';
  bool _isGrid = CoursesViewModeService.isGrid;
  HierarchySortOrder _sortOrder = HierarchySortOrder.natural;

  @override
  void initState() {
    super.initState();
    CoursesViewModeService.ensureLoaded().then((_) {
      if (mounted) setState(() => _isGrid = CoursesViewModeService.isGrid);
    });
  }

  List<T> get _filtered {
    var result = List<T>.from(widget.items);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      result = result
          .where((i) => widget.searchableText(i).toLowerCase().contains(q))
          .toList();
    }
    if (_sortOrder == HierarchySortOrder.nameAsc) {
      result.sort(
        (a, b) => widget
            .searchableText(a)
            .toLowerCase()
            .compareTo(widget.searchableText(b).toLowerCase()),
      );
    } else if (_sortOrder == HierarchySortOrder.nameDesc) {
      result.sort(
        (a, b) => widget
            .searchableText(b)
            .toLowerCase()
            .compareTo(widget.searchableText(a).toLowerCase()),
      );
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isSelecting = widget.isSelecting;

    return ApplicationShell(
      user: widget.user,
      currentTitle: isSelecting
          ? (widget.selectionTitle ?? 'Select Items')
          : widget.title,
      subtitle: isSelecting ? null : widget.subtitle,
      currentDestination: widget.navDestination,
      breadcrumbs: widget.breadcrumbs,
      contextualPanel: widget.contextualPanel,
      showRightPanel: widget.showRightPanel,
      floatingActionButton: isSelecting ? null : widget.floatingActionButton,
      onBack: isSelecting ? widget.onCancelSelection : null,
      showBackButton: isSelecting ? true : null,
      headerActions: isSelecting
          ? widget.selectionActions
          : [
              if (widget.actions != null) ...widget.actions!,
            ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.headerWidget != null) widget.headerWidget!,
          if (!isSelecting) _buildExplorerToolbar(ac),
          Expanded(child: _body(ac)),
        ],
      ),
    );
  }

  Widget _buildExplorerToolbar(AppColors ac) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: ac.surf,
        border: Border(bottom: BorderSide(color: ac.bdr)),
      ),
      child: Row(
        children: [
          // Search Field
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 40),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: GoogleFonts.inter(fontSize: 13, color: ac.txt),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  hintStyle: GoogleFonts.inter(fontSize: 13, color: ac.muted),
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 18, color: ac.muted),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  filled: true,
                  fillColor: ac.surf2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ac.bdr),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ac.bdr),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: ac.primary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Sort Selector
          PopupMenuButton<HierarchySortOrder>(
            tooltip: 'Sort items',
            initialValue: _sortOrder,
            onSelected: (order) => setState(() => _sortOrder = order),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: HierarchySortOrder.natural,
                child: Text('Default Order'),
              ),
              PopupMenuItem(
                value: HierarchySortOrder.nameAsc,
                child: Text('Name (A – Z)'),
              ),
              PopupMenuItem(
                value: HierarchySortOrder.nameDesc,
                child: Text('Name (Z – A)'),
              ),
            ],
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: ac.surf2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ac.bdr),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort_rounded, size: 17, color: ac.txt2),
                  const SizedBox(width: 6),
                  Text(
                    _sortOrder == HierarchySortOrder.nameAsc
                        ? 'A–Z'
                        : (_sortOrder == HierarchySortOrder.nameDesc
                            ? 'Z–A'
                            : 'Sort'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ac.txt,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Grid / List View Toggle
          HierarchyViewToggle(
            isGrid: _isGrid,
            onChanged: (grid) {
              setState(() => _isGrid = grid);
              CoursesViewModeService.setGrid(grid);
            },
          ),
        ],
      ),
    );
  }

  Widget _body(AppColors ac) {
    if (widget.loading) {
      return _isGrid
          ? GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 250,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              itemBuilder: (_, __) => const ShimmerBlock(
                width: double.infinity,
                height: double.infinity,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              itemCount: 5,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, __) => const ShimmerBlock(
                width: double.infinity,
                height: 68,
              ),
            );
    }

    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 48,
                color: ac.muted.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                _query.isNotEmpty
                    ? 'No matches found for "$_query".'
                    : widget.emptyMessage,
                textAlign: TextAlign.center,
                style: AppText.bodySm.copyWith(color: ac.txt2),
              ),
            ],
          ),
        ),
      );
    }

    if (_isGrid) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.92,
        ),
        itemBuilder: (context, i) => widget.gridTileBuilder(context, items[i]),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => widget.listTileBuilder(context, items[i]),
    );
  }
}
