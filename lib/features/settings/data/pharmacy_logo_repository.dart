import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

const _bucket = 'pharmacy-logos';

/// Upload / clear pharmacy logos in Supabase Storage under `{tenant_id}/…`.
class PharmacyLogoRepository {
  const PharmacyLogoRepository();

  SupabaseClient? get _client => SupabaseBootstrap.clientOrNull;

  String _contentTypeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  /// Deletes all objects under `tenantId/` in the logo bucket (best-effort).
  Future<void> clearTenantLogoObjects(String tenantId) async {
    final c = _client;
    if (c == null) return;
    try {
      final entries = await c.storage.from(_bucket).list(path: tenantId);
      if (entries.isEmpty) return;
      final paths = [for (final e in entries) '$tenantId/${e.name}'];
      await c.storage.from(_bucket).remove(paths);
    } catch (e, st) {
      debugPrint('PharmacyLogoRepository.clearTenantLogoObjects: $e\n$st');
    }
  }

  /// Uploads bytes to `tenantId/logo_<ts>.<ext>` and returns the **public** URL.
  Future<String> uploadLogo({
    required String tenantId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final c = _client;
    if (c == null) throw StateError('Supabase not configured');

    var ext = fileExtension.replaceAll('.', '').toLowerCase();
    if (ext == 'jpg') ext = 'jpeg';
    if (!const {'png', 'jpeg', 'webp'}.contains(ext)) {
      throw ArgumentError('Logo must be PNG, JPG, or WEBP.');
    }

    await clearTenantLogoObjects(tenantId);

    final path = '$tenantId/logo_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await c.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: _contentTypeForExtension(ext),
        upsert: true,
      ),
    );

    return c.storage.from(_bucket).getPublicUrl(path);
  }
}
