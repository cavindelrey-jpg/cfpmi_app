// lib/features/school/widgets/management_scaffold.dart
// Shared scaffold for admin/teacher management pages (Homework Management,
// Teacher Management, School Calendar, Marks/Timetable management, Roster, etc.).
// Wraps inside the unified 3-column ApplicationShell so that the persistent left
// navigation rail and contextual right sidebar remain consistent across every
// school management route.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/app_user.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/application_shell.dart';

const double kWideBreakpoint = 900;

class ManagementNavItem {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const ManagementNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });
}

class ManagementScaffold extends StatelessWidget {
  final String title;
  final AppUser? user;
  final AppNavDestination navDestination;
  final List<ManagementNavItem> sidebarItems;
  final List<Widget> actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final PreferredSizeWidget? bottom;

  const ManagementScaffold({
    super.key,
    required this.title,
    this.user,
    this.navDestination = AppNavDestination.schoolConnect,
    this.sidebarItems = const [],
    this.actions = const [],
    required this.body,
    this.floatingActionButton,
    this.drawer,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    Widget? bottomBar;
    if (sidebarItems.isNotEmpty || bottom != null) {
      bottomBar = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sidebarItems.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: sidebarItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: item.selected,
                      onSelected: (_) => item.onTap?.call(),
                      avatar: Icon(
                        item.icon,
                        size: 16,
                        color: item.selected ? ac.primary : ac.txt2,
                      ),
                      label: Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight:
                              item.selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (bottom != null) ...[
            if (sidebarItems.isNotEmpty) const SizedBox(height: 8),
            bottom!,
          ],
        ],
      );
    }

    return ApplicationShell(
      user: user,
      currentTitle: title,
      currentDestination: navDestination,
      headerActions: actions.isEmpty ? null : actions,
      bottomHeader: bottomBar,
      floatingActionButton: floatingActionButton,
      child: body,
    );
  }
}
