// lib/pages/privacy_policy_page.dart
// Privacy Policy & Data Protection page with genuine data practices,
// user rights under GDPR/local data protection laws, and contact details.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/branding.dart';
import '../models/app_user.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/application_shell.dart';

class PrivacyPolicyPage extends StatelessWidget {
  final AppUser user;
  const PrivacyPolicyPage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final appName = Branding.current.appName;

    return ApplicationShell(
      user: user,
      currentTitle: 'Privacy Policy',
      currentDestination: AppNavDestination.settings,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: ac.surf,
              borderRadius: BorderRadius.circular(Rad.md),
              border: Border.all(color: ac.bdr),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$appName Privacy & Data Protection Policy',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ac.txt,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Last updated: October 2026 • Effective immediately',
                  style: GoogleFonts.inter(fontSize: 12, color: ac.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _section(
            ac,
            '1. Information We Collect',
            'We collect and process only the minimal personal information required to deliver academic and institutional services:\n\n'
                '• Account Data: Full name, institutional email address, assigned school, role, and class level.\n'
                '• Academic Records: Exam marks, sequence assessments, teacher remarks, and attendance logs.\n'
                '• Classroom Activity: Participation in live synchronized lessons, notes, and downloaded academic documents.\n'
                '• Institutional Fee Records: Administrative tuition obligations and recorded bank-slip payment receipts (we do not process financial transactions in-app).',
          ),
          _section(
            ac,
            '2. How Your Information Is Used',
            'Your data is processed strictly for educational purposes:\n\n'
                '• Generating student report cards, transcripts, and honour roll recognition.\n'
                '• Delivering real-time classroom presentations and courseware.\n'
                '• Sending essential notifications and automated SMS result releases to verified guardians.\n'
                '• We never sell, rent, or monetize personal student or teacher information to third parties.',
          ),
          _section(
            ac,
            '3. Data Storage & Security',
            'All credentials and student records are encrypted both in transit (TLS 1.3) and at rest with strict Row Level Security (RLS) policies enforcing single-institution data separation. Only authorized school staff may access student academic records.',
          ),
          _section(
            ac,
            '4. Your Rights & Account Deletion',
            'You have the legal right to inspect, correct, export, or permanently delete your account and associated personal data at any time. To request account deletion or data removal, visit Settings > Delete Account or email privacy@cfpmi.org.',
          ),
          _section(
            ac,
            '5. Contact Data Protection Officer',
            'For questions regarding institutional compliance or student data privacy, contact the institutional administration:\n\n'
                'Email: privacy@cfpmi.org\n'
                'Institution: CFPMI Academic & Professional Complex\n'
                'Location: Yaoundé / Douala, Cameroon',
          ),
        ],
      ),
    );
  }

  Widget _section(AppColors ac, String heading, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ac.surf,
        borderRadius: BorderRadius.circular(Rad.md),
        border: Border.all(color: ac.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: ac.txt,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: ac.txt2,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
