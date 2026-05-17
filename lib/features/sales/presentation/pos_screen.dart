import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/responsive/responsive_helpers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../barcode/domain/barcode_scan_pop_result.dart';
import '../../enterprise/application/product_barcodes_notifier.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../medicines/domain/medicine.dart';
import '../../medicines/domain/medicine_type_style.dart';
import '../application/pos_cart_notifier.dart';
import '../domain/cart_line.dart';

/// Product-style grid vs compact list — single scroll in catalog (no nested list+page scroll).
enum PosCatalogViewMode { grid, list }

bool _medicineMatchesQuery(Medicine m, String q) {
  if (q.isEmpty) return true;
  final n = m.name.toLowerCase();
  final b = (m.barcode ?? '').toLowerCase();
  return n.contains(q) || b.contains(q);
}

/// Pharmacy POS — grid/list modes, barcode search, collapsible cart rail (desktop).
class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _search = TextEditingController();
  PosCatalogViewMode _viewMode = PosCatalogViewMode.grid;
  bool _cartRailExpanded = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _editSell(BuildContext context, WidgetRef ref, CartLine line) async {
    final ctrl = TextEditingController(text: line.unitSell.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Selling price · ${line.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(prefixText: r'$ ', labelText: 'Per unit'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      final v = double.tryParse(ctrl.text);
      ctrl.dispose();
      if (v == null) return;
      ref.read(posCartProvider.notifier).setUnitSell(line.id, v);
      if (v < line.unitBuy) {
        kpmsSnack(context, 'Price below buying cost — sale cannot complete until fixed.', isError: true);
      }
    } else {
      ctrl.dispose();
    }
  }

  void _tryAddMedicine(Medicine m) {
    if (m.sellingPrice < m.buyingPrice) {
      kpmsSnack(context, 'Catalog error: selling below cost — fix in Medicines first.', isError: true);
      return;
    }
    final ok = ref.read(posCartProvider.notifier).addOrIncrement(m);
    if (!ok) {
      kpmsSnack(context, 'Could not add line', isError: true);
      return;
    }
    if (!kIsWeb) {
      HapticFeedback.lightImpact();
    }
    kpmsSnack(context, '${m.name} added to cart');
  }

  void _openCheckout(BuildContext context) {
    if (ref.read(posCartProvider).isEmpty) {
      kpmsSnack(context, 'Cart is empty', isError: true);
      return;
    }
    context.push(AppRoutes.checkout);
  }

  Future<void> _openBarcodeScanner(BuildContext context) async {
    final result = await context.push<BarcodeScanPopResult?>('${AppRoutes.barcodeScanner}?target=pos');
    if (!context.mounted || result == null) return;

    if (result.openAddMedicine) {
      await context.push(
        '${AppRoutes.addMedicine}?barcode=${Uri.encodeComponent(result.rawCode)}',
      );
      return;
    }

    if (result.cartHandledInScanner) {
      return;
    }

    if (result.posSearchOnly) {
      final q = (result.matchedMedicine?.name ?? result.rawCode).trim();
      _search.text = q;
      setState(() {});
      return;
    }

    final trimmed = result.rawCode.trim();
    if (trimmed.isEmpty) return;

    final extraMedicineId = ref.read(pharmacyBarcodeLookupProvider)(trimmed);
    final med = result.matchedMedicine ??
        () {
          if (extraMedicineId != null) {
            return ref.read(medicineCatalogProvider.notifier).byId(extraMedicineId);
          }
          for (final m in ref.read(medicineCatalogProvider)) {
            if ((m.barcode ?? '').trim() == trimmed) return m;
          }
          return null;
        }();

    if (med != null) {
      _tryAddMedicine(med);
      return;
    }

    _search.text = trimmed;
    setState(() {});
    if (!context.mounted) return;
    kpmsSnack(
      context,
      'No medicine linked to this barcode — use catalog search, link barcode, or register stock.',
    );
  }

  void _openCartSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.72,
          child: Consumer(
            builder: (context, ref, _) => _PosCartPanel(
              onCheckout: () {
                Navigator.pop(ctx);
                _openCheckout(context);
              },
              onReturns: () {
                Navigator.pop(ctx);
                context.push(AppRoutes.salesReturns);
              },
              onEditSell: (line) => _editSell(context, ref, line),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = isPosSplitLayout(context);
    final meds = ref.watch(medicineCatalogProvider);
    final cart = ref.watch(posCartProvider);
    final notifier = ref.read(posCartProvider.notifier);

    final q = _search.text.trim().toLowerCase();
    final filtered = meds.where((m) => _medicineMatchesQuery(m, q)).toList();

    final catalog = _PosCatalogPane(
      controller: _search,
      viewMode: _viewMode,
      onViewModeChanged: (m) => setState(() => _viewMode = m),
      onChanged: () => setState(() {}),
      medicines: filtered,
      onPick: _tryAddMedicine,
    );

    final cartPanel = _PosCartPanel(
      onCheckout: () => _openCheckout(context),
      onReturns: () => context.push(AppRoutes.salesReturns),
      onEditSell: (line) => _editSell(context, ref, line),
    );

    final body = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: catalog),
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: _cartRailExpanded ? 420 : 56,
                child: ClipRect(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        child: InkWell(
                          onTap: () => setState(() => _cartRailExpanded = !_cartRailExpanded),
                          child: SizedBox(
                            width: 56,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _cartRailExpanded ? Icons.chevron_right_rounded : Icons.shopping_bag_rounded,
                                  color: AppColors.primary,
                                  size: 26,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${notifier.itemCount}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                RotatedBox(
                                  quarterTurns: 3,
                                  child: Text(
                                    'CART',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          letterSpacing: 1.2,
                                          fontWeight: FontWeight.w800,
                                          color: Theme.of(context).hintColor,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_cartRailExpanded)
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.25)),
                              ),
                            ),
                            child: cartPanel,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : catalog;

    return KpmsPageShell(
      title: 'Point of sale',
      subtitle: 'Grid · list · barcode-aware search',
      constrainContentWidth: false,
      actions: [
        IconButton(
          tooltip: 'Scan barcode',
          icon: const Icon(Icons.document_scanner_rounded),
          onPressed: () => _openBarcodeScanner(context),
        ),
      ],
      floatingActionButton: wide
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openCartSheet(context),
              icon: const Icon(Icons.shopping_cart_rounded),
              label: Text(
                cart.isEmpty ? 'Cart' : '${notifier.itemCount} · \$${notifier.subtotal.toStringAsFixed(2)}',
              ),
            ),
      body: body,
    );
  }
}

/// Grid column count + aspect ratio from actual catalog column width (fixes clipped Quick add on web).
({int cross, double aspect}) _posGridLayout(double catalogW, double pad) {
  const gap = 14.0;
  final int cross;
  if (catalogW < 280) {
    cross = 1;
  } else if (isDesktopWidth(catalogW)) {
    if (catalogW >= 720) {
      cross = 4;
    } else if (catalogW >= 520) {
      cross = 3;
    } else {
      cross = 2;
    }
  } else {
    cross = 2;
  }
  final totalGap = gap * (cross - 1);
  final cellW = (catalogW - pad * 2 - totalGap) / cross;
  const targetH = 212.0;
  final raw = math.max(1.0, cellW) / targetH;
  final aspect = cross == 1 ? math.max(raw, 1.12) : math.max(raw, 0.52);
  return (cross: cross, aspect: aspect);
}

class _PosCatalogPane extends StatelessWidget {
  const _PosCatalogPane({
    required this.controller,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.onChanged,
    required this.medicines,
    required this.onPick,
  });

  final TextEditingController controller;
  final PosCatalogViewMode viewMode;
  final ValueChanged<PosCatalogViewMode> onViewModeChanged;
  final VoidCallback onChanged;
  final List<Medicine> medicines;
  final void Function(Medicine m) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewportW = MediaQuery.sizeOf(context).width;
    final pad = KpmsBreakpoints.pagePaddingHorizontal(viewportW);
    final animateTiles = isMobile(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final catalogW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : viewportW;
        final grid = _posGridLayout(catalogW, pad);

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: kIsWeb),
          child: CustomScrollView(
            primary: true,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 14, pad, 10),
            sliver: SliverToBoxAdapter(
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Theme(
                  data: theme.copyWith(
                    inputDecorationTheme: InputDecorationTheme(
                      filled: false,
                      fillColor: Colors.transparent,
                      hintStyle: theme.inputDecorationTheme.hintStyle,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    onChanged: (_) => onChanged(),
                    decoration: InputDecoration(
                      hintText: 'Search name or barcode…',
                      prefixIcon: Icon(Icons.search_rounded, color: theme.hintColor),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text(
                    'Catalog',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  SegmentedButton<PosCatalogViewMode>(
                    segments: const [
                      ButtonSegment(
                        value: PosCatalogViewMode.grid,
                        label: Text('Grid'),
                        icon: Icon(Icons.grid_view_rounded, size: 18),
                      ),
                      ButtonSegment(
                        value: PosCatalogViewMode.list,
                        label: Text('List'),
                        icon: Icon(Icons.view_list_rounded, size: 18),
                      ),
                    ],
                    selected: {viewMode},
                    onSelectionChanged: (s) => onViewModeChanged(s.first),
                  ),
                ],
              ),
            ),
          ),
          if (medicines.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 56, color: theme.hintColor),
                      const SizedBox(height: 12),
                      Text(
                        'No matches',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try another name or barcode.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '${medicines.length} product${medicines.length == 1 ? '' : 's'}',
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (viewMode == PosCatalogViewMode.grid)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: grid.cross,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: grid.aspect,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    childCount: medicines.length,
                    (context, i) {
                      final card = _PosGridProductCard(
                        medicine: medicines[i],
                        onAdd: () => onPick(medicines[i]),
                      );
                      if (!animateTiles) return card;
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 220 + (i % 5) * 28),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, child) => Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - t)),
                            child: child,
                          ),
                        ),
                        child: card,
                      );
                    },
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
                sliver: SliverList.separated(
                  itemCount: medicines.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _PosListProductRow(
                    medicine: medicines[i],
                    onAdd: () => onPick(medicines[i]),
                  ),
                ),
              ),
          ],
            ],
          ),
        );
      },
    );
  }
}

class _PosGridProductCard extends StatefulWidget {
  const _PosGridProductCard({required this.medicine, required this.onAdd});

  final Medicine medicine;
  final VoidCallback onAdd;

  @override
  State<_PosGridProductCard> createState() => _PosGridProductCardState();
}

class _PosGridProductCardState extends State<_PosGridProductCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = MedicineTypeStyle.resolve(widget.medicine);
    final profit = widget.medicine.sellingPrice - widget.medicine.buyingPrice;
    final low = widget.medicine.isLowStock;
    final outline = theme.colorScheme.outline.withValues(alpha: low ? 0.45 : 0.14);
    final enableHover = !isMobile(context);

    Widget card = Material(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.surface,
          border: Border.all(
            color: _hover && enableHover ? AppColors.primary.withValues(alpha: 0.45) : outline,
            width: _hover && enableHover ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: theme.brightness == Brightness.dark ? 0.35 : 0.06),
              blurRadius: _hover && enableHover ? 18 : 12,
              offset: Offset(0, _hover && enableHover ? 8 : 4),
            ),
            if (_hover && enableHover)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onAdd,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: widget.medicine.imageBytes != null
                                    ? Image.memory(widget.medicine.imageBytes!, fit: BoxFit.cover)
                                    : DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              style.softBg,
                                              style.accent.withValues(alpha: 0.22),
                                            ],
                                          ),
                                        ),
                                        child: Icon(style.icon, size: 26, color: style.accent),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.medicine.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.medicine.typeDisplayName,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: theme.hintColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(999),
                                          color: low
                                              ? Colors.orange.withValues(alpha: 0.18)
                                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
                                          border: Border.all(
                                            color: theme.colorScheme.outline.withValues(alpha: 0.2),
                                          ),
                                        ),
                                        child: Text(
                                          'Stock ${widget.medicine.quantity}',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((widget.medicine.barcode ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.medicine.barcode!,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.hintColor.withValues(alpha: 0.9),
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _PosGridPriceCell(
                                label: 'Sell',
                                value: widget.medicine.sellingPrice,
                                accent: AppColors.primary,
                                emphasized: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _PosGridPriceCell(
                                label: 'Buy',
                                value: widget.medicine.buyingPrice,
                                accent: theme.colorScheme.onSurfaceVariant,
                                emphasized: false,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Margin +\$${profit.toStringAsFixed(2)}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.tertiary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: SizedBox(
                height: 38,
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: widget.onAdd,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Quick add'),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!enableHover) return card;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hover ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: card,
      ),
    );
  }
}

/// Compact sell/buy price cell for POS grid tiles.
class _PosGridPriceCell extends StatelessWidget {
  const _PosGridPriceCell({
    required this.label,
    required this.value,
    required this.accent,
    required this.emphasized,
  });

  final String label;
  final double value;
  final Color accent;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: theme.brightness == Brightness.dark ? 0.45 : 0.65);
    final border = theme.colorScheme.outline.withValues(alpha: 0.12);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.hintColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '\$${value.toStringAsFixed(2)}',
              style: (emphasized ? theme.textTheme.titleMedium : theme.textTheme.titleSmall)?.copyWith(
                fontWeight: FontWeight.w900,
                color: accent,
                height: 1.05,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosListProductRow extends StatelessWidget {
  const _PosListProductRow({required this.medicine, required this.onAdd});

  final Medicine medicine;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = MedicineTypeStyle.resolve(medicine);
    final profit = medicine.sellingPrice - medicine.buyingPrice;

    return Material(
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: medicine.imageBytes != null
                      ? Image.memory(medicine.imageBytes!, fit: BoxFit.cover)
                      : DecoratedBox(
                          decoration: BoxDecoration(color: style.softBg),
                          child: Icon(style.icon, color: style.accent),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        if ((medicine.barcode ?? '').isNotEmpty) medicine.barcode!,
                        'Stock ${medicine.quantity}',
                      ].join(' · '),
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'Buy \$${medicine.buyingPrice.toStringAsFixed(2)} · Sell \$${medicine.sellingPrice.toStringAsFixed(2)} · +\$${profit.toStringAsFixed(2)}',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onAdd,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(88, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosCartPanel extends ConsumerWidget {
  const _PosCartPanel({
    required this.onCheckout,
    required this.onReturns,
    required this.onEditSell,
  });

  final VoidCallback onCheckout;
  final VoidCallback onReturns;
  final void Function(CartLine line) onEditSell;

  static const _taxRate = 0.05;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isMobile(context)) {
      return _PosCartPanelMobile(
        onCheckout: onCheckout,
        onReturns: onReturns,
        onEditSell: onEditSell,
      );
    }

    final theme = Theme.of(context);
    final desktop = isDesktop(context);
    final double pad = desktop
        ? 16
        : KpmsBreakpoints.pagePaddingHorizontal(MediaQuery.sizeOf(context).width).clamp(8.0, 18.0);
    final lines = ref.watch(posCartProvider);
    final notifier = ref.read(posCartProvider.notifier);

    final subtotal = notifier.subtotal;
    final profit = notifier.totalProfit;
    final tax = subtotal * _taxRate;
    final grand = subtotal + tax;
    final border = theme.colorScheme.outline.withValues(alpha: theme.brightness == Brightness.dark ? 0.22 : 0.32);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(left: BorderSide(color: border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: theme.colorScheme.surface,
            elevation: desktop ? 2 : 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 14, pad, 12),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invoice', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                        Text(
                          'Live cart · ${notifier.itemCount} item${notifier.itemCount == 1 ? '' : 's'}',
                          style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text('${notifier.itemCount}'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: kIsWeb),
              child: lines.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(pad),
                        child: Text(
                          'Add products from the catalog.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                        ),
                      ),
                    )
                  : ListView.builder(
                      primary: false,
                      padding: EdgeInsets.fromLTRB(pad, 12, pad, 12),
                      itemCount: lines.length,
                      itemBuilder: (context, i) => RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PosCartLineTile(
                            line: lines[i],
                            onEditSell: () => onEditSell(lines[i]),
                            onRemove: () => ref.read(posCartProvider.notifier).remove(lines[i].id),
                            onQty: (q) => ref.read(posCartProvider.notifier).setQuantity(lines[i].id, q),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          Material(
            color: theme.colorScheme.surface,
            elevation: desktop ? 6 : 0,
            shadowColor: Colors.black.withValues(alpha: 0.12),
            child: Padding(
              padding: EdgeInsets.fromLTRB(pad, 12, pad, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _totRow(theme, 'Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
                  _totRow(theme, 'Est. profit', '\$${profit.toStringAsFixed(2)}', profit: true),
                  _totRow(theme, 'Tax (${(_taxRate * 100).toStringAsFixed(0)}%)', '\$${tax.toStringAsFixed(2)}'),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Grand total', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Text(
                          '\$${grand.toStringAsFixed(2)}',
                          key: ValueKey(grand),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: lines.isEmpty ? null : onCheckout,
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Continue to checkout'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onReturns,
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: const Text('Returns & refunds'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _totRow(ThemeData theme, String a, String b, {bool profit = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(a, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          Text(
            b,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: profit ? AppColors.tertiary : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mobile cart sheet — unchanged layout from pre-web polish.
class _PosCartPanelMobile extends ConsumerWidget {
  const _PosCartPanelMobile({
    required this.onCheckout,
    required this.onReturns,
    required this.onEditSell,
  });

  final VoidCallback onCheckout;
  final VoidCallback onReturns;
  final void Function(CartLine line) onEditSell;

  static const _taxRate = 0.05;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pad = KpmsBreakpoints.pagePaddingHorizontal(MediaQuery.sizeOf(context).width);
    final lines = ref.watch(posCartProvider);
    final notifier = ref.read(posCartProvider.notifier);

    final subtotal = notifier.subtotal;
    final profit = notifier.totalProfit;
    final tax = subtotal * _taxRate;
    final grand = subtotal + tax;

    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      padding: EdgeInsets.fromLTRB(pad.clamp(8, 18), 12, pad.clamp(8, 18), 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Checkout', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              Chip(label: Text('${notifier.itemCount} items'), visualDensity: VisualDensity.compact),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: GlassCard(
                padding: const EdgeInsets.all(10),
                child: lines.isEmpty
                    ? Center(
                        child: Text(
                          'Add products from the catalog.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                        ),
                      )
                    : ListView.separated(
                        primary: false,
                        shrinkWrap: false,
                        itemCount: lines.length,
                        separatorBuilder: (_, _) => const Divider(height: 14),
                        itemBuilder: (context, i) {
                          final line = lines[i];
                          final bad = line.priceViolatesFloor;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      line.name,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: bad ? Colors.red.shade700 : null,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    onPressed: () => ref.read(posCartProvider.notifier).remove(line.id),
                                  ),
                                ],
                              ),
                              Text(
                                'Buy \$${line.unitBuy.toStringAsFixed(2)}',
                                style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                              ),
                              InkWell(
                                onTap: () => onEditSell(line),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Sell \$${line.unitSell.toStringAsFixed(2)}',
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: bad ? Colors.red.shade700 : AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(Icons.edit_rounded, size: 16, color: theme.hintColor),
                                    ],
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => ref.read(posCartProvider.notifier).setQuantity(line.id, line.quantity - 1),
                                    icon: const Icon(Icons.remove_circle_outline_rounded),
                                  ),
                                  Text('${line.quantity}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                  IconButton(
                                    onPressed: () => ref.read(posCartProvider.notifier).setQuantity(line.id, line.quantity + 1),
                                    icon: const Icon(Icons.add_circle_outline_rounded),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Line \$${line.lineSubtotal.toStringAsFixed(2)}', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                                  Text(
                                    'Profit \$${line.lineProfit.toStringAsFixed(2)}',
                                    style: theme.textTheme.labelMedium?.copyWith(color: AppColors.tertiary, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              if (bad)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Selling below cost — blocked at checkout.',
                                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.red.shade700),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PosCartPanel._totRow(theme, 'Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
          _PosCartPanel._totRow(theme, 'Est. profit', '\$${profit.toStringAsFixed(2)}', profit: true),
          _PosCartPanel._totRow(theme, 'Tax (${(_taxRate * 100).toStringAsFixed(0)}%)', '\$${tax.toStringAsFixed(2)}'),
          const Divider(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Grand total', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              Text('\$${grand.toStringAsFixed(2)}', style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onCheckout,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('Continue to checkout'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onReturns,
            icon: const Icon(Icons.assignment_return_outlined),
            label: const Text('Returns & refunds'),
          ),
        ],
      ),
    );
  }
}

class _PosCartLineTile extends StatelessWidget {
  const _PosCartLineTile({
    required this.line,
    required this.onEditSell,
    required this.onRemove,
    required this.onQty,
  });

  final CartLine line;
  final VoidCallback onEditSell;
  final VoidCallback onRemove;
  final void Function(int qty) onQty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bad = line.priceViolatesFloor;
    final outline = theme.colorScheme.outline.withValues(alpha: 0.2);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: outline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    line.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: bad ? Colors.red.shade700 : null,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: onRemove,
                ),
              ],
            ),
            Text(
              'Buy \$${line.unitBuy.toStringAsFixed(2)}',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
            ),
            InkWell(
              onTap: onEditSell,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'Sell \$${line.unitSell.toStringAsFixed(2)}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: bad ? Colors.red.shade700 : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_rounded, size: 16, color: theme.hintColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                border: Border.all(color: outline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onQty(line.quantity - 1),
                    icon: const Icon(Icons.remove_rounded, size: 20),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${line.quantity}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onQty(line.quantity + 1),
                    icon: const Icon(Icons.add_rounded, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Line \$${line.lineSubtotal.toStringAsFixed(2)}',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Profit \$${line.lineProfit.toStringAsFixed(2)}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (bad)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Selling below cost — blocked at checkout.',
                  style: theme.textTheme.labelSmall?.copyWith(color: Colors.red.shade700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
