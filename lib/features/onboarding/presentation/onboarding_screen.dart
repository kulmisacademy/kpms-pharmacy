import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_prefs_keys.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/theme_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_context.dart';

/// First-run onboarding — frosted blur panels + icons; respects light/dark/system.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;

  List<_OnboardPage> _pages(AppLocalizations l) => [
        _OnboardPage(
          icon: Icons.local_pharmacy_rounded,
          title: l.onboardWelcomeTitle(AppConstants.appName),
          subtitle: l.onboardWelcomeSubtitle,
        ),
        _OnboardPage(
          icon: Icons.point_of_sale_rounded,
          title: l.onboardSellTitle,
          subtitle: l.onboardSellSubtitle,
        ),
        _OnboardPage(
          icon: Icons.insights_rounded,
          title: l.onboardAnalyticsTitle,
          subtitle: l.onboardAnalyticsSubtitle,
        ),
        _OnboardPage(
          icon: Icons.dark_mode_rounded,
          title: l.onboardComfortTitle,
          subtitle: l.onboardComfortSubtitle,
        ),
      ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(AppPrefsKeys.onboardingCompleted, true);
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  void _syncChrome() {
    final brightness = Theme.of(context).brightness;
    SystemChrome.setSystemUIOverlayStyle(
      brightness == Brightness.dark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: AppColors.surfaceDark,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: AppColors.surfacePage,
            ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncChrome();
  }

  void _cycleTheme() {
    final mode = ref.read(themeModeProvider);
    final next = switch (mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    ref.read(themeModeProvider.notifier).setTheme(next);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncChrome());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mode = ref.watch(themeModeProvider);
    final l = context.l10n;
    final pages = _pages(l);

    final bgA = isDark ? AppColors.surfaceDark : const Color(0xFFE8F4EC);
    final bgB = isDark ? AppColors.surfaceDarkCard : const Color(0xFFF8FAFC);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  bgA,
                  bgB,
                  AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                ],
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -60,
            child: _GlowBlob(
              color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.2),
              size: 260,
            ),
          ),
          Positioned(
            bottom: -80,
            left: -50,
            child: _GlowBlob(
              color: AppColors.tertiary.withValues(alpha: isDark ? 0.18 : 0.14),
              size: 220,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        l.onboardGetStarted,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: _themeTooltip(l, mode),
                        onPressed: _cycleTheme,
                        icon: Icon(_themeIcon(mode)),
                      ),
                      TextButton(
                        onPressed: _finish,
                        child: Text(l.commonSkip),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: pages.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => _OnboardSlide(page: pages[i], isDark: isDark),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var j = 0; j < pages.length; j++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: j == _index ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: j == _index
                                ? AppColors.primary
                                : theme.colorScheme.outline.withValues(alpha: 0.35),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (_index > 0)
                        OutlinedButton(
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                            );
                          },
                          child: Text(l.commonBack),
                        )
                      else
                        const SizedBox(width: 88),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          if (_index < pages.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                            );
                          } else {
                            _finish();
                          }
                        },
                        child: Text(_index < pages.length - 1 ? l.commonNext : l.commonContinue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _themeIcon(ThemeMode m) => switch (m) {
        ThemeMode.dark => Icons.dark_mode_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.system => Icons.brightness_auto_rounded,
      };

  static String _themeTooltip(AppLocalizations l, ThemeMode m) => switch (m) {
        ThemeMode.dark => l.onboardThemeDark,
        ThemeMode.light => l.onboardThemeLight,
        ThemeMode.system => l.onboardThemeSystem,
      };
}

class _OnboardPage {
  const _OnboardPage({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;
}

class _OnboardSlide extends StatelessWidget {
  const _OnboardSlide({required this.page, required this.isDark});

  final _OnboardPage page;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frost = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.55);
    final border = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.65);

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: frost,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                    ),
                    child: Icon(page.icon, size: 44, color: AppColors.primary),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    page.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    page.subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
