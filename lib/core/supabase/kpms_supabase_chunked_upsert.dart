import 'package:supabase_flutter/supabase_flutter.dart';

import '../performance/kpms_performance_log.dart';

/// Batched PostgREST upserts to stay under payload limits for large tenants.
abstract final class KpmsSupabaseChunkedUpsert {
  KpmsSupabaseChunkedUpsert._();

  static const int defaultChunkSize = 400;

  static Future<int> upsertAll({
    required SupabaseClient client,
    required String table,
    required List<Map<String, dynamic>> rows,
    required String onConflict,
    int chunkSize = defaultChunkSize,
  }) async {
    if (rows.isEmpty) return 0;
    var total = 0;
    for (var i = 0; i < rows.length; i += chunkSize) {
      final end = i + chunkSize > rows.length ? rows.length : i + chunkSize;
      final chunk = rows.sublist(i, end);
      await client.from(table).upsert(chunk, onConflict: onConflict);
      total += chunk.length;
      KpmsPerformanceLog.paginationLoaded(table: '$table@upsert', count: chunk.length, offset: i);
    }
    return total;
  }
}
