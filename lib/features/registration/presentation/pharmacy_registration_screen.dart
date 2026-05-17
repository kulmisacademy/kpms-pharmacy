import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/kpms_password_policy.dart';
import '../../../core/auth/permission_providers.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/registration/kpms_registration_log.dart';
import '../../../core/supabase/auth_user_helpers.dart';
import '../../../core/supabase/profile_tenant_gate.dart';
import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../routes/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../settings/application/pharmacy_settings_providers.dart';
import '../data/kpms_countries_regions.dart';

/// Pharmacy onboarding: tenant + owner account, then workspace home.
class PharmacyRegistrationScreen extends ConsumerStatefulWidget {
  const PharmacyRegistrationScreen({super.key});

  @override
  ConsumerState<PharmacyRegistrationScreen> createState() => _PharmacyRegistrationScreenState();
}

class _PharmacyRegistrationScreenState extends ConsumerState<PharmacyRegistrationScreen> {
  final _name = TextEditingController();
  final _owner = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _district = TextEditingController();
  final _license = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  String? _country;
  String? _somaliaRegion;
  bool _busy = false;
  Uint8List? _pendingLogoBytes;
  String _pendingLogoExt = 'png';
  bool _logoPicking = false;
  bool _showManualContinue = false;

  void _navigateBackOrLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  void _cancelBusyAndLeaveRegistration() {
    if (_busy) {
      KpmsRegistrationLog.backPressedWhileBusy();
      setState(() => _busy = false);
    }
    _navigateBackOrLogin();
  }

  /// Polls / listens for Supabase session — critical on mobile APK where JWT persistence lags signUp.
  Future<Session?> _waitForAuthSession(
    SupabaseClient client, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    var session = client.auth.currentSession;
    if (session != null) return session;

    final completer = Completer<Session?>();
    late final StreamSubscription<AuthState> sub;
    sub = client.auth.onAuthStateChange.listen((state) {
      final s = state.session;
      if (s != null && !completer.isCompleted) completer.complete(s);
    });

    try {
      session = await completer.future.timeout(
        timeout,
        onTimeout: () => client.auth.currentSession,
      );
    } finally {
      await sub.cancel();
    }
    return session ?? client.auth.currentSession;
  }

  void _resetBusyIfMounted() {
    if (!mounted) return;
    if (_busy) setState(() => _busy = false);
    KpmsRegistrationLog.loadingReset();
  }

  Future<void> _navigateToHomeAfterRegistration(String uid) async {
    if (!mounted) return;
    final sideEffectContainer = ProviderScope.containerOf(context, listen: false);
    ProfileTenantGate.markTenantLinked(uid, tenantId: ProfileTenantGate.cachedTenantId(uid));
    KpmsRegistrationLog.tenantLinked();
    _resetBusyIfMounted();
    KpmsRegistrationLog.redirectStarted();

    void goHome() {
      if (!mounted) return;
      GoRouter.of(context).go(AppRoutes.home);
    }

    var navigated = false;
    try {
      goHome();
      navigated = true;
      KpmsRegistrationLog.redirectCompleted();
    } catch (e, st) {
      KpmsRegistrationLog.redirectFallback(e);
      debugPrint('[kpms.registration] go_router primary failed: $e\n$st');
    }

    if (!navigated) {
      try {
        ref.read(appRouterProvider).go(AppRoutes.home);
        navigated = true;
        KpmsRegistrationLog.redirectCompleted();
      } catch (e, st) {
        KpmsRegistrationLog.redirectFallback(e);
        debugPrint('[kpms.registration] go_router provider fallback failed: $e\n$st');
      }
    }

    if (!navigated && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          GoRouter.of(context).go(AppRoutes.home);
          KpmsRegistrationLog.redirectCompleted();
        } catch (e) {
          KpmsRegistrationLog.redirectFallback(e);
          if (mounted) setState(() => _showManualContinue = true);
        }
      });
    }

    _schedulePostRegistrationSideEffects(sideEffectContainer);
    _scheduleNavigationWatchdog();
  }

  void _schedulePostRegistrationSideEffects([ProviderContainer? container]) {
    final scoped =
        container ?? (mounted ? ProviderScope.containerOf(context, listen: false) : null);
    if (scoped == null) return;
    KpmsRegistrationLog.sessionReloadScheduled();
    scheduleMicrotask(() async {
      try {
        scoped.invalidate(kpmsPermissionContextProvider);
        await scoped
            .read(pharmacySessionProvider.notifier)
            .reload()
            .timeout(const Duration(seconds: 25));
        KpmsRegistrationLog.sessionReloadDone();
      } catch (e, st) {
        KpmsRegistrationLog.sessionReloadFailed(e);
        debugPrint('[kpms.registration] session_reload stack: $st');
      }
      try {
        await _applyPendingLogoWithContainer(scoped).timeout(const Duration(seconds: 30));
      } catch (e) {
        KpmsRegistrationLog.logoDeferredSkipped(e);
      }
    });
  }

  Future<void> _applyPendingLogoWithContainer(ProviderContainer container) async {
    final bytes = _pendingLogoBytes;
    if (bytes == null || bytes.isEmpty) return;
    final logoRepo = container.read(pharmacyLogoRepositoryProvider);
    final settingsRepo = container.read(pharmacySettingsRepositoryProvider);
    try {
      final loaded = await settingsRepo.loadMyPharmacy();
      if (loaded == null) return;
      final tid = loaded.tenant.id;
      final url = await logoRepo.uploadLogo(
        tenantId: tid,
        bytes: bytes,
        fileExtension: _pendingLogoExt,
      );
      final m = Map<String, dynamic>.from(loaded.tenant.settingsJson);
      m['logo_url'] = url;
      await settingsRepo.updateTenant(
        tenantId: tid,
        name: loaded.tenant.name,
        address: loaded.tenant.address,
        phone: loaded.tenant.phone,
        licenseNumber: loaded.tenant.licenseNumber,
        ownerName: loaded.tenant.ownerName,
        settings: m,
      );
    } catch (e, st) {
      debugPrint('Registration logo upload failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _owner.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _district.dispose();
    _license.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  String _buildAddressForRpc() {
    if (kpmsIsSomaliaCountry(_country)) {
      final r = (_somaliaRegion ?? '').trim();
      final d = _district.text.trim();
      if (r.isEmpty && d.isEmpty) return kpmsSomaliaCountryName;
      if (d.isEmpty) return '$r, $kpmsSomaliaCountryName';
      if (r.isEmpty) return '$d, $kpmsSomaliaCountryName';
      return '$r, $d, $kpmsSomaliaCountryName';
    }
    final a = _address.text.trim();
    final c = (_country ?? '').trim();
    final parts = <String>[];
    if (a.isNotEmpty) parts.add(a);
    if (c.isNotEmpty) parts.add(c);
    if (parts.isEmpty) return '—';
    return parts.join(' · ');
  }

  Future<void> _pickCountry() async {
    var filter = '';
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final qq = filter.trim().toLowerCase();
            final list = kpmsRegistrationCountries
                .where((c) => qq.isEmpty || c.toLowerCase().contains(qq))
                .take(100)
                .toList();
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: SizedBox(
                height: MediaQuery.sizeOf(ctx).height * 0.58,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: Text(
                        'Select country',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search countries',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                        onChanged: (v) => setModal(() => filter = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final c = list[i];
                          return ListTile(
                            title: Text(c),
                            onTap: () => Navigator.pop(ctx, c),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _country = picked;
        if (!kpmsIsSomaliaCountry(picked)) {
          _somaliaRegion = null;
          _district.clear();
        }
      });
    }
  }

  Future<void> _pickSomaliaRegion() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'Select region',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              for (final r in kpmsSomaliaRegions)
                ListTile(
                  title: Text(r),
                  trailing: _somaliaRegion == r ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(ctx, r),
                ),
            ],
          ),
        );
      },
    );
    if (picked != null && mounted) setState(() => _somaliaRegion = picked);
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(authRepositoryProvider);
    final name = _name.text.trim();
    final owner = _owner.text.trim();
    final email = _email.text.trim();
    final phone = _phone.text.trim();

    if (name.isEmpty) {
      kpmsSnack(context, l.registerNameRequired, isError: true);
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      kpmsSnack(context, l.validationEmailInvalid, isError: true);
      return;
    }
    if (owner.isEmpty) {
      kpmsSnack(context, l.registerOwnerRequired, isError: true);
      return;
    }
    if (phone.isEmpty) {
      kpmsSnack(context, l.registerPhoneRequired, isError: true);
      return;
    }
    if ((_country ?? '').trim().isEmpty) {
      kpmsSnack(context, 'Please select a country.', isError: true);
      return;
    }
    if (kpmsIsSomaliaCountry(_country)) {
      if ((_somaliaRegion ?? '').trim().isEmpty) {
        kpmsSnack(context, 'Please select a region.', isError: true);
        return;
      }
      if (_district.text.trim().isEmpty) {
        kpmsSnack(context, 'Please enter a district.', isError: true);
        return;
      }
    }

    final pw = _password.text;
    if (!KpmsPasswordPolicy.meetsPharmacySignupRules(pw)) {
      kpmsSnack(context, l.validationPasswordSignupRules, isError: true);
      return;
    }
    if (pw != _passwordConfirm.text) {
      kpmsSnack(context, l.validationPasswordMismatch, isError: true);
      return;
    }

    setState(() {
      _busy = true;
      _showManualContinue = false;
    });
    KpmsRegistrationLog.registrationStarted();
    try {
      await _runPharmacyRegistration(email: email, password: pw, owner: owner, repo: repo, l: l).timeout(
        const Duration(seconds: 20),
      );
    } on TimeoutException {
      KpmsRegistrationLog.registrationTimeout();
      if (mounted) {
        setState(() => _showManualContinue = true);
        kpmsSnack(
          context,
          'Registration is taking longer than expected. Tap "Go to Dashboard" or try again.',
          isError: true,
        );
      }
    } on AuthException catch (e) {
      if (repo.isDuplicateSignupError(e)) {
        await _signInExistingAndFinishPharmacy(repo);
        return;
      }
      if (mounted) kpmsSnackError(context, e);
    } catch (e) {
      if (mounted) kpmsSnackError(context, e, fallback: l.registerGenericError);
    } finally {
      _resetBusyIfMounted();
    }
  }

  Future<void> _runPharmacyRegistration({
    required String email,
    required String password,
    required String owner,
    required AuthRepository repo,
    required AppLocalizations l,
  }) async {
    final res = await repo.signUpWithEmail(
      email: email,
      password: password,
      fullName: owner,
    );
    if (!mounted) return;

    final clientAfter = SupabaseBootstrap.clientOrNull;
    if (clientAfter == null) {
      if (mounted) kpmsSnack(context, l.registerSessionMissing, isError: true);
      return;
    }

    if (kIsWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    var session = res.session ?? clientAfter.auth.currentSession;
    session ??= await _waitForAuthSession(clientAfter);

    KpmsRegistrationLog.authCreated(hasSession: session != null);
    if (session == null) {
      if (!mounted) return;
      context.go('${AppRoutes.verifyEmail}?email=${Uri.encodeComponent(email)}');
      return;
    }

    KpmsRegistrationLog.sessionConfirmed();
    await _finishPharmacyRegistration(repo, isNewSignup: true);
  }

  Future<void> _finishPharmacyRegistration(
    AuthRepository repo, {
    required bool isNewSignup,
  }) async {
    final l = AppLocalizations.of(context);
    final client = SupabaseBootstrap.clientOrNull;
    final uid = kpmsAuthUserId(client) ?? repo.currentUser?.id;

    if (client == null || uid == null) {
      if (mounted) kpmsSnack(context, l.registerSessionMissing, isError: true);
      return;
    }

    if (mounted) setState(() => _showManualContinue = false);

    if (!isNewSignup) {
      late final bool has;
      try {
        has = await ProfileTenantGate.hasTenantLinked(client, uid).timeout(const Duration(seconds: 8));
      } on TimeoutException {
        KpmsRegistrationLog.tenantLinkCheckTimeout();
        if (mounted) {
          setState(() => _showManualContinue = true);
          kpmsSnack(
            context,
            'Could not confirm your pharmacy link in time. Tap "Go to Dashboard" below.',
            isError: true,
          );
        }
        return;
      }

      KpmsRegistrationLog.tenantConfirmed(hasTenant: has);
      if (has) {
        if (!mounted) return;
        await _navigateToHomeAfterRegistration(uid);
        return;
      }
    }

    try {
      await repo
          .registerPharmacyTenant(
            name: _name.text.trim(),
            address: _buildAddressForRpc(),
            phone: _phone.text.trim(),
            license: _license.text.trim(),
            owner: _owner.text.trim(),
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      KpmsRegistrationLog.rpcTimeout();
      ProfileTenantGate.markTenantLinked(uid, tenantId: ProfileTenantGate.cachedTenantId(uid));
      if (mounted) {
        setState(() => _showManualContinue = true);
        kpmsSnack(
          context,
          'Pharmacy setup is still finishing. Tap "Go to Dashboard" to continue.',
          isError: true,
        );
      }
      return;
    } catch (e) {
      if (mounted) kpmsSnackError(context, e, fallback: l.registerGenericError);
      return;
    }

    KpmsRegistrationLog.tenantCreated();
    if (!mounted) return;
    await _navigateToHomeAfterRegistration(uid);
  }

  void _scheduleNavigationWatchdog() {
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      setState(() => _showManualContinue = true);
    });
  }

  Future<void> _pickRegistrationLogo(ImageSource source) async {
    if (_busy || _logoPicking) return;
    final l = AppLocalizations.of(context);
    final picker = ImagePicker();
    setState(() => _logoPicking = true);
    try {
      final x = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (x == null || !mounted) return;
      final bytes = await x.readAsBytes();
      var ext = 'png';
      final path = x.path;
      if (path.contains('.')) {
        ext = path.split('.').last.toLowerCase();
      }
      if (ext == 'jpg') ext = 'jpeg';
      if (!const {'png', 'jpeg', 'webp'}.contains(ext)) {
        if (mounted) kpmsSnack(context, l.registerLogoInvalidFormat, isError: true);
        return;
      }
      setState(() {
        _pendingLogoBytes = bytes;
        _pendingLogoExt = ext;
      });
    } catch (e) {
      if (mounted) kpmsSnackError(context, e);
    } finally {
      if (mounted) setState(() => _logoPicking = false);
    }
  }

  Future<void> _signInExistingAndFinishPharmacy(AuthRepository repo) async {
    final l = AppLocalizations.of(context);
    final email = _email.text.trim();
    final pw = _password.text;
    try {
      final res = await repo.signInWithEmail(email: email, password: pw);
      if (!mounted) return;
      final c = SupabaseBootstrap.clientOrNull;
      if (kIsWeb && c != null) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      if (!mounted) return;
      final c2 = SupabaseBootstrap.clientOrNull;
      var sessionOk = res.session ?? c2?.auth.currentSession;
      if (sessionOk == null && c2 != null) {
        sessionOk = await _waitForAuthSession(c2);
      }
      if (sessionOk == null) {
        if (!mounted) return;
        kpmsSnack(context, l.registerVerifyEmailFirst, isError: true);
        return;
      }
      KpmsRegistrationLog.sessionConfirmed();
      await _finishPharmacyRegistration(repo, isNewSignup: false);
    } on AuthException catch (_) {
      if (mounted) kpmsSnack(context, l.registerDuplicateHelp, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.brandGradient)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: _busy ? _cancelBusyAndLeaveRegistration : _navigateBackOrLogin,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.registerPharmacyTitle,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.registerPharmacySubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, height: 1.35),
                      ),
                      const SizedBox(height: 24),
                      GlassCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _name,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l.registerFieldPharmacyName,
                                prefixIcon: const Icon(Icons.local_pharmacy_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _owner,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l.registerFieldOwnerName,
                                prefixIcon: const Icon(Icons.person_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l.commonEmail,
                                prefixIcon: const Icon(Icons.mail_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l.registerFieldPhone,
                                prefixIcon: const Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Material(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: _busy ? null : _pickCountry,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                  child: Row(
                                    children: [
                                      Icon(Icons.public_rounded, color: theme.colorScheme.primary),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          (_country ?? '').isEmpty ? 'Country *' : _country!,
                                          style: theme.textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: (_country ?? '').isEmpty
                                                ? theme.hintColor
                                                : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.arrow_drop_down_rounded, color: theme.hintColor),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (kpmsIsSomaliaCountry(_country)) ...[
                              const SizedBox(height: 12),
                              Material(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: _busy ? null : _pickSomaliaRegion,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.map_outlined),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            (_somaliaRegion ?? '').isEmpty ? 'Region / gobol *' : _somaliaRegion!,
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: (_somaliaRegion ?? '').isEmpty
                                                  ? theme.hintColor
                                                  : theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        Icon(Icons.arrow_drop_down_rounded, color: theme.hintColor),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _district,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'District *',
                                  hintText: 'e.g. Hodan, Beledweyne, Garowe',
                                  prefixIcon: Icon(Icons.location_city_outlined),
                                ),
                              ),
                            ],
                            if (!kpmsIsSomaliaCountry(_country) && (_country ?? '').isNotEmpty) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: _address,
                                maxLines: 2,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: l.registerFieldAddressOptional,
                                  prefixIcon: const Icon(Icons.place_outlined),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            TextField(
                              controller: _password,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l.authPasswordLabel,
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                helperText: l.validationPasswordSignupRules,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordConfirm,
                              obscureText: true,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: l.changePasswordConfirm,
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _license,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: l.registerFieldLicenseOptional,
                                helperText: l.registerLicenseHelper,
                                prefixIcon: const Icon(Icons.badge_outlined),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l.registerLogoButton,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l.registerLogoSubtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 140, maxHeight: 88),
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                                  alignment: Alignment.center,
                                  child: _pendingLogoBytes != null
                                      ? Image.memory(
                                          _pendingLogoBytes!,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.medium,
                                        )
                                      : Icon(
                                          Icons.local_pharmacy_rounded,
                                          size: 40,
                                          color: theme.colorScheme.primary,
                                        ),
                                ),
                              ),
                            ),
                            if (_logoPicking) ...[
                              const SizedBox(height: 10),
                              const LinearProgressIndicator(minHeight: 2),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: (_busy || _logoPicking)
                                        ? null
                                        : () => _pickRegistrationLogo(ImageSource.gallery),
                                    icon: const Icon(Icons.photo_library_outlined, size: 20),
                                    label: Text(l.registerLogoGallery),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: (_busy || _logoPicking)
                                        ? null
                                        : () => _pickRegistrationLogo(ImageSource.camera),
                                    icon: const Icon(Icons.photo_camera_outlined, size: 20),
                                    label: Text(l.registerLogoCamera),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: (_busy || _logoPicking || _pendingLogoBytes == null)
                                  ? null
                                  : () => setState(() => _pendingLogoBytes = null),
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              label: Text(l.registerLogoRemove),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                              child: _busy
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Text(l.registerSubmitCta),
                            ),
                            if (_showManualContinue) ...[
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () {
                                  final client = SupabaseBootstrap.clientOrNull;
                                  final uid = kpmsAuthUserId(client);
                                  if (uid == null) return;
                                  setState(() => _showManualContinue = false);
                                  _navigateToHomeAfterRegistration(uid);
                                },
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('Go to Dashboard'),
                              ),
                            ],
                            TextButton(
                              onPressed: () {
                                if (_busy) {
                                  KpmsRegistrationLog.backPressedWhileBusy();
                                  setState(() => _busy = false);
                                }
                                context.go(AppRoutes.login);
                              },
                              child: Text(l.authVerifyBackSignIn),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
