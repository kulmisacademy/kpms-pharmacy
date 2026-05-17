import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';
import '../../l10n/l10n_context.dart';

/// Shown when no route matches — keeps navigation recoverable.
class KpmsNotFoundScreen extends StatelessWidget {
  const KpmsNotFoundScreen({super.key, required this.attemptedPath});

  final String attemptedPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.travel_explore_outlined, size: 56, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                l.notFoundTitle,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              SelectableText(
                attemptedPath,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutes.home),
                child: Text(l.notFoundGoDashboard),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.login),
                child: Text(l.notFoundSignIn),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
