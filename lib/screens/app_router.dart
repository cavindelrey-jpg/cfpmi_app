// lib/screens/app_router.dart
// Root navigator. 2026-09 correction: a fresh install (no session) shows
// VoucherEntryScreen FIRST — activate with a code or log in to an
// existing (already-activated) account — with guest browsing one tap
// away, not the default. Once signed in (including after a code is
// redeemed once), reopening the app skips straight to HomeShell — this
// screen only ever appears when authStateChanges reports signed-out, so
// a returning user with a live session, or one who reinstalls and logs
// back into their existing account, never sees it again. School
// membership (schoolId/schoolRole on AppUser) is orthogonal to the
// 6-role UserRole permission system, which still governs content
// moderation/authoring privilege independent of any school.

import 'dart:async';
import '../features/daily_learning/daily_challenge_gate.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../repositories/magazine_repository.dart';
import 'first_login_screen.dart';
// pages
import '../features/academic_content/library_home_page.dart';
import '../features/courses_marketplace/courses_home_page.dart';
import '../pages/profile_page.dart';
import '../features/dashboard/universal_home_page.dart';
import '../features/school/parent_dashboard_page.dart';
import '../features/magazine/magazine_feed_page.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/create_content_sheet.dart';
import '../features/testing/quiz_categories_page.dart';
import '../features/clubs/clubs_page.dart';
import '../features/school/school_connect_page.dart';
import '../features/school/timetable_page.dart';
import '../features/school/daily_notices/daily_notices_page.dart';
import '../features/school/school_calendar_page.dart';
import '../features/school/attendance_page.dart';
import '../features/school/attendance_summary_page.dart';
import '../features/school/fees_page.dart';
import '../features/school/marks_page.dart';
import '../features/school/student_records_page.dart';
import '../features/classroom/classroom_teacher_page.dart';
import '../features/classroom/student_classroom_page.dart';
import '../features/onboarding/voucher_entry_screen.dart';
import 'dictionary_screen.dart';

// ────────────────────────────────────────────────────────────────────────────
// AppRouter — watches Firebase auth state only.
//
//  1. Nobody signed in → VoucherEntryScreen (the front door: activate
//     with a code, log in, or "continue browsing without a code" ->
//     _GuestShell).
//  2. Somebody IS signed in → HomeShell (via _AppUserGate).
// ────────────────────────────────────────────────────────────────────────────

class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  late Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = AuthService.instance.authStateChanges;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      initialData: AuthService.instance.firebaseUser,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == null) {
          return const _SignedOutGate();
        }
        return const _AppUserGate();
      },
    );
  }
}

/// Toggles between the voucher/login front door and full guest browsing,
/// purely a local UI choice (never touches auth) — tapping "Continue
/// browsing without a code" on VoucherEntryScreen just swaps which of
/// these two this widget shows.
class _SignedOutGate extends StatefulWidget {
  const _SignedOutGate();
  @override
  State<_SignedOutGate> createState() => _SignedOutGateState();
}

class _SignedOutGateState extends State<_SignedOutGate> {
  bool _browsingAsGuest = false;

  @override
  Widget build(BuildContext context) {
    // Guests get the SAME application shell as signed-in users (desktop rail
    // + global top bar on wide screens, bottom nav on phones) — just driven
    // by AppUser.guest(), whose guest role gates what each section shows.
    // Previously guests fell into a separate mobile-only _GuestShell that
    // hardcoded a bottom nav bar at every width, so the desktop/web landing
    // looked like a phone app stretched onto a 16:9 screen. One shell now.
    if (_browsingAsGuest) return HomeShell(user: AppUser.guest());
    return VoucherEntryScreen(onBrowseAsGuest: () => setState(() => _browsingAsGuest = true));
  }
}

/// Gate for signed-in users — resolves the account (suspended / first-login
/// / normal) and lands on HomeShell.
class _AppUserGate extends StatefulWidget {
  const _AppUserGate();

  @override
  State<_AppUserGate> createState() => _AppUserGateState();
}

class _AppUserGateState extends State<_AppUserGate> {
  late Stream<AppUser?> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = AuthService.instance.currentAppUserStream();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _userStream,
      initialData: AuthService.instance.lastKnownUser,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting && snap.data == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) {
          // currentAppUserStream() only ever emits null after a
          // SUCCESSFUL fetch that found no row at all (account deleted
          // server-side) — a network failure/offline reconnect keeps
          // showing the last cached/known user instead of reaching
          // here, so this signOut() no longer fires on a connectivity
          // hiccup (see auth_service.dart's currentAppUserStream doc).
          AuthService.instance.signOut();
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (user.status == AccountStatus.suspended) return _SuspendedScreen(user: user);
        if (user.isFirstLogin) return FirstLoginScreen(user: user);
        return DailyChallengeGate(user: user, child: HomeShell(user: user));
      },
    );
  }
}

class _SuspendedScreen extends StatelessWidget {
  final AppUser user;
  const _SuspendedScreen({required this.user});
  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.block_outlined, size: 64, color: ac.red),
          const SizedBox(height: 16),
          Text('Account Suspended',
              style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: ac.txt)),
          const SizedBox(height: 8),
          Text('Please contact support.',
              style: GoogleFonts.inter(color: ac.txt2), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          OutlinedButton(
              onPressed: () => AuthService.instance.performSignOut(context),
              child: const Text('Sign Out')),
        ]),
      )),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// HomeShell — role-gated bottom navigation
// ────────────────────────────────────────────────────────────────────────────

class HomeShell extends StatefulWidget {
  final AppUser user;
  const HomeShell({super.key, required this.user});
  @override State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // Current primary section, by stable label (not an index), so the wide
  // desktop rail and the narrower mobile bottom bar can select from the same
  // canonical section set without index drift.
  String _section = 'Home';

  // Selected School sub-destination (desktop secondary rail).
  int _schoolSub = 0;

  // Desktop primary rail: expanded with labels by default (matches the
  // design reference), collapsible to an icon-only rail via the top-bar menu.
  bool _railExpanded = true;

  // Lazy section loading: only a visited section's page is built, so an
  // untouched section's own streams never start until it's first opened.
  final Set<String> _visited = {'Home'};

  // Desktop/web breakpoint. At/above this width the shell renders the
  // persistent rail + workspace; below it, the mobile bottom-nav bar — two
  // deliberately different navigation surfaces over the same sections.
  static const double _wideBreakpoint = 900;

  // Mobile bottom bar keeps a focused 5 (the rest reach via the top-bar menu
  // / drawer); desktop surfaces the full set in the rail.
  static const List<String> _mobileSections = [
    'Home', 'Courses', 'Library', 'Groups', 'Profile',
  ];

  @override
  void initState() {
    super.initState();
    // Recovery sweep for any magazine-read XP that was durably recorded
    // as "owed" (see MagazineRepository.recordRead()) but never settled
    // — e.g. this device was offline right after a reader's first visit.
    // Fire-and-forget, cheap no-op when nothing's pending; deliberately
    // not blocking the shell's first frame on it.
    unawaited(MagazineRepository.instance.settlePendingXp(widget.user.id));
  }

  void _select(String label) {
    setState(() {
      _section = label;
      _visited.add(label);
    });
  }

  // Canonical primary sections (desktop rail order), role-gated. `maxWidth`
  // is the desktop workspace constraint: null = full-bleed (the page manages
  // its own widths — used for already-redesigned/task-specific workspaces),
  // a value = a transitional cap so a not-yet-redesigned page doesn't stretch.
  List<_NavDef> _sections() {
    final u = widget.user;
    final defs = <_NavDef>[
      const _NavDef('Home', Icons.home_rounded, Icons.home_outlined, UserRole.guest),
      const _NavDef('Courses', Icons.school_rounded, Icons.school_outlined, UserRole.guest),
      const _NavDef('Library', Icons.menu_book_rounded, Icons.menu_book_outlined, UserRole.guest),
      const _NavDef('Magazine', Icons.auto_stories_rounded, Icons.auto_stories_outlined, UserRole.guest, maxWidth: 1100),
      const _NavDef('Groups', Icons.groups_rounded, Icons.groups_outlined, UserRole.guest, maxWidth: 1180),
      const _NavDef('Tests', Icons.quiz_rounded, Icons.quiz_outlined, UserRole.guest, maxWidth: 1180),
      if (u.isSchoolMember)
        const _NavDef('School', Icons.apartment_rounded, Icons.apartment_outlined, UserRole.guest),
      const _NavDef('Profile', Icons.person_rounded, Icons.person_outlined, UserRole.guest, maxWidth: 1000),
    ];
    return defs.where((n) => u.hasMinRole(n.minRole)).toList();
  }

  // The raw feature page for a section (each keeps its own Scaffold/streams).
  Widget _rawPage(AppColors ac, _NavDef def, bool isWide) {
    final u = widget.user;
    switch (def.label) {
      // A parent's Home shows their linked student's info, never their own.
      case 'Home':     return u.isParent ? ParentDashboardPage(user: u) : UniversalHomePage(user: u, embedded: true);
      case 'Courses':  return CoursesHomePage(user: u);
      case 'Library':  return LibraryHomePage(user: u);
      case 'Magazine': return MagazineFeedPage(user: u, embedded: true);
      case 'Groups':   return ClubsPage(user: u, embedded: true);
      case 'Tests':    return QuizCategoriesPage(user: u, embedded: true);
      case 'School':   return isWide ? _schoolWorkspaceDesktop(ac) : _schoolWorkspaceMobile(ac);
      case 'Profile':  return ProfilePage(user: u, embedded: true);
      default:         return const SizedBox.shrink();
    }
  }

  // Applies the desktop workspace width policy; mobile is always full width.
  Widget _sectionBody(AppColors ac, _NavDef def, bool isWide) {
    final page = _rawPage(ac, def, isWide);
    if (!isWide || def.maxWidth == null) return page;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: def.maxWidth!),
        child: page,
      ),
    );
  }

  Widget _workspace(AppColors ac, List<_NavDef> sections, int currentIdx, bool isWide) {
    return IndexedStack(
      index: currentIdx,
      children: List.generate(sections.length, (i) {
        final def = sections[i];
        if (!_visited.contains(def.label)) return const SizedBox.shrink();
        return _sectionBody(ac, def, isWide);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final sections = _sections();
    var currentIdx = sections.indexWhere((n) => n.label == _section);
    if (currentIdx < 0) currentIdx = 0;
    _visited.add(sections[currentIdx].label);

    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    return isWide
        ? _desktopScaffold(ac, sections, currentIdx)
        : _mobileScaffold(ac, sections, currentIdx);
  }

  // ── Mobile: global top bar + bottom-nav shell (phones) ─────────────
  Widget _mobileScaffold(AppColors ac, List<_NavDef> sections, int currentIdx) {
    final mobileDefs = [
      for (final label in _mobileSections)
        sections.firstWhere((n) => n.label == label,
            orElse: () => const _NavDef('', Icons.circle, Icons.circle, UserRole.guest)),
    ].where((n) => n.label.isNotEmpty).toList();
    final selected = mobileDefs.indexWhere((n) => n.label == _section);

    return Scaffold(
      key: _scaffoldKey,
      // One shared top bar (logo + global search/notifications/account),
      // instead of each page drawing its own header.
      appBar: AppTopBar(
        user: widget.user,
        compact: true,
        onMenu: () => _scaffoldKey.currentState?.openDrawer(),
        onProfile: () => _select('Profile'),
      ),
      drawer: AppDrawer(user: widget.user, onHomeTap: () => _select('Home')),
      body: SafeArea(
        top: false,
        child: Column(children: [
          const _OfflineBanner(),
          Expanded(child: _workspace(ac, sections, currentIdx, false)),
        ]),
      ),
      // Architecture brief item 14: content creation lives behind this
      // one "+" button instead of permanent per-page CTA cards.
      floatingActionButton: FloatingActionButton(
        backgroundColor: ac.gold,
        onPressed: () => showCreateContentSheet(context, widget.user),
        child: Icon(Icons.add_rounded, color: ac.navy),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: ac.surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.lg)),
          boxShadow: Shad.lg,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Rad.lg)),
          child: NavigationBar(
            selectedIndex: selected < 0 ? 0 : selected,
            onDestinationSelected: (i) => _select(mobileDefs[i].label),
            // Labels under every icon (not just the selected one): the
            // design notes recommend this for a mixed/less tech-savvy
            // audience (parents, teachers, students).
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: mobileDefs.map((n) => NavigationDestination(
              icon: Icon(n.outlinedIcon), selectedIcon: Icon(n.filledIcon), label: n.label,
            )).toList(),
          ),
        ),
      ),
    );
  }

  // ── Desktop/web: global top bar + persistent rail + workspace ──────
  Widget _desktopScaffold(AppColors ac, List<_NavDef> sections, int currentIdx) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(user: widget.user, onHomeTap: () => _select('Home')),
      body: Column(
        children: [
          // One global bar across the whole app width, sitting above the rail.
          AppTopBar(
            user: widget.user,
            onMenu: () => setState(() => _railExpanded = !_railExpanded),
            onProfile: () => _select('Profile'),
          ),
          const _OfflineBanner(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _desktopSidebar(ac, sections, currentIdx),
                // The workspace fills the rest; each section decides its own
                // width (full-bleed or capped) via _sectionBody — no single
                // global container forcing one layout on every page. The
                // School section renders its own persistent secondary rail.
                Expanded(child: _workspace(ac, sections, currentIdx, true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  // School sub-destinations — role-aware, each a real wired page. Builders
  // (not pre-pushed routes) so the one list drives both the desktop in-shell
  // secondary rail and the mobile menu.
  List<(IconData, String, Widget Function())> _schoolDests() {
    final u = widget.user;
    final staff = u.canRecordAnyMarks || (u.isSchoolMember && !u.isStudent && !u.isParent);
    return [
      (Icons.forum_outlined, 'School Connect', () => SchoolConnectPage(user: u)),
      (Icons.event_note_outlined, 'Timetable', () => TimetablePage(user: u)),
      (Icons.campaign_outlined, 'Daily Notices', () => DailyNoticesPage(user: u)),
      (Icons.calendar_month_outlined, 'Calendar', () => SchoolCalendarPage(user: u)),
      if (staff) ...[
        (Icons.fact_check_outlined, 'Attendance', () => AttendancePage(user: u)),
        (Icons.query_stats_rounded, 'Attendance Summary', () => AttendanceSummaryPage(user: u)),
        (Icons.account_balance_wallet_outlined, 'Fees', () => FeesPage(user: u)),
        (Icons.assessment_outlined, 'Marks', () => MarksPage(user: u)),
        (Icons.cast_for_education_rounded, 'Classroom', () => ClassroomTeacherPage(user: u)),
      ] else ...[
        (Icons.badge_outlined, 'My Records', () => StudentRecordsPage(user: u)),
        (Icons.assessment_outlined, 'My Marks', () => MarksPage(user: u)),
        (Icons.sensors_rounded, 'Live Class', () => StudentClassroomPage(user: u)),
      ],
    ];
  }

  // Desktop School workspace: a persistent secondary rail (stays put as the
  // user moves between School tools) + the selected tool in the workspace —
  // so the primary rail never disappears the way the old _push flow did.
  Widget _schoolWorkspaceDesktop(AppColors ac) {
    final dests = _schoolDests();
    final sub = _schoolSub.clamp(0, dests.length - 1);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 236,
          decoration: BoxDecoration(
            color: ac.surf,
            border: Border(right: BorderSide(color: ac.bdr)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Text('School',
                    style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.w800, color: ac.txt)),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    for (int i = 0; i < dests.length; i++)
                      _schoolRailTile(ac, dests[i].$1, dests[i].$2, i == sub,
                          () => setState(() => _schoolSub = i)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: dests[sub].$3()),
      ],
    );
  }

  Widget _schoolRailTile(AppColors ac, IconData icon, String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? ac.primary.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Row(children: [
              Icon(icon, size: 19, color: selected ? ac.primary : ac.txt2),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? ac.txt : ac.txt2)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // Mobile School: no room for a side rail — the tools are a list; each opens
  // full-screen while the bottom nav remains the shell.
  Widget _schoolWorkspaceMobile(AppColors ac) {
    final dests = _schoolDests();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 10),
          child: Text('School',
              style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800, color: ac.txt)),
        ),
        for (final (icon, label, builder) in dests)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Material(
              color: ac.surf,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _push(builder()),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                  child: Row(children: [
                    Icon(icon, size: 22, color: ac.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(label,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: ac.txt)),
                    ),
                    Icon(Icons.chevron_right_rounded, color: ac.muted),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _desktopSidebar(AppColors ac, List<_NavDef> sections, int currentIdx) {
    final exp = _railExpanded;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: exp ? 232 : 76,
      decoration: BoxDecoration(
        color: ac.surf,
        border: Border(right: BorderSide(color: ac.bdr)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Collapse/expand toggle (the brand/logo lives in the global top bar).
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
            child: Align(
              alignment: exp ? Alignment.centerLeft : Alignment.center,
              child: IconButton(
                icon: Icon(exp ? Icons.menu_open_rounded : Icons.menu_rounded, color: ac.txt2),
                tooltip: exp ? 'Collapse menu' : 'Expand menu',
                onPressed: () => setState(() => _railExpanded = !_railExpanded),
              ),
            ),
          ),
          // One CTA colour, reachable (the gold "+"): a pill when expanded,
          // a round icon with a tooltip when collapsed.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
            child: exp
                ? FilledButton.icon(
                    onPressed: () => showCreateContentSheet(context, widget.user),
                    style: FilledButton.styleFrom(
                      backgroundColor: ac.gold,
                      foregroundColor: ac.navy,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Create', style: TextStyle(fontWeight: FontWeight.w700)),
                  )
                : Center(
                    child: Tooltip(
                      message: 'Create',
                      child: Material(
                        color: ac.gold,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => showCreateContentSheet(context, widget.user),
                          child: SizedBox(
                            width: 46,
                            height: 46,
                            child: Icon(Icons.add_rounded, color: ac.navy, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              children: [
                for (int i = 0; i < sections.length; i++)
                  _desktopNavTile(ac, sections[i], i == currentIdx, exp),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Collapsed: centred icon + tooltip. Expanded: icon + label + left bar.
  // Active state keeps 2+ distinct changes either way (tinted pill + brand
  // colour + filled icon [+ bold label / left bar when expanded]).
  Widget _desktopNavTile(AppColors ac, _NavDef def, bool selected, bool expanded) {
    final color = selected ? ac.primary : ac.txt2;
    final tile = Container(
      height: 46,
      decoration: BoxDecoration(
        color: selected ? ac.primary.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: expanded
          ? Row(
              children: [
                Container(
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? ac.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 11),
                Icon(selected ? def.filledIcon : def.outlinedIcon, color: color, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(def.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color)),
                ),
              ],
            )
          : Center(child: Icon(selected ? def.filledIcon : def.outlinedIcon, color: color, size: 24)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _select(def.label),
          child: expanded ? tile : Tooltip(message: def.label, child: tile),
        ),
      ),
    );
  }
}

class _NavDef {
  final String label;
  final IconData filledIcon, outlinedIcon;
  final UserRole minRole;

  /// Desktop workspace width cap for this section. null = full-bleed (the
  /// page manages its own widths — used for task-specific workspaces).
  final double? maxWidth;
  const _NavDef(this.label, this.filledIcon, this.outlinedIcon, this.minRole, {this.maxWidth});
}


/// Tells the student they're offline and what still works, instead of
/// sections silently showing "nothing here yet".
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return StreamBuilder<bool>(
      stream: ConnectivityService().watchOffline(),
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: ac.orgBg,
          child: Row(children: [
            Icon(Icons.wifi_off_rounded, size: 16, color: ac.org),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Offline — saved downloads & dictionary open.',
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: ac.org),
            )),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DictionaryScreen())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: ac.org.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Dictionary', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.org)),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LibraryHomePage(user: AppUser.guest()))),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: ac.org.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Downloads', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.org)),
              ),
            ),
          ]),
        );
      },
    );
  }
}
