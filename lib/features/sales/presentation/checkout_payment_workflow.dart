import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/kpms_payment_methods.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_payment_method_selector.dart';
import '../domain/sale_settlement.dart';

/// Premium POS payment & credit flow — status first, then methods, then customer (credit only).
class CheckoutPaymentWorkflow extends StatelessWidget {
  const CheckoutPaymentWorkflow({
    super.key,
    required this.settlement,
    required this.onSettlementChanged,
    required this.grandTotal,
    required this.collectedController,
    required this.onCollectedChanged,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
    required this.customerNameController,
    required this.customerPhoneController,
    required this.customerNotesController,
    required this.onPickCustomer,
  });

  final SaleSettlementMode settlement;
  final ValueChanged<SaleSettlementMode> onSettlementChanged;
  final double grandTotal;
  final TextEditingController collectedController;
  final VoidCallback onCollectedChanged;
  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;

  final TextEditingController customerNameController;
  final TextEditingController customerPhoneController;
  final TextEditingController customerNotesController;
  final VoidCallback onPickCustomer;

  static List<String> get paymentMethods => KpmsPosPaymentMethods.all;

  double get _collected => double.tryParse(collectedController.text.trim()) ?? 0;

  double _paidDisplay() {
    return switch (settlement) {
      SaleSettlementMode.paidInFull => grandTotal,
      SaleSettlementMode.partialDebt => _collected.clamp(0.0, grandTotal),
      SaleSettlementMode.fullDebt => 0,
    };
  }

  double _remainingDisplay() {
    return (grandTotal - _paidDisplay()).clamp(0.0, double.infinity);
  }

  String _statusLabel() {
    return switch (settlement) {
      SaleSettlementMode.paidInFull => 'Paid',
      SaleSettlementMode.partialDebt => 'Partial payment',
      SaleSettlementMode.fullDebt => 'Credit',
    };
  }

  String _methodLabel() {
    return switch (settlement) {
      SaleSettlementMode.fullDebt => '—',
      _ => paymentMethod,
    };
  }

  double _changeDue() {
    if (settlement != SaleSettlementMode.paidInFull) return 0;
    return (_collected - grandTotal);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline.withValues(alpha: 0.2);
    final showCustomer = settlement != SaleSettlementMode.paidInFull;

    return GlassCard(
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Payment',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.2),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how this sale is settled, then payment channel.',
            style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, height: 1.35),
          ),
          const SizedBox(height: 14),
          Text(
            'PAYMENT STATUS',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
              color: theme.hintColor,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 340;
              if (narrow) {
                return Column(
                  children: [
                    _StatusOptionCard(
                      selected: settlement == SaleSettlementMode.paidInFull,
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Paid',
                      subtitle: 'Full amount now',
                      onTap: () => onSettlementChanged(SaleSettlementMode.paidInFull),
                    ),
                    const SizedBox(height: 8),
                    _StatusOptionCard(
                      selected: settlement == SaleSettlementMode.partialDebt,
                      icon: Icons.call_split_rounded,
                      title: 'Partial',
                      subtitle: 'Pay part · rest on credit',
                      onTap: () => onSettlementChanged(SaleSettlementMode.partialDebt),
                    ),
                    const SizedBox(height: 8),
                    _StatusOptionCard(
                      selected: settlement == SaleSettlementMode.fullDebt,
                      icon: Icons.receipt_long_outlined,
                      title: 'Credit',
                      subtitle: 'Full invoice on account',
                      onTap: () => onSettlementChanged(SaleSettlementMode.fullDebt),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _StatusOptionCard(
                      selected: settlement == SaleSettlementMode.paidInFull,
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Paid',
                      subtitle: 'Full amount',
                      compact: true,
                      onTap: () => onSettlementChanged(SaleSettlementMode.paidInFull),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusOptionCard(
                      selected: settlement == SaleSettlementMode.partialDebt,
                      icon: Icons.call_split_rounded,
                      title: 'Partial',
                      subtitle: 'Split pay',
                      compact: true,
                      onTap: () => onSettlementChanged(SaleSettlementMode.partialDebt),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusOptionCard(
                      selected: settlement == SaleSettlementMode.fullDebt,
                      icon: Icons.receipt_long_outlined,
                      title: 'Credit',
                      subtitle: 'All on account',
                      compact: true,
                      onTap: () => onSettlementChanged(SaleSettlementMode.fullDebt),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: outline),
            ),
            child: Column(
              children: [
                _SummaryLine(theme, 'Invoice total', '\$${grandTotal.toStringAsFixed(2)}', strong: true),
                const SizedBox(height: 8),
                _SummaryLine(theme, 'Paid amount', '\$${_paidDisplay().toStringAsFixed(2)}'),
                const SizedBox(height: 8),
                _SummaryLine(
                  theme,
                  'Remaining balance',
                  '\$${_remainingDisplay().toStringAsFixed(2)}',
                  warn: _remainingDisplay() > 0.009,
                ),
                const SizedBox(height: 8),
                _SummaryLine(theme, 'Payment status', _statusLabel()),
                const SizedBox(height: 8),
                _SummaryLine(theme, 'Payment method', _methodLabel()),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: settlement == SaleSettlementMode.paidInFull && _changeDue() > 0.009
                ? Padding(
                    key: const ValueKey('chg'),
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.tertiary.withValues(alpha: 0.12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Change due',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '\$${_changeDue().toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox(key: ValueKey('nochg'), height: 0),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: KeyedSubtree(
              key: ValueKey<SaleSettlementMode>(settlement),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (settlement == SaleSettlementMode.paidInFull) ...[
                    Text(
                      'PAYMENT CHANNEL',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    KpmsPaymentMethodSelector(
                      selected: paymentMethod,
                      onSelected: onPaymentMethodChanged,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Amount collected',
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: collectedController,
                      onChanged: (_) => onCollectedChanged(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      decoration: InputDecoration(
                        prefixText: r'$ ',
                        filled: true,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (_collected + 0.009 < grandTotal)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Increase collected amount to at least the invoice total.',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                        ),
                      ),
                  ],
                  if (settlement == SaleSettlementMode.partialDebt) ...[
                    Text(
                      'AMOUNT RECEIVED NOW',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: collectedController,
                      onChanged: (_) => onCollectedChanged(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      decoration: InputDecoration(
                        labelText: 'Paid amount',
                        prefixText: r'$ ',
                        filled: true,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'PAYMENT CHANNEL',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    KpmsPaymentMethodSelector(
                      selected: paymentMethod,
                      onSelected: onPaymentMethodChanged,
                    ),
                  ],
                  if (settlement == SaleSettlementMode.fullDebt)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'No money collected — the full invoice is saved as customer debt.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, height: 1.4),
                      ),
                    ),
                ],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: showCustomer
                ? Padding(
                    key: const ValueKey('cust'),
                    padding: const EdgeInsets.only(top: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Divider(height: 1, color: outline),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Customer (required)',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: onPickCustomer,
                          icon: const Icon(Icons.person_search_rounded, size: 20),
                          label: const Text('Search or add customer'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: customerNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Customer name *',
                            filled: true,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: customerPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone number *',
                            filled: true,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: customerNotesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Notes (optional)',
                            filled: true,
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(key: ValueKey('nocust'), height: 0),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.theme, this.label, this.value, {this.strong = false, this.warn = false});

  final ThemeData theme;
  final String label;
  final String value;
  final bool strong;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final vStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
      color: warn ? Colors.orange.shade900 : null,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600),
          ),
        ),
        Text(value, style: vStyle, textAlign: TextAlign.right),
      ],
    );
  }
}

class _StatusOptionCard extends StatelessWidget {
  const _StatusOptionCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.compact = false,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool compact;

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
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: compact ? 10 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected ? primary : theme.colorScheme.outline.withValues(alpha: 0.25),
            ),
            color: selected ? primary.withValues(alpha: 0.08) : theme.colorScheme.surface.withValues(alpha: 0.5),
          ),
          child: compact
              ? Column(
                  children: [
                    Icon(icon, color: selected ? primary : theme.hintColor, size: 22),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: selected ? primary : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, height: 1.2),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Icon(icon, color: selected ? primary : theme.hintColor, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: selected ? primary : null,
                            ),
                          ),
                          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
