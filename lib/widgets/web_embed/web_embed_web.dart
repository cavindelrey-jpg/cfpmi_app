// Web implementation of WebDocEmbed: renders a document inside an <iframe>
// so the browser itself displays it. Used on Flutter web, where the native
// pdfrx/local-file path cannot work (no device filesystem).
//
// The caller passes the exact URL to embed:
//   - PDFs: the file URL directly (browsers render PDFs inline in an iframe).
//   - Office files (.pptx/.docx/.xlsx): an Office Online / Google Docs viewer
//     URL wrapping the public file URL.
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

bool get isWebPlatform => true;

class WebDocEmbed extends StatelessWidget {
  final String url;
  const WebDocEmbed({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final viewType = 'cfpmi-doc-${url.hashCode}';
    // Registering the same viewType twice is a harmless no-op.
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;
      return iframe;
    });
    return HtmlElementView(viewType: viewType);
  }
}
