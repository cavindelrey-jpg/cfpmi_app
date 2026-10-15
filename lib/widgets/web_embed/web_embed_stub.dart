// Non-web stub for WebDocEmbed. On mobile/desktop the native viewers
// (pdfrx, video, etc.) handle files, so this is never used to render —
// it just satisfies the import on non-web targets.
import 'package:flutter/material.dart';

bool get isWebPlatform => false;

class WebDocEmbed extends StatelessWidget {
  final String url;
  const WebDocEmbed({super.key, required this.url});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
