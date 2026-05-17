/// Identifies which **product surface** the user is in. Used for documentation and
/// guards: pharmacy staff never enter [platform]; platform operators never enter [pharmacy]
/// authenticated routes (`/app/*`).
///
/// Routing and [KpmsPermissionContext] enforce separation; Supabase RLS must deny cross-zone
/// data access on the server for production security.
enum KpmsAuthZone {
  /// Tenant pharmacy workspace — mobile-first POS (`/app/*`, [AppRoutes.login]).
  pharmacy,

  /// SaaS control plane — web-style admin (`/super-admin/*`, [AppRoutes.superAdminLogin]).
  platform,
}
