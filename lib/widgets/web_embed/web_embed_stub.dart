// Non-web stub for WebDocEmbed. On mobile/desktop the native viewers
// handle files. When WebDocEmbed is invoked directly on mobile/desktop,
// it presents a clean document card with an action to open the document
// rather than returning a blank SizedBox.shrink().
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

bool get isWebPlatform => false;

class WebDocEmbed extends StatelessWidget {
  final String url;
  const WebDocEmbed({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final cleanUrl = Uri.tryParse(url)?.path ?? url.split('?').first;
    final filename = cleanUrl.split('/').last;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E222B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF333A48)),
              ),
              child: const Icon(Icons.description_rounded, size: 48, color: Color(0xFFE5A93C)),
            ),
            const SizedBox(height: 16),
            Text(
              filename.isNotEmpty ? filename : 'Document Viewer',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Document ready to view',
              style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white70),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open Presentation / Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5A93C),
                foregroundColor: const Color(0xFF081630),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
