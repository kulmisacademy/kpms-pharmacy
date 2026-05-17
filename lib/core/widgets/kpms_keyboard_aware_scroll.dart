import 'package:flutter/material.dart';

/// Scroll wrapper that keeps focused fields and actions above the software keyboard.
class KpmsKeyboardAwareScroll extends StatelessWidget {
  const KpmsKeyboardAwareScroll({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.only(bottom: 24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: padding.add(EdgeInsets.only(bottom: inset)),
      child: child,
    );
  }
}

/// Bottom-sheet padding: safe area + keyboard inset (does not replace [viewInsets]).
EdgeInsets kpmsSheetScrollPadding(BuildContext context, {double horizontal = 20, double top = 8}) {
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    MediaQuery.paddingOf(context).bottom + MediaQuery.viewInsetsOf(context).bottom + 20,
  );
}
