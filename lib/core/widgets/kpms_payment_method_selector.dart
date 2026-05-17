import 'package:flutter/material.dart';

import '../constants/kpms_payment_methods.dart';
import '../theme/app_colors.dart';

/// Selectable grid of POS payment channels — shared by checkout & purchases.
class KpmsPaymentMethodSelector extends StatelessWidget {
  const KpmsPaymentMethodSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  static const Map<String, IconData> icons = {
    'Cash': Icons.payments_outlined,
    'EVC Plus': Icons.phone_android_rounded,
    'E-Dahab': Icons.account_balance_wallet_outlined,
    'Jeeb': Icons.qr_code_2_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final methods = KpmsPosPaymentMethods.all;
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in methods)
              SizedBox(
                width: w.clamp(120.0, 200.0),
                child: KpmsPaymentMethodChip(
                  label: m,
                  icon: icons[m] ?? Icons.payment_rounded,
                  selected: selected == m,
                  onTap: () => onSelected(m),
                ),
              ),
          ],
        );
      },
    );
  }
}

class KpmsPaymentMethodChip extends StatelessWidget {
  const KpmsPaymentMethodChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected ? primary : theme.colorScheme.outline.withValues(alpha: 0.22),
            ),
            color: selected
                ? primary.withValues(alpha: 0.1)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? primary : theme.hintColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected ? primary : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_circle_rounded, size: 18, color: primary),
            ],
          ),
        ),
      ),
    );
  }
}
