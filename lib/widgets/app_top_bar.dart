// lib/widgets/app_top_bar.dart
// The ONE global top bar for the application shell — rendered once by
// HomeShell (desktop and mobile), never per page. It carries the real CFPMI
// logo asset, the current school/application context, a single global Search,
// Notifications, and the account/profile menu. Pages must not draw their own
// copies of these controls; a pushed detail page keeps its own titled AppBar
// with a back button instead (that is a different surface from this shell bar).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/branding.dart';
import '../models/app_user.dart';
import '../theme/app_colors.dart';
import '../pages/search_page.dart';
import '../pages/notifications_page.dart';
import '../services/auth_service.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser user;

  /// Opens the navigation drawer (mobile) or toggles the rail (desktop).
  final VoidCallback onMenu;

  /// Selects the Profile section in the shell.
  final VoidCallback onProfile;

  /// Mobile layout: a hamburger + icon-only search, tighter padding.
  final bool compact;

  const AppTopBar({
    super.key,
    required this.user,
    required this.onMenu,
    required this.onProfile,
    this.compact = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: ac.surf,
        border: Border(bottom: BorderSide(color: ac.bdr)),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 16),
      child: Row(
        children: [
          if (compact)
            IconButton(
              icon: Icon(Icons.menu_rounded, color: ac.txt),
              tooltip: 'Menu',
              onPressed: onMenu,
            ),
          _logo(ac),
          if (!compact && user.isSchoolMember && user.schoolName.isNotEmpty) ...[
            const SizedBox(width: 14),
            Container(width: 1, height: 22, color: ac.bdr),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                user.schoolName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 13.5, fontWeight: FontWeight.w600, color: ac.txt2),
              ),
            ),
          ],
          const Spacer(),
          if (compact)
            IconButton(
              icon: Icon(Icons.search_rounded, color: ac.txt2),
              tooltip: 'Search',
              onPressed: () => _open(context, SearchPage(user: user)),
            )
          else
            _searchField(context, ac),
          const SizedBox(width: 2),
          IconButton(
            icon: Icon(Icons.notifications_none_rounded, color: ac.txt2),
            tooltip: 'Notifications',
            onPressed: () => _open(context, NotificationsPage(user: user)),
          ),
          const SizedBox(width: 2),
          _profileMenu(context, ac),
        ],
      ),
    );
  }

  Widget _logo(AppColors ac) {
    return Image.asset(
      Branding.current.logoAssetPath,
      height: 34,
      filterQuality: FilterQuality.medium,
      // A broken/missing asset must never blank the whole shell bar — fall
      // back to the brand wordmark instead.
      errorBuilder: (_, __, ___) => Text(
        Branding.current.appName,
        style: GoogleFonts.inter(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: ac.primary,
            letterSpacing: -0.5),
      ),
    );
  }

  // Desktop global search: a click target that opens the full search page.
  // Kept as a launcher (not an inline live-search field) so this change
  // touches only presentation, not the existing SearchPage behaviour.
  Widget _searchField(BuildContext context, AppColors ac) {
    return SizedBox(
      width: 280,
      child: Material(
        color: ac.surf2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _open(context, SearchPage(user: user)),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ac.bdr),
            ),
            child: Row(children: [
              Icon(Icons.search_rounded, size: 19, color: ac.muted),
              const SizedBox(width: 10),
              Text('Search courses, library, people…',
                  style: GoogleFonts.inter(fontSize: 13, color: ac.muted)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _profileMenu(BuildContext context, AppColors ac) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'profile') {
          onProfile();
        } else if (v == 'signout') {
          AuthService.instance.performSignOut(context);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(children: [
            Icon(Icons.person_outline_rounded, size: 19, color: ac.txt2),
            const SizedBox(width: 10),
            const Text('My profile'),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'signout',
          child: Row(children: [
            Icon(Icons.logout_rounded, size: 19, color: ac.red),
            const SizedBox(width: 10),
            Text('Sign out', style: TextStyle(color: ac.red)),
          ]),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: CircleAvatar(
          radius: 17,
          backgroundColor: ac.primary.withValues(alpha: 0.12),
          backgroundImage:
              (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                  ? NetworkImage(user.photoUrl!)
                  : null,
          child: (user.photoUrl == null || user.photoUrl!.isEmpty)
              ? Text(initial,
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      color: ac.primary,
                      fontSize: 14))
              : null,
        ),
      ),
    );
  }
}
