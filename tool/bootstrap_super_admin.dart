// Bootstrap a Super Admin: Supabase Auth user + public.profiles (role super_admin).
//
// Required env (never commit service role keys):
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
//   BOOTSTRAP_SUPER_ADMIN_EMAIL    — e.g. you@example.com
//   BOOTSTRAP_SUPER_ADMIN_PASSWORD — exact password (case-sensitive)
//
// Optional:
//   BOOTSTRAP_SUPER_ADMIN_FULL_NAME — default "Super Admin"
//   SUPABASE_ANON_KEY — if set, verifies password grant after profile upsert
//
// PowerShell example:
//   $env:SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
//   $env:SUPABASE_SERVICE_ROLE_KEY="eyJ..."
//   $env:BOOTSTRAP_SUPER_ADMIN_EMAIL="you@example.com"
//   $env:BOOTSTRAP_SUPER_ADMIN_PASSWORD="YourPasswordHere"
//   dart run tool/bootstrap_super_admin.dart
//
// Apply migration `20260515120000_super_admin_role_alias_rls.sql` (supabase db push or SQL Editor).

import 'dart:convert';
import 'dart:io';

/// DB value. App + RLS treat as platform operator.
const String _profileRole = 'super_admin';

Future<void> main() async {
  final baseUrl = _reqEnv('SUPABASE_URL').replaceAll(RegExp(r'/$'), '');
  final serviceKey = _reqEnv('SUPABASE_SERVICE_ROLE_KEY');
  final bootstrapEmail = _reqEnv('BOOTSTRAP_SUPER_ADMIN_EMAIL').toLowerCase();
  final password = _reqEnv('BOOTSTRAP_SUPER_ADMIN_PASSWORD');
  final fullNameRaw = Platform.environment['BOOTSTRAP_SUPER_ADMIN_FULL_NAME']?.trim();
  final fullName = (fullNameRaw != null && fullNameRaw.isNotEmpty) ? fullNameRaw : 'Super Admin';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY']?.trim();

  stdout.writeln('KPMS bootstrap super admin → $bootstrapEmail');

  final client = HttpClient();
  try {
    var userId = await _createOrFindAuthUser(
      client: client,
      baseUrl: baseUrl,
      serviceKey: serviceKey,
      bootstrapEmail: bootstrapEmail,
      fullName: fullName,
      password: password,
    );

    await _upsertProfile(
      client: client,
      baseUrl: baseUrl,
      serviceKey: serviceKey,
      userId: userId,
      bootstrapEmail: bootstrapEmail,
      fullName: fullName,
    );

    userId = await _verifyProfile(
      client: client,
      baseUrl: baseUrl,
      serviceKey: serviceKey,
      userId: userId,
    );

    if (anonKey != null && anonKey.isNotEmpty) {
      await _verifyPasswordLogin(
        client: client,
        baseUrl: baseUrl,
        anonKey: anonKey,
        bootstrapEmail: bootstrapEmail,
        password: password,
      );
    } else {
      stdout.writeln('Skip password login check (set SUPABASE_ANON_KEY to enable).');
    }
  } finally {
    client.close(force: true);
  }

  stdout.writeln('');
  stdout.writeln('Done.');
  stdout.writeln('- Super Admin login: /super-admin/login');
  stdout.writeln('- After sign-in, app routes to /super-admin');
  stdout.writeln('- Pharmacy staff use /login only.');
}

String _reqEnv(String name) {
  final v = Platform.environment[name]?.trim();
  if (v == null || v.isEmpty) {
    stderr.writeln('Missing required environment variable: $name');
    exitCode = 1;
    exit(1);
  }
  return v;
}

Future<String> _readBody(HttpClientResponse res) async {
  final chunks = <int>[];
  await for (final chunk in res) {
    chunks.addAll(chunk);
  }
  return utf8.decode(chunks);
}

Future<String> _createOrFindAuthUser({
  required HttpClient client,
  required String baseUrl,
  required String serviceKey,
  required String bootstrapEmail,
  required String fullName,
  required String password,
}) async {
  final uri = Uri.parse('$baseUrl/auth/v1/admin/users');
  final createBody = jsonEncode({
    'email': bootstrapEmail,
    'password': password,
    'email_confirm': true,
    'user_metadata': {'full_name': fullName},
  });

  final req = await client.postUrl(uri);
  req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
  req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $serviceKey');
  req.headers.set('apikey', serviceKey);
  req.write(createBody);
  final createRes = await req.close();

  final createText = await _readBody(createRes);
  final createJson = createText.isEmpty ? <String, dynamic>{} : jsonDecode(createText) as Map<String, dynamic>;

  if (createRes.statusCode == 200 || createRes.statusCode == 201) {
    final id = createJson['user']?['id'] ?? createJson['id'];
    if (id is! String) {
      stderr.writeln('Unexpected create user response: $createText');
      exit(1);
    }
    stdout.writeln('Created auth user: $id');
    return id;
  }

  if (createRes.statusCode == 409 ||
      createRes.statusCode == 422 ||
      (createJson['message']?.toString().toLowerCase().contains('already') ?? false)) {
    stdout.writeln('Auth user already exists — looking up id…');
    final id = await _findUserIdByEmail(
      client: client,
      baseUrl: baseUrl,
      serviceKey: serviceKey,
      bootstrapEmail: bootstrapEmail,
    );
    await _updateAuthUserPassword(
      client: client,
      baseUrl: baseUrl,
      serviceKey: serviceKey,
      userId: id,
      fullName: fullName,
      password: password,
    );
    stdout.writeln('Updated password + email_confirm for existing user: $id');
    return id;
  }

  stderr.writeln('Create user failed (${createRes.statusCode}): $createText');
  exit(1);
}

Future<String> _findUserIdByEmail({
  required HttpClient client,
  required String baseUrl,
  required String serviceKey,
  required String bootstrapEmail,
}) async {
  var page = 1;
  const perPage = 1000;
  while (true) {
    final uri = Uri.parse('$baseUrl/auth/v1/admin/users?page=$page&per_page=$perPage');
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $serviceKey');
    req.headers.set('apikey', serviceKey);
    final res = await req.close();
    final body = await _readBody(res);
    if (res.statusCode != 200) {
      stderr.writeln('List users failed (${res.statusCode}): $body');
      exit(1);
    }
    final map = jsonDecode(body) as Map<String, dynamic>;
    final users = map['users'] as List<dynamic>? ?? const [];
    for (final u in users) {
      if (u is! Map<String, dynamic>) continue;
      final email = (u['email'] as String?)?.toLowerCase().trim();
      if (email == bootstrapEmail.toLowerCase()) {
        return u['id'] as String;
      }
    }
    if (users.length < perPage) break;
    page++;
  }
  stderr.writeln('Could not find existing auth user for $bootstrapEmail');
  exit(1);
}

Future<void> _updateAuthUserPassword({
  required HttpClient client,
  required String baseUrl,
  required String serviceKey,
  required String userId,
  required String fullName,
  required String password,
}) async {
  final uri = Uri.parse('$baseUrl/auth/v1/admin/users/$userId');
  final body = jsonEncode({
    'password': password,
    'email_confirm': true,
    'user_metadata': {'full_name': fullName},
  });
  final req = await client.putUrl(uri);
  req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
  req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $serviceKey');
  req.headers.set('apikey', serviceKey);
  req.write(body);
  final res = await req.close();
  final text = await _readBody(res);
  if (res.statusCode != 200) {
    stderr.writeln('Update user failed (${res.statusCode}): $text');
    exit(1);
  }
}

Future<void> _upsertProfile({
  required HttpClient client,
  required String baseUrl,
  required String serviceKey,
  required String userId,
  required String bootstrapEmail,
  required String fullName,
}) async {
  final uri = Uri.parse('$baseUrl/rest/v1/profiles?id=eq.${Uri.encodeComponent(userId)}');
  final patchBody = jsonEncode({
    'role': _profileRole,
    'full_name': fullName,
    'account_email': bootstrapEmail.toLowerCase(),
    'staff_status': 'active',
    'tenant_id': null,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });

  final patchReq = await client.openUrl('PATCH', uri);
  patchReq.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
  patchReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $serviceKey');
  patchReq.headers.set('apikey', serviceKey);
  patchReq.headers.set('Prefer', 'return=representation');
  patchReq.write(patchBody);
  final patchRes = await patchReq.close();
  final patchText = await _readBody(patchRes);

  if (patchRes.statusCode == 200) {
    final list = jsonDecode(patchText) as List<dynamic>;
    if (list.isNotEmpty) {
      stdout.writeln('Updated profiles row (PATCH).');
      return;
    }
  }

  if (patchRes.statusCode == 200 || patchRes.statusCode == 204) {
    stdout.writeln('PATCH returned no rows — inserting profile…');
  } else {
    stdout.writeln('PATCH status ${patchRes.statusCode} — attempting insert… ($patchText)');
  }

  final insertUri = Uri.parse('$baseUrl/rest/v1/profiles');
  final insertBody = jsonEncode({
    'id': userId,
    'role': _profileRole,
    'full_name': fullName,
    'account_email': bootstrapEmail.toLowerCase(),
    'staff_status': 'active',
    'tenant_id': null,
  });
  final insReq = await client.postUrl(insertUri);
  insReq.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
  insReq.headers.set(HttpHeaders.authorizationHeader, 'Bearer $serviceKey');
  insReq.headers.set('apikey', serviceKey);
  insReq.headers.set('Prefer', 'return=representation');
  insReq.write(insertBody);
  final insRes = await insReq.close();
  final insText = await _readBody(insRes);
  if (insRes.statusCode != 200 && insRes.statusCode != 201) {
    stderr.writeln('Insert profile failed (${insRes.statusCode}): $insText');
    exit(1);
  }
  stdout.writeln('Inserted profiles row.');
}

Future<String> _verifyProfile({
  required HttpClient client,
  required String baseUrl,
  required String serviceKey,
  required String userId,
}) async {
  final uri = Uri.parse(
    '$baseUrl/rest/v1/profiles?select=id,role,full_name,account_email,staff_status,tenant_id&id=eq.${Uri.encodeComponent(userId)}',
  );
  final req = await client.getUrl(uri);
  req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $serviceKey');
  req.headers.set('apikey', serviceKey);
  final res = await req.close();
  final text = await _readBody(res);
  if (res.statusCode != 200) {
    stderr.writeln('Verify profile failed (${res.statusCode}): $text');
    exit(1);
  }
  final rows = jsonDecode(text) as List<dynamic>;
  if (rows.isEmpty) {
    stderr.writeln('Profile row missing after upsert.');
    exit(1);
  }
  final row = rows.first as Map<String, dynamic>;
  stdout.writeln('Verify profile: ${jsonEncode(row)}');
  final role = (row['role'] as String?)?.toLowerCase();
  if (role != _profileRole) {
    stderr.writeln('Expected role $_profileRole, got $role');
    exit(1);
  }
  stdout.writeln('Role OK ($_profileRole → app treats as platform super admin).');
  return row['id'] as String;
}

Future<void> _verifyPasswordLogin({
  required HttpClient client,
  required String baseUrl,
  required String anonKey,
  required String bootstrapEmail,
  required String password,
}) async {
  final uri = Uri.parse('$baseUrl/auth/v1/token?grant_type=password');
  final body = jsonEncode({'email': bootstrapEmail, 'password': password});
  final req = await client.postUrl(uri);
  req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
  req.headers.set('apikey', anonKey);
  req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $anonKey');
  req.write(body);
  final res = await req.close();
  final text = await _readBody(res);
  if (res.statusCode != 200) {
    stderr.writeln('Password grant failed (${res.statusCode}): $text');
    exit(1);
  }
  final map = jsonDecode(text) as Map<String, dynamic>;
  if (map['access_token'] == null) {
    stderr.writeln('No access_token in token response.');
    exit(1);
  }
  stdout.writeln('Password grant OK (auth.signInWithPassword would succeed).');
}
