// ignore_for_file: deprecated_member_use_from_same_package

import 'package:supabase_flutter/supabase_flutter.dart';

/// Prefer [Session.user] — it matches the JWT right after sign-in; [SupabaseClient.auth.currentUser] can lag on web.
User? kpmsAuthUser(SupabaseClient client) {
  final session = client.auth.currentSession;
  if (session != null) return session.user;
  return client.auth.currentUser;
}

String? kpmsAuthUserId(SupabaseClient? client) {
  if (client == null) return null;
  return kpmsAuthUser(client)?.id;
}

/// Matches GoRouter: confirmed email via modern or legacy field.
bool kpmsEmailVerified(User user) {
  if (user.emailConfirmedAt != null) return true;
  // ignore: deprecated_member_use
  return user.confirmedAt != null;
}
