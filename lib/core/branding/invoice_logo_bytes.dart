import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Fetches remote logo bytes for PDF rendering (public bucket URLs).
Future<Uint8List?> fetchInvoiceLogoBytes(
  String? url, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final u = url?.trim();
  if (u == null || u.isEmpty) return null;
  try {
    final uri = Uri.tryParse(u);
    if (uri == null || !uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    final res = await http.get(uri).timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    if (res.bodyBytes.isEmpty) return null;
    return res.bodyBytes;
  } catch (_) {
    return null;
  }
}
