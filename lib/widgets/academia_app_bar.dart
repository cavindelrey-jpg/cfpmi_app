// lib/widgets/academia_app_bar.dart
// Shared top bar for the application shell — one consistent bar across every
// section (same height, colour, title style, separation line, and the global
// Search + Notifications actions), while each page supplies its own title and
// any page-specific actions. Profile/account lives in the rail (desktop) and
// the bottom bar (mobile), so it is not duplicated here.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_user.dart';
import '../theme/app_colors.dart';
import '../pages/search_page.dart';
import '../pages/notifications_page.dart';

class AcademiaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final AppUser user;

  /// Page-specific actions, shown before the global Search/Notifications.
  final List<Widget> actions;
  final bool showBack;

  /// Hide the shared global actions on pages that have their own (e.g. a
  /// dedicated in-page search).
  final bool showGlobalActions;

  const AcademiaAppBar({
    super.key,
    required this.title,
    required this.user,
    this.actions = const [],
    this.showBack = false,
    this.showGlobalActions = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(57);

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return AppBar(
      backgroundColor: ac.surf,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: showBack,
      iconTheme: IconThemeData(color: ac.txt),
      titleSpacing: 16,
      title: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800, color: ac.txt)),
      actions: [
        ...actions,
        if (showGlobalActions) ...[
          IconButton(
            icon: Icon(Icons.search_rounded, color: ac.txt2),
            tooltip: 'Search',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SearchPage(user: user))),
          ),
          IconButton(
            icon: Icon(Icons.notifications_none_rounded, color: ac.txt2),
            tooltip: 'Notifications',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => NotificationsPage(user: user))),
          ),
        ],
        const SizedBox(width: 6),
      ],
      // A 1px rule cleanly separates the top bar from the content workspace.
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: ac.bdr),
      ),
    );
  }
}
