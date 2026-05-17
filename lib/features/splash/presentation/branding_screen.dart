import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_prefs_keys.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';

/// Full-screen branding / splash — product identity before auth (PRD §5.1, Phase 1).
class BrandingScreen extends StatefulWidget {
  const BrandingScreen({super.key});

  @override
  State<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends State<BrandingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: const Color(0xFF051A3F),
    ));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();

    scheduleMicrotask(() async {
      await Future<void>.delayed(const Duration(milliseconds: 2600));
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool(AppPrefsKeys.onboardingCompleted) ?? false;
      if (!mounted) return;
      context.go(onboardingDone ? AppRoutes.login : AppRoutes.onboarding);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.brandGradient)),
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tertiary.withValues(alpha: 0.18),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(
                      scale: _scale,
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LogoMark(),
                            const SizedBox(height: 28),
                            Text(
                              AppConstants.appName,
                              style: textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pharmacy Management',
                              style: textTheme.titleMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppConstants.tagline,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 3),
                  FadeTransition(
                    opacity: _fade,
                    child: Column(
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppConstants.appFullName,
                          textAlign: TextAlign.center,
                          style: textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.65),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Icon(
        Icons.local_pharmacy_rounded,
        size: 48,
        color: AppColors.primaryDark,
      ),
    );
  }
}
