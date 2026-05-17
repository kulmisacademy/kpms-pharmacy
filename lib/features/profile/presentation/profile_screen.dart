import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/kpms_permission_gate.dart';
import '../../../core/auth/permission_providers.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/l10n/kpms_language_picker_sheet.dart';
import '../../../core/supabase/auth_user_helpers.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/errors/kpms_user_facing_error.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_change_password_dialog.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/theme_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../../settings/application/pharmacy_settings_providers.dart';

/// Account hub: language, theme, password, optional links to pharmacy settings / subscription, sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final sessionAsync = ref.watch(pharmacySessionProvider);
    final perm = ref.watch(kpmsPermissionContextProvider).valueOrNull;
    final client = SupabaseBootstrap.clientOrNull;
    final userEmail = client != null ? kpmsAuthUser(client)?.email?.trim() : null;

    return KpmsPageShell(
      title: l.profileTitle,
      subtitle: l.profileSubtitle,
      body: sessionAsync.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '${l.settingsLoadError}\n${kpmsUserFacingMessage(e)}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (session) {
          final tenant = session?.tenant;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              if (perm?.mustChangePassword == true) ...[
                Material(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Set a new password to finish activating your workspace access.',
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.local_pharmacy_rounded, color: theme.colorScheme.primary, size: 36),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tenant?.name ?? l.appTitle,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (userEmail != null && userEmail.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              l.profileAccountLabel,
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600),
                            ),
                            Text(userEmail, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                          if (tenant?.ownerName != null && tenant!.ownerName!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(tenant.ownerName!, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                l.profileSectionPreferences,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.primary),
              ),
              const SizedBox(height: 10),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.language_rounded, color: theme.colorScheme.primary),
                      title: Text(l.profileLanguageOpen),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showKpmsLanguagePickerSheet(context, ref),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.profileThemeTitle, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          SegmentedButton<ThemeMode>(
                            segments: [
                              ButtonSegment(value: ThemeMode.system, label: Text(l.profileThemeSystem)),
                              ButtonSegment(value: ThemeMode.light, label: Text(l.profileThemeLight)),
                              ButtonSegment(value: ThemeMode.dark, label: Text(l.profileThemeDark)),
                            ],
                            selected: {themeMode},
                            onSelectionChanged: (s) {
                              final m = s.first;
                              ref.read(themeModeProvider.notifier).setTheme(m);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.devices_other_rounded, color: theme.colorScheme.primary),
                      title: const Text('Active sessions'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(AppRoutes.profileSessions),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.lock_outline_rounded, color: theme.colorScheme.primary),
                      title: Text(l.profileChangePassword),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showKpmsChangePasswordDialog(context),
                    ),
                  ],
                ),
              ),
              if (perm != null && (perm.isPharmacyAdminTier || perm.features.canAccessRoute(AppRoutes.settings))) ...[
                const SizedBox(height: 22),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(Icons.settings_rounded, color: theme.colorScheme.primary),
                    title: Text(l.profilePharmacySettings),
                    subtitle: Text(l.profilePharmacySettingsSubtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.settings),
                  ),
                ),
              ],
              if (perm != null && (perm.isPharmacyAdminTier || perm.features.canAccessRoute(AppRoutes.subscriptions))) ...[
                const SizedBox(height: 12),
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(Icons.subscriptions_outlined, color: theme.colorScheme.primary),
                    title: Text(l.profileSubscriptionOpen),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push(AppRoutes.subscriptions),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  KpmsPermissionGate.invalidate();
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go(AppRoutes.login);
                },
                icon: const Icon(Icons.logout_rounded),
                label: Text(l.profileLogout),
              ),
            ],
          );
        },
      ),
    );
  }
}
