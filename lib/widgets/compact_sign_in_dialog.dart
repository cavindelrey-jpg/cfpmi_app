// lib/widgets/compact_sign_in_dialog.dart
// Compact centered sign-in dialog for guests. Enables instant sign-in
// without full-page redirection, keeping the application shell intact.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../features/onboarding/voucher_entry_screen.dart';

Future<bool?> showCompactSignInDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => const CompactSignInDialog(),
  );
}

class CompactSignInDialog extends StatefulWidget {
  const CompactSignInDialog({super.key});

  @override
  State<CompactSignInDialog> createState() => _CompactSignInDialogState();
}

class _CompactSignInDialogState extends State<CompactSignInDialog> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await AuthService.instance.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      if (user == null) {
        setState(() {
          _error = 'Account profile not found. Please contact administration.';
          _loading = false;
        });
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, ${user.name.isNotEmpty ? user.name : "User"}!'),
          backgroundColor: const Color(0xFF1B6B3A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
        _error = msg.contains('Invalid login credentials')
            ? 'Incorrect email or password.'
            : msg;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: ac.surf,
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: ac.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.lock_outline_rounded, color: ac.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sign In',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ac.txt,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 20, color: ac.muted),
                      onPressed: () => Navigator.of(context).pop(false),
                      tooltip: 'Cancel',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter your credentials to access full school features.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: ac.muted),
                ),
                const SizedBox(height: 18),

                // Error Banner
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF87171)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF991B1B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.inter(fontSize: 13.5, color: ac.txt),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: GoogleFonts.inter(fontSize: 13, color: ac.muted),
                    prefixIcon: Icon(Icons.email_outlined, size: 18, color: ac.muted),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your email.';
                    if (!v.contains('@')) return 'Enter a valid email.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Password
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  style: GoogleFonts.inter(fontSize: 13.5, color: ac.txt),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: GoogleFonts.inter(fontSize: 13, color: ac.muted),
                    prefixIcon: Icon(Icons.key_outlined, size: 18, color: ac.muted),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18, color: ac.muted),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your password.';
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 18),

                // Submit Button
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ac.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          'Sign In',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                ),
                const SizedBox(height: 14),

                // Voucher Link
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => VoucherEntryScreen(
                            onBrowseAsGuest: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Have a school voucher code? Activate here',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: ac.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
