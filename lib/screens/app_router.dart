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
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../features/academic_content/library_folder_page.dart';
import '../features/academic_content/library_home_page.dart';
import '../features/announcements/announcements_page.dart';
import '../features/clubs/clubs_page.dart';
import '../features/courses_marketplace/courses_home_page.dart';
import '../features/daily_learning/daily_challenge_gate.dart';
import '../features/dashboard/universal_home_page.dart';
import '../features/magazine/magazine_feed_page.dart';
import '../features/messages/messages_home_page.dart';
import '../features/onboarding/school_admin_page.dart';
import '../features/onboarding/voucher_entry_screen.dart';
import '../features/school/exam_composer/exam_list_page.dart';
import '../features/school/homework_page.dart';
import '../features/school/marks_page.dart';
import '../features/school/parent_dashboard_page.dart';
import '../features/school/school_connect_page.dart';
import '../features/school/student_roster_page.dart';
import '../features/school/teacher_management_page.dart';
import '../features/school/timetable_page.dart';
import '../features/testing/quiz_categories_page.dart';
import '../models/library_folder.dart';
import '../models/models.dart';
import '../pages/help_support_page.dart';
import '../pages/profile_page.dart';
import '../pages/settings_page.dart';
import '../repositories/library_folder_repository.dart';
import '../repositories/magazine_repository.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_top_bar.dart';
import 'dictionary_screen.dart';
import 'first_login_screen.dart';

// ────────────────────────────────────────────────────────────────────────────
// AppRouter — watches Firebase/Supabase auth state only.
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

class _SignedOutGate extends StatefulWidget {
  const _SignedOutGate();
  @override
  State<_SignedOutGate> createState() => _SignedOutGateState();
}

class _SignedOutGateState extends State<_SignedOutGate> {
  bool _browsingAsGuest = false;

  @override
  Widget build(BuildContext context) {
    if (_browsingAsGuest) return HomeShell(user: AppUser.guest());
    return VoucherEntryScreen(onBrowseAsGuest: () => setState(() => _browsingAsGuest = true));
  }
}

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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block_outlined, size: 64, color: ac.red),
              const SizedBox(height: 16),
              Text(
                'Account Suspended',
                style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w700, color: ac.txt),
              ),
              const SizedBox(height: 8),
              Text(
                'Please contact support.',
                style: GoogleFonts.inter(color: ac.txt2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => AuthService.instance.performSignOut(context),
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// HomeShell — Unified single top bar + minimalist hover-expanding left sidebar
// ────────────────────────────────────────────────────────────────────────────

class HomeShell extends StatefulWidget {
  final AppUser user;
  const HomeShell({super.key, required this.user});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  // Current destination label.
  String _section = 'Home';

  // Sidebar defaults to narrow icon-only (false). Expands smoothly on hover
  // or when toggled via the top-bar menu button.
  bool _sidebarHovered = false;
  bool _sidebarPinned = false;

  bool get _isSidebarExpanded => _sidebarHovered || _sidebarPinned;

  // Lazy section loading so untouched destinations do not start streams early.
  final Set<String> _visited = {'Home'};

  // Canonical 23 destinations organized into logical groups.
  static const List<_NavDef> _allDestinations = [
    // Group 1: Learning & Content
    _NavDef('Home', Icons.home_rounded, Icons.home_outlined, group: 'Learning & Content'),
    _NavDef('Dictionary', Icons.menu_book_rounded, Icons.menu_book_outlined, group: 'Learning & Content'),
    _NavDef('Courses', Icons.school_rounded, Icons.school_outlined, group: 'Learning & Content'),
    _NavDef('Library', Icons.local_library_rounded, Icons.local_library_outlined, group: 'Learning & Content'),
    _NavDef('Past Questions', Icons.description_rounded, Icons.description_outlined, group: 'Learning & Content'),

    // Group 2: Assessment & Academic
    _NavDef('Tests', Icons.assignment_rounded, Icons.assignment_outlined, group: 'Assessment & Academic'),
    _NavDef('Quizzes', Icons.quiz_rounded, Icons.quiz_outlined, group: 'Assessment & Academic'),
    _NavDef('Marks', Icons.assessment_rounded, Icons.assessment_outlined, group: 'Assessment & Academic'),
    _NavDef('Homework', Icons.assignment_turned_in_rounded, Icons.assignment_turned_in_outlined, group: 'Assessment & Academic'),
    _NavDef('Timetable', Icons.calendar_today_rounded, Icons.calendar_today_outlined, group: 'Assessment & Academic'),

    // Group 3: Campus & Community
    _NavDef('School Connect', Icons.forum_rounded, Icons.forum_outlined, group: 'Campus & Community'),
    _NavDef('Announcements', Icons.campaign_rounded, Icons.campaign_outlined, group: 'Campus & Community'),
    _NavDef('Messaging', Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, group: 'Campus & Community'),
    _NavDef('Magazine', Icons.auto_stories_rounded, Icons.auto_stories_outlined, group: 'Campus & Community'),
    _NavDef('Groups', Icons.groups_rounded, Icons.groups_outlined, group: 'Campus & Community'),

    // Group 4: Administration
    _NavDef('Teacher Management', Icons.badge_rounded, Icons.badge_outlined, group: 'Administration'),
    _NavDef('Class Lists', Icons.people_alt_rounded, Icons.people_alt_outlined, group: 'Administration'),
    _NavDef('Access Codes', Icons.vpn_key_rounded, Icons.vpn_key_outlined, group: 'Administration'),
    _NavDef('Exam Composer', Icons.post_add_rounded, Icons.post_add_outlined, group: 'Administration'),

    // Group 5: Account & System
    _NavDef('Settings', Icons.settings_rounded, Icons.settings_outlined, group: 'Account & System'),
    _NavDef('Support', Icons.help_rounded, Icons.help_outline_rounded, group: 'Account & System'),
    _NavDef('Profile', Icons.person_rounded, Icons.person_outlined, group: 'Account & System'),
    _NavDef('Sign Out', Icons.logout_rounded, Icons.logout_rounded, group: 'Account & System', isSignOut: true),
  ];

  List<_NavDef> get _pageDestinations =>
      _allDestinations.where((d) => !d.isSignOut).toList(growable: false);

  @override
  void initState() {
    super.initState();
    unawaited(MagazineRepository.instance.settlePendingXp(widget.user.id));
  }

  void _select(String label) {
    if (label == 'Sign Out') {
      AuthService.instance.performSignOut(context);
      return;
    }
    setState(() {
      _section = label;
      _visited.add(label);
      if (MediaQuery.of(context).size.width < 680) {
        _sidebarPinned = false;
        _sidebarHovered = false;
      }
    });
  }

  void _toggleSidebar() {
    setState(() {
      if (_isSidebarExpanded) {
        _sidebarPinned = false;
        _sidebarHovered = false;
      } else {
        _sidebarPinned = true;
      }
    });
  }

  Widget _rawPage(_NavDef def) {
    final u = widget.user;
    switch (def.label) {
      case 'Home':
        return u.isParent
            ? ParentDashboardPage(user: u)
            : UniversalHomePage(
                user: u,
                embedded: true,
                onSelectSection: _select,
              );
      case 'Dictionary':
        return const DictionaryScreen();
      case 'Courses':
        return CoursesHomePage(user: u, embedded: true);
      case 'Library':
        return LibraryHomePage(user: u, embedded: true);
      case 'Past Questions':
        return _PastQuestionsWorkspace(user: u);
      case 'Tests':
      case 'Quizzes':
        return QuizCategoriesPage(user: u, embedded: true);
      case 'Marks':
        return MarksPage(user: u);
      case 'Homework':
        return HomeworkPage(user: u);
      case 'Timetable':
        return TimetablePage(user: u);
      case 'School Connect':
        return SchoolConnectPage(user: u);
      case 'Announcements':
        return AnnouncementsPage(
          user: u,
          canPost: !u.isGuest && u.canPostAnnouncement,
        );
      case 'Messaging':
        return MessagesHomePage(user: u);
      case 'Magazine':
        return MagazineFeedPage(user: u, embedded: true);
      case 'Groups':
        return ClubsPage(user: u, embedded: true);
      case 'Teacher Management':
        return TeacherManagementPage(admin: u);
      case 'Class Lists':
        return StudentRosterPage(user: u);
      case 'Access Codes':
        return SchoolAdminPage(user: u);
      case 'Exam Composer':
        return ExamListPage(user: u);
      case 'Settings':
        return SettingsPage(user: u);
      case 'Support':
        return const HelpSupportPage();
      case 'Profile':
        return ProfilePage(user: u, embedded: true);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _workspace(List<_NavDef> sections, int currentIdx) {
    return IndexedStack(
      index: currentIdx,
      children: List.generate(sections.length, (i) {
        final def = sections[i];
        if (!_visited.contains(def.label)) return const SizedBox.shrink();
        return _rawPage(def);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final sections = _pageDestinations;
    var currentIdx = sections.indexWhere((n) => n.label == _section);
    if (currentIdx < 0) currentIdx = 0;
    final activeTitle = sections[currentIdx].label;
    _visited.add(activeTitle);

    final isCompact = MediaQuery.of(context).size.width < 680;

    return Scaffold(
      backgroundColor: ac.bg,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Single unified top bar across the entire application.
            AppTopBar(
              user: widget.user,
              compact: isCompact,
              title: activeTitle,
              sidebarExpanded: _isSidebarExpanded,
              onMenu: _toggleSidebar,
              onSettings: () => _select('Settings'),
              onProfile: () => _select('Profile'),
            ),
            const _OfflineBanner(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _leftSidebar(ac, activeTitle, isCompact: isCompact),
                  Expanded(child: _workspace(sections, currentIdx)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leftSidebar(AppColors ac, String activeTitle, {required bool isCompact}) {
    final exp = _isSidebarExpanded;
    return MouseRegion(
      onEnter: (_) {
        if (!isCompact && !_sidebarHovered) setState(() => _sidebarHovered = true);
      },
      onExit: (_) {
        if (_sidebarHovered || _sidebarPinned) {
          setState(() {
            _sidebarHovered = false;
            _sidebarPinned = false;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: exp ? 248 : (isCompact ? 0 : 64),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: ac.navy,
          border: isCompact && !exp
              ? null
              : Border(
                  right: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
                ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 40) return const SizedBox.shrink();
            // Only render labels/group headers once the animated container has
            // expanded wide enough, preventing transient horizontal overflows.
            final showExpandedDetails = exp && constraints.maxWidth >= 150;
            final children = <Widget>[];
            String? lastGroup;

            for (final def in _allDestinations) {
              if (showExpandedDetails && def.group != lastGroup) {
                if (lastGroup != null) {
                  children.add(const SizedBox(height: 8));
                  children.add(
                    Divider(
                      height: 1,
                      thickness: 0.6,
                      indent: 12,
                      endIndent: 12,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  );
                }
                children.add(_sidebarGroupHeader(ac, def.group));
                lastGroup = def.group;
              }
              children.add(
                _sidebarNavTile(
                  ac: ac,
                  def: def,
                  selected: !def.isSignOut && def.label == activeTitle,
                  showExpandedDetails: showExpandedDetails,
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              children: children,
            );
          },
        ),
      ),
    );
  }

  Widget _sidebarGroupHeader(AppColors ac, String groupTitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Text(
        groupTitle.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: ac.gold.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Widget _sidebarNavTile({
    required AppColors ac,
    required _NavDef def,
    required bool selected,
    required bool showExpandedDetails,
  }) {
    final isDanger = def.isSignOut;
    final color = isDanger
        ? const Color(0xFFF87171)
        : (selected ? ac.gold : Colors.white.withValues(alpha: 0.80));

    final iconWidget = Tooltip(
      message: def.label,
      waitDuration: const Duration(milliseconds: 220),
      preferBelow: false,
      verticalOffset: 12,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF061326),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 0.6),
      ),
      textStyle: GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: Colors.white,
      ),
      child: Icon(
        selected ? def.filledIcon : def.outlinedIcon,
        color: color,
        size: 20,
      ),
    );

    final tile = Container(
      height: 40,
      decoration: BoxDecoration(
        color: selected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: showExpandedDetails
          ? Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected ? ac.gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                iconWidget,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    def.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
              ],
            )
          : Center(child: iconWidget),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _select(def.label),
          child: tile,
        ),
      ),
    );
  }
}

class _NavDef {
  final String label;
  final IconData filledIcon;
  final IconData outlinedIcon;
  final String group;
  final bool isSignOut;

  const _NavDef(
    this.label,
    this.filledIcon,
    this.outlinedIcon, {
    required this.group,
    this.isSignOut = false,
  });
}

class _PastQuestionsWorkspace extends StatelessWidget {
  final AppUser user;
  const _PastQuestionsWorkspace({required this.user});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LibraryFolder?>(
      future: LibraryFolderRepository.instance.rootFolderByName('Past Papers'),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final folder = snap.data;
        if (folder == null) {
          return LibraryHomePage(user: user, embedded: true);
        }
        return LibraryFolderPage(
          folderId: folder.id,
          folderName: folder.name,
          user: user,
        );
      },
    );
  }
}

/// Tells the student they're offline and what still works.
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
          child: Row(
            children: [
              Icon(Icons.wifi_off_rounded, size: 16, color: ac.org),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline — saved downloads & dictionary open.',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: ac.org),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DictionaryScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: ac.org.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Dictionary',
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.org),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LibraryHomePage(user: AppUser.guest())),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: ac.org.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Downloads',
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.org),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

