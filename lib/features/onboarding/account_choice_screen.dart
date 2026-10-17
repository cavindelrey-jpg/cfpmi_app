// lib/features/onboarding/account_choice_screen.dart
// Reached from the Home dashboard's "Join Free" / "Create Free Account" CTAs.
// The account/entitlement system's three tiers (core/feature_access.dart):
//   1. Individual     — free identity, no payment.
//   2. Premium Silver — direct payment (MoMo/Orange Money) or an Academia
//                       vendor voucher. Every premium feature except Video
//                       Courses.
//   3. Premium Gold   — same two funding paths, full access including
//                       Video Courses.
// A voucher received from a vendor is redeemed from Profile after signing
// in (features/entitlements/redeem_voucher_page.dart) — it needs an
// existing account, so it isn't offered as a fourth choice here.

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_colors.dart';
import '../../config/branding.dart';
import '../../models/entitlement.dart';
import '../../widgets/widgets.dart';
import '../../widgets/app_background.dart';
import 'create_account_screen.dart';

class AccountChoiceScreen extends StatelessWidget {
  const AccountChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Scaffold(
      backgroundColor: ac.bg,
      appBar: AppBar(
        backgroundColor: ac.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: ac.txt),
      ),
      body: AppBackground(child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Center(child: BrandLogo(size: 52)),
            const SizedBox(height: 20),
            Text('Create your account',
                style: AppText.h1.copyWith(fontSize: 24, color: ac.txt)),
            const SizedBox(height: 6),
            Text('Choose how you want to join ${Branding.current.appName}.',
                style: AppText.body.copyWith(fontSize: 14, color: ac.txt2)),
            const SizedBox(height: 24),

            _ChoiceCard(
              icon: Icons.person_outline_rounded,
              iconColor: ac.primary,
              iconBg: ac.primaryBg,
              title: 'Individual',
              subtitle: 'Free. Get an identity to post, comment, and '
                  'message under your own name instead of anonymously.',
              badge: 'Free',
              badgeColor: ac.grn,
              badgeBg: ac.grnBg,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CreateAccountScreen(tier: EntitlementTier.free))),
            ),
            const SizedBox(height: 12),

            _ChoiceCard(
              icon: Icons.workspace_premium_outlined,
              iconColor: ac.txt2,
              iconBg: ac.surf3,
              title: 'Premium Silver',
              subtitle: 'Direct payment or a vendor voucher. '
                  'Every premium feature — except Video Courses.',
              badge: 'Premium',
              badgeColor: ac.navy,
              badgeBg: ac.surf3,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CreateAccountScreen(tier: EntitlementTier.silver))),
            ),
            const SizedBox(height: 12),

            _ChoiceCard(
              icon: Icons.workspace_premium_rounded,
              iconColor: ac.gold,
              iconBg: ac.goldBg,
              title: 'Premium Gold',
              subtitle: 'Direct payment or a vendor voucher. '
                  'Full access, including Video Courses.',
              badge: 'Most Popular',
              badgeColor: ac.navy,
              badgeBg: ac.gold,
              isHighlighted: true,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CreateAccountScreen(tier: EntitlementTier.gold))),
            ),

            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Continue browsing as Guest',
                    style: AppText.subtitle.copyWith(fontSize: 13, color: ac.txt2)),
              ),
            ),
          ]),
        ),
      )),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final Color badgeBg;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon, required this.iconColor, required this.iconBg,
    required this.title, required this.subtitle,
    required this.badge, required this.badgeColor, required this.badgeBg,
    this.isHighlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final radius = BorderRadius.circular(Rad.md);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ac.surf,
            borderRadius: radius,
            border: Border.all(
              color: isHighlighted ? ac.gold : ac.bdr.withValues(alpha: 0.7),
              width: isHighlighted ? 1.5 : 0.8,
            ),
            boxShadow: Shad.card,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Nested radius rule: outer Rad.md (16) - 8px visual inset = 8px (Rad.xs)
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(Rad.xs),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(title,
                      style: AppText.title.copyWith(fontSize: 15, color: ac.txt))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                    child: Text(badge,
                        style: AppText.label.copyWith(
                            fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor, letterSpacing: 0.6)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(subtitle,
                    style: AppText.bodySm.copyWith(fontSize: 12.5, color: ac.txt2, height: 1.55)),
              ]),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: ac.muted),
          ]),
        ),
      ),
    );
  }
}
