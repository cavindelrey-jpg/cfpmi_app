// lib/widgets/app_top_bar.dart
// Single unified top bar for the application shell.
// Far left: menu/sidebar toggle followed immediately by the current page title.
// Same horizontal line: search bar and utility icons (Notifications, Light/Dark
// mode, Appearance customization, Settings, Profile) as one continuous,
// left-aligned group with small hover tooltips. No logo or branding.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../pages/notifications_page.dart';
import '../pages/search_page.dart';
import '../pages/settings_page.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final AppUser user;

  /// Toggles the left navigation sidebar.
  final VoidCallback onMenu;

  /// Selects the Profile destination in the shell.
  final VoidCallback onProfile;

  /// Selects the Settings destination in the shell.
  final VoidCallback? onSettings;

  /// Whether the sidebar is currently expanded.
  final bool sidebarExpanded;

  /// Compact mode for narrower screens.
  final bool compact;

  /// The current page title shown immediately beside the menu toggle (e.g. "Home").
  final String title;

  const AppTopBar({
    super.key,
    required this.user,
    required this.onMenu,
    required this.onProfile,
    this.onSettings,
    this.sidebarExpanded = false,
    this.compact = false,
    this.title = 'Home',
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Widget _smallTooltip({required String message, required Widget child}) {
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 250),
      preferBelow: true,
      verticalOffset: 14,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1F3A),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    ThemeProvider? themeProvider;
    try {
      themeProvider = context.watch<ThemeProvider>();
    } catch (_) {
      themeProvider = null;
    }
    final isDark = themeProvider?.isDark ?? (Theme.of(context).brightness == Brightness.dark);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: ac.surf,
        border: Border(bottom: BorderSide(color: ac.bdr.withValues(alpha: 0.8), width: 0.8)),
      ),
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Far left: menu/sidebar toggle
          _smallTooltip(
            message: sidebarExpanded ? 'Collapse sidebar' : 'Expand sidebar',
            child: IconButton(
              icon: Icon(
                sidebarExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
                color: ac.txt,
                size: 22,
              ),
              splashRadius: 20,
              onPressed: onMenu,
            ),
          ),
          const SizedBox(width: 6),
          // 2. Immediately followed by the current page title
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 130 : 240),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                fontSize: compact ? 16 : 18,
                fontWeight: FontWeight.w800,
                color: ac.txt,
                letterSpacing: -0.3,
              ),
            ),
          ),
          SizedBox(width: compact ? 12 : 24),
          // 3. Continuous, left-aligned horizontal group: Search bar + Utility icons
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _searchField(context, ac, compact: compact),
                    const SizedBox(width: 6),
                    _utilityIconButton(
                      ac: ac,
                      icon: Icons.notifications_none_rounded,
                      tooltip: 'Notifications',
                      onTap: () => _open(context, NotificationsPage(user: user)),
                    ),
                    _utilityIconButton(
                      ac: ac,
                      icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
                      onTap: () => themeProvider?.toggle(),
                    ),
                    _utilityIconButton(
                      ac: ac,
                      icon: Icons.palette_outlined,
                      tooltip: 'Appearance customization',
                      onTap: () => _showAppearanceSheet(context),
                    ),
                    _utilityIconButton(
                      ac: ac,
                      icon: Icons.settings_outlined,
                      tooltip: 'Settings',
                      onTap: () {
                        if (onSettings != null) {
                          onSettings!();
                        } else {
                          _open(context, SettingsPage(user: user));
                        }
                      },
                    ),
                    const SizedBox(width: 2),
                    _profileButton(context, ac),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField(BuildContext context, AppColors ac, {required bool compact}) {
    return _smallTooltip(
      message: 'Search courses, library, dictionary, and people',
      child: SizedBox(
        width: compact ? 156 : 240,
        height: 36,
        child: Material(
          color: ac.surf2,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _open(context, SearchPage(user: user)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ac.bdr.withValues(alpha: 0.8), width: 0.8),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 17, color: ac.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      compact ? 'Search…' : 'Search courses, library…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12.5, color: ac.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _utilityIconButton({
    required AppColors ac,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return _smallTooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 20, color: ac.txt2),
          ),
        ),
      ),
    );
  }

  Widget _profileButton(BuildContext context, AppColors ac) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U';
    return _smallTooltip(
      message: 'Profile',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onProfile,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: CircleAvatar(
            radius: 15,
            backgroundColor: ac.navy,
            backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                ? NetworkImage(user.photoUrl!)
                : null,
            child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                ? Text(
                    initial,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      color: ac.gold,
                      fontSize: 12.5,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  void _showAppearanceSheet(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final ac = AppColors.of(ctx);
        ThemeProvider? themeProv;
        LocaleProvider? localeProv;
        try {
          themeProv = ctx.watch<ThemeProvider>();
        } catch (_) {}
        try {
          localeProv = ctx.watch<LocaleProvider>();
        } catch (_) {}
        final currentMode = themeProv?.mode ?? ThemeMode.light;
        final currentLang = localeProv?.language ?? AppLanguage.system;

        Widget modeChip(ThemeMode m, IconData icon, String label) {
          final selected = currentMode == m;
          return Expanded(
            child: Material(
              color: selected ? ac.navy : ac.surf2,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => themeProv?.setMode(m),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 18, color: selected ? ac.gold : ac.txt2),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : ac.txt2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        Widget langChip(AppLanguage l, String label) {
          final selected = currentLang == l;
          return Expanded(
            child: Material(
              color: selected ? ac.navy : ac.surf2,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => localeProv?.setLanguage(l),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : ac.txt2,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return AlertDialog(
          backgroundColor: ac.surf,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.palette_outlined, color: ac.navy, size: 20),
              const SizedBox(width: 8),
              Text(
                'Appearance Customization',
                style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w700, color: ac.txt),
              ),
            ],
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme Mode',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: ac.txt2),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    modeChip(ThemeMode.light, Icons.light_mode_rounded, 'Light'),
                    const SizedBox(width: 8),
                    modeChip(ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
                    const SizedBox(width: 8),
                    modeChip(ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Interface Language',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: ac.txt2),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    langChip(AppLanguage.system, 'System'),
                    const SizedBox(width: 8),
                    langChip(AppLanguage.english, 'English'),
                    const SizedBox(width: 8),
                    langChip(AppLanguage.french, 'Français'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: ac.primary)),
            ),
          ],
        );
      },
    );
  }
}

