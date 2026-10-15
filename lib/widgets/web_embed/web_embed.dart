// Conditional export: WebDocEmbed renders a document in an <iframe> on web,
// and is a no-op stub elsewhere. `isWebPlatform` lets callers branch to the
// web path without importing dart:html directly.
//
// Office viewer helper: wraps a PUBLIC file URL in Microsoft's Office Online
// embed viewer so .pptx/.docx/.xlsx render in the browser.
export 'web_embed_stub.dart' if (dart.library.html) 'web_embed_web.dart';

/// Microsoft Office Online embed URL for a public Office document URL.
String officeViewerUrl(String fileUrl) =>
    'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(fileUrl)}';

/// Google Docs viewer URL — fallback that also renders PDFs/Office files.
String gdocsViewerUrl(String fileUrl) =>
    'https://docs.google.com/viewer?url=${Uri.encodeComponent(fileUrl)}&embedded=true';
