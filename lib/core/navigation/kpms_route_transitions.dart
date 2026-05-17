import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Smooth enter/exit for stack navigation (PRD: polished UX).
/// Web uses a shorter fade-only transition for snappier ERP navigation.
CustomTransitionPage<void> kpmsSlideFadePage(GoRouterState state, Widget child) {
  final webFast = kIsWeb;
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration(milliseconds: webFast ? 140 : 300),
    reverseTransitionDuration: Duration(milliseconds: webFast ? 110 : 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut, reverseCurve: Curves.easeIn);
      if (webFast) {
        return FadeTransition(opacity: fade, child: child);
      }
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Softer transition for auth flows.
CustomTransitionPage<void> kpmsFadePage(GoRouterState state, Widget child) {
  final webFast = kIsWeb;
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Duration(milliseconds: webFast ? 120 : 280),
    reverseTransitionDuration: Duration(milliseconds: webFast ? 100 : 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        child: child,
      );
    },
  );
}
