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
import '../theme/app_colors.dart';
import '../services/auth_service.dart';
import 'first_login_screen.dart';
import '../features/dashboard/universal_home_page.dart';
import '../features/school/parent_dashboard_page.dart';
import '../features/courses_marketplace/courses_home_page.dart';
import '../features/academic_content/library_home_page.dart';
import '../features/testing/quiz_categories_page.dart';
import '../features/magazine/magazine_feed_page.dart';
import '../features/clubs/clubs_page.dart';
import '../features/messages/messages_home_page.dart';
import '../features/school/school_connect_page.dart';
import '../features/school/marks_page.dart';
import '../features/school/homework_page.dart';
import '../features/school/timetable_page.dart';
import '../features/school/attendance_page.dart';
import '../features/school/fees_page.dart';
import '../features/school/classroom_page.dart';
import '../features/school/daily_notices/daily_notices_page.dart';
import '../features/school/exam_composer/exam_list_page.dart';
import '../pages/settings_page.dart';
import '../widgets/application_shell.dart';
import '../pages/help_support_page.dart';
import '../pages/bookmarks_page.dart';
import '../features/timetable/personal_study_page.dart';
import 'dictionary_screen.dart';
import 'login_screen.dart';

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

  static Route<dynamic>? generateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name == '/' || name.isEmpty) return null;

    final user = AuthService.instance.lastKnownUser ?? AppUser.guest();

    Widget page;
    switch (name) {
      case '/courses':
        page = CoursesHomePage(user: user);
        break;
      case '/library':
        page = LibraryHomePage(user: user);
        break;
      case '/past-questions':
        page = LibraryHomePage(
          user: user,
          initialCollectionFilter: 'past_papers',
          navDestination: AppNavDestination.pastQuestions,
        );
        break;
      case '/tests':
      case '/quizzes':
        page = QuizCategoriesPage(user: user);
        break;
      case '/homework':
        page = HomeworkPage(user: user);
        break;
      case '/marks':
        page = MarksPage(user: user);
        break;
      case '/classroom':
        page = ClassroomPage(user: user);
        break;
      case '/set-exam':
      case '/exam-composer':
        page = ExamListPage(user: user);
        break;
      case '/messages':
        page = MessagesHomePage(user: user);
        break;
      case '/clubs':
        page = ClubsPage(user: user);
        break;
      case '/timetable':
        page = TimetablePage(user: user);
        break;
      case '/attendance':
        page = AttendancePage(user: user);
        break;
      case '/fees':
        page = FeesPage(user: user);
        break;
      case '/announcements':
        page = DailyNoticesPage(user: user);
        break;
      case '/magazine':
        page = MagazineFeedPage(user: user);
        break;
      case '/dictionary':
        page = DictionaryScreen(user: user);
        break;
      case '/bookmarks':
        page = BookmarksPage(user: user);
        break;
      case '/study-plan':
        page = PersonalStudyPage(user: user);
        break;
      case '/school-connect':
        page = SchoolConnectPage(user: user);
        break;
      case '/settings':
        page = SettingsPage(user: user);
        break;
      case '/help':
        page = HelpSupportPage(user: user);
        break;
      case '/login':
        page = const LoginScreen();
        break;
      default:
        return null;
    }

    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: Duration.zero,
    );
  }

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
          return const Scaffold(
            backgroundColor: Color(0xFFF5F7FA),
            body: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1A56DB)),
              ),
            ),
          );
        }
        if (snap.data == null) {
          return HomeShell(user: AppUser.guest());
        }
        return const _AppUserGate();
      },
    );
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
          return const Scaffold(
            backgroundColor: Color(0xFFF5F7FA),
            body: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1A56DB)),
              ),
            ),
          );
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
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: ac.txt)),
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
// HomeShell — primary authenticated/guest landing
// ────────────────────────────────────────────────────────────────────────────

class HomeShell extends StatelessWidget {
  final AppUser user;
  const HomeShell({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    if (user.isParent) {
      return ParentDashboardPage(user: user);
    }
    return UniversalHomePage(user: user);
  }
}


