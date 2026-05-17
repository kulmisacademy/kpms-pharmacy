import 'package:flutter/material.dart';

import '../responsive/responsive_helpers.dart';

/// Max width for centered desktop dialogs (forms, confirmations).
const double kpmsDesktopDialogMaxWidth = 700;

/// Centers and constrains dialogs on tablet/desktop; unchanged on mobile.
Future<T?> showKpmsResponsiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  double maxWidth = kpmsDesktopDialogMaxWidth,
}) {
  final tier = responsiveTierOf(context);
  if (tier == ResponsiveTier.mobile) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: builder,
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.92;
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxH),
          child: builder(ctx),
        ),
      );
    },
  );
}

/// Bottom sheet on mobile; centered constrained dialog on tablet/desktop.
Future<T?> showKpmsAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  ShapeBorder? shape,
  double dialogMaxWidth = kpmsDesktopDialogMaxWidth,
}) {
  if (isMobile(context)) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      shape: shape,
      builder: builder,
    );
  }

  return showKpmsResponsiveDialog<T>(
    context: context,
    maxWidth: dialogMaxWidth,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Dialog(
        clipBehavior: Clip.antiAlias,
        shape: shape ??
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
        child: Material(
          color: theme.colorScheme.surface,
          child: builder(ctx),
        ),
      );
    },
  );
}

/// Wraps dialog content with scroll + max height on wide layouts.
class KpmsResponsiveDialogBody extends StatelessWidget {
  const KpmsResponsiveDialogBody({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SingleChildScrollView(child: child),
    );
  }
}
