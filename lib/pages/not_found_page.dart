// lib/pages/not_found_page.dart
// Dedicated 404 Not Found screen for unknown or moved routes.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/app_user.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/application_shell.dart';

class NotFoundPage extends StatelessWidget {
  final AppUser user;
  final String? attemptedPath;

  const NotFoundPage({
    super.key,
    required this.user,
    this.attemptedPath,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return ApplicationShell(
      user: user,
      currentTitle: 'Page Not Found',
      currentDestination: AppNavDestination.none,
      showBackButton: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: ac.primaryBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.explore_off_rounded, size: 40, color: ac.primary),
                ),
                const SizedBox(height: 24),
                Text(
                  '404',
                  style: GoogleFonts.sora(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: ac.txt,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Page or Record Not Found',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: ac.txt,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  attemptedPath != null && attemptedPath!.isNotEmpty
                      ? "The requested URL '$attemptedPath' could not be found or has been moved."
                      : "The section, record, or page you are looking for doesn't exist or you don't have permission to view it.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: ac.txt2,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (Navigator.of(context).canPop()) ...[
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Go Back'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false),
                      icon: const Icon(Icons.home_rounded, size: 16),
                      label: const Text('Back to Home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ac.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.md)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
