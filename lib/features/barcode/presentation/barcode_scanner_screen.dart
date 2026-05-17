import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../medicines/data/medicine_catalog_notifier.dart';
import '../../medicines/domain/medicine.dart';
import '../../sales/application/pos_cart_notifier.dart';
import '../../sales/application/pos_scan_settings_notifier.dart';
import '../domain/barcode_scan_pop_result.dart';

/// Enterprise-style barcode scan: compact preview, overlay, unmatched pharmacy workflow, POS integration.
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _controller;
  String? _lastCode;
  DateTime? _lastAt;
  Medicine? _match;
  bool _torch = false;
  late final AnimationController _lineCtrl;

  static const _debounce = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    if (!kIsWeb) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        detectionTimeoutMs: 350,
        cameraResolution: const Size(1280, 720),
        autoZoom: true,
        facing: CameraFacing.back,
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
          BarcodeFormat.code128,
          BarcodeFormat.code39,
          BarcodeFormat.code93,
          BarcodeFormat.itf14,
          BarcodeFormat.qrCode,
          BarcodeFormat.dataMatrix,
          BarcodeFormat.pdf417,
        ],
      );
    }
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    _controller?.dispose();
    super.dispose();
  }

  String? get _target => GoRouterState.of(context).uri.queryParameters['target'];
  bool get _forPos => _target == 'pos';

  Medicine? _findByBarcode(String raw) {
    final t = raw.trim();
    for (final m in ref.read(medicineCatalogProvider)) {
      if ((m.barcode ?? '').trim() == t) return m;
    }
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    final codes = capture.barcodes;
    if (codes.isEmpty) return;
    final raw0 = codes.first.rawValue ?? codes.first.displayValue;
    if (raw0 == null || raw0.isEmpty) return;
    final raw = raw0.trim();
    if (raw.isEmpty) return;

    final now = DateTime.now();
    if (_lastCode == raw && _lastAt != null && now.difference(_lastAt!) < _debounce) {
      return;
    }
    _lastCode = raw;
    _lastAt = now;

    if (_target == 'prefill') {
      HapticFeedback.selectionClick();
      if (mounted) {
        context.pop(BarcodeScanPopResult(rawCode: raw));
      }
      return;
    }

    final hit = _findByBarcode(raw);
    setState(() => _match = hit);
    HapticFeedback.lightImpact();

    if (hit == null) return;

    if (_forPos) {
      final auto = ref.read(posAutoAddAfterScanProvider).value ?? true;
      if (auto) {
        if (hit.sellingPrice < hit.buyingPrice) {
          kpmsSnack(context, 'Fix pricing in Medicines before selling.', isError: true);
          return;
        }
        final ok = ref.read(posCartProvider.notifier).addOrIncrement(hit);
        if (ok) {
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.click);
          kpmsSnack(context, '${hit.name} · added to cart');
          if (mounted) {
            context.pop(
              BarcodeScanPopResult(
                rawCode: raw,
                matchedMedicine: hit,
                cartHandledInScanner: true,
              ),
            );
          }
          return;
        }
      }
      return;
    }

    // Non-POS: stay on screen showing match (user taps action).
  }

  Future<void> _openLinkSheet(String code) async {
    final picked = await showModalBottomSheet<Medicine?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _LinkMedicineSheet(scannedCode: code),
    );
    if (!mounted || picked == null) return;
    ref.read(medicineCatalogProvider.notifier).updateMedicine(
          picked.copyWith(barcode: code),
        );
    final linked = picked.copyWith(barcode: code);
    setState(() => _match = linked);
    HapticFeedback.mediumImpact();
    kpmsSnack(context, 'Saved · barcode linked to ${linked.name}');
  }

  void _retryClear() {
    setState(() {
      _lastCode = null;
      _match = null;
      _lastAt = null;
    });
  }

  void _popAddMedicine(String code) {
    context.pop(
      BarcodeScanPopResult(
        rawCode: code,
        openAddMedicine: true,
      ),
    );
  }

  void _popCodeOnly(String code) {
    context.pop(
      BarcodeScanPopResult(rawCode: code, posSearchOnly: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = KpmsBreakpoints.pagePaddingHorizontal(MediaQuery.sizeOf(context).width);

    if (kIsWeb) {
      return KpmsPageShell(
        title: 'Barcode scanner',
        subtitle: 'Camera runs on Android & iOS',
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Text(
              'Use the mobile app to scan. On web, type the code in POS or Medicines search.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    final autoAddAsync = ref.watch(posAutoAddAfterScanProvider);

    return KpmsPageShell(
      title: 'Scan barcode',
      subtitle: _forPos
          ? 'Point at pack · fast checkout'
          : (_target == 'prefill')
              ? 'Scan pack barcode to fill field'
              : 'Match catalog or link',
      actions: [
        if (_forPos)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: autoAddAsync.when(
                data: (auto) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Auto-add', style: theme.textTheme.labelMedium),
                    const SizedBox(width: 4),
                    Switch.adaptive(
                      value: auto,
                      onChanged: (v) =>
                          ref.read(posAutoAddAfterScanProvider.notifier).setAutoAdd(v),
                    ),
                  ],
                ),
                loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        IconButton(
          tooltip: _torch ? 'Torch off' : 'Torch on',
          onPressed: () async {
            await _controller?.toggleTorch();
            setState(() => _torch = !_torch);
          },
          icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded),
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight;
          final scanHeight = (maxH * 0.33).clamp(188.0, 300.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
                child: Text(
                  _forPos
                      ? 'Scan adds to cart when Auto-add is on · use torch in low light'
                      : (_target == 'prefill')
                          ? 'One scan fills the barcode field'
                          : 'Scan or link unknown codes',
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.hintColor),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: scanHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                          errorBuilder: (ctx, err) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('Camera: ${err.errorCode}', textAlign: TextAlign.center),
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(
                                painter: _ScanFramePainter(
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                                child: const SizedBox.expand(),
                              ),
                              AnimatedBuilder(
                                animation: _lineCtrl,
                                builder: (context, _) => CustomPaint(
                                  painter: _ScanLinePainter(
                                    progress: _lineCtrl.value,
                                    color: AppColors.tertiary.withValues(alpha: 0.75),
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 12, pad, 12),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _lastCode == null
                        ? _HintCard(key: const ValueKey('hint'))
                        : _match != null
                            ? _MatchResultCard(
                                key: ValueKey('${_match!.id}_$_lastCode'),
                                medicine: _match!,
                                scannedCode: _lastCode!,
                                forPos: _forPos,
                                onContinueNonPos: !_forPos
                                    ? () => context.pop(
                                          BarcodeScanPopResult(
                                            rawCode: _lastCode!,
                                            matchedMedicine: _match,
                                          ),
                                        )
                                    : null,
                                onQuickAddToCart: _forPos
                                    ? () {
                                        final hit = _match!;
                                        final raw = _lastCode!;
                                        if (hit.sellingPrice < hit.buyingPrice) {
                                          kpmsSnack(
                                            context,
                                            'Fix pricing in Medicines before selling.',
                                            isError: true,
                                          );
                                          return;
                                        }
                                        final ok =
                                            ref.read(posCartProvider.notifier).addOrIncrement(hit);
                                        if (!context.mounted) return;
                                        if (ok) {
                                          HapticFeedback.mediumImpact();
                                          SystemSound.play(SystemSoundType.click);
                                          kpmsSnack(context, '${hit.name} · added to cart');
                                          context.pop(
                                            BarcodeScanPopResult(
                                              rawCode: raw,
                                              matchedMedicine: hit,
                                              cartHandledInScanner: true,
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                onPosSearchOnly: _forPos
                                    ? () => context.pop(
                                          BarcodeScanPopResult(
                                            rawCode: _lastCode!,
                                            matchedMedicine: _match,
                                            posSearchOnly: true,
                                          ),
                                        )
                                    : null,
                              )
                            : _UnmatchedWorkflowCard(
                                key: ValueKey(_lastCode),
                                scannedCode: _lastCode!,
                                forPos: _forPos,
                                onRetry: _retryClear,
                                onLink: () => _openLinkSheet(_lastCode!),
                                onAddMedicine: () => _popAddMedicine(_lastCode!),
                                onSendToPos: () => _popCodeOnly(_lastCode!),
                              ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.center_focus_strong_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Align the barcode inside the frame. Hold steady; use the torch icon for dim shelves.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchResultCard extends StatelessWidget {
  const _MatchResultCard({
    super.key,
    required this.medicine,
    required this.scannedCode,
    required this.forPos,
    this.onContinueNonPos,
    this.onQuickAddToCart,
    this.onPosSearchOnly,
  });

  final Medicine medicine;
  final String scannedCode;
  final bool forPos;
  final VoidCallback? onContinueNonPos;
  final VoidCallback? onQuickAddToCart;
  final VoidCallback? onPosSearchOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.97, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_rounded, color: AppColors.tertiary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      medicine.name,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${medicine.typeDisplayName} · Stock ${medicine.quantity}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 4),
              Text(
                r'$' + medicine.sellingPrice.toStringAsFixed(2),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Barcode $scannedCode',
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (forPos &&
                  onQuickAddToCart != null &&
                  onPosSearchOnly != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Auto-add is off — pick an action',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                ),
              ],
              const SizedBox(height: 12),
              if (!forPos && onContinueNonPos != null)
                FilledButton.icon(
                  onPressed: onContinueNonPos,
                  icon: const Icon(Icons.check_rounded, size: 20),
                  label: const Text('Continue'),
                )
              else if (forPos) ...[
                if (onQuickAddToCart != null)
                  FilledButton.icon(
                    onPressed: onQuickAddToCart,
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                    label: const Text('Add to cart'),
                  ),
                if (onPosSearchOnly != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onPosSearchOnly,
                    icon: const Icon(Icons.filter_list_rounded, size: 20),
                    label: const Text('Filter POS list'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnmatchedWorkflowCard extends StatelessWidget {
  const _UnmatchedWorkflowCard({
    super.key,
    required this.scannedCode,
    required this.forPos,
    required this.onRetry,
    required this.onLink,
    required this.onAddMedicine,
    required this.onSendToPos,
  });

  final String scannedCode;
  final bool forPos;
  final VoidCallback onRetry;
  final VoidCallback onLink;
  final VoidCallback onAddMedicine;
  final VoidCallback onSendToPos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not in catalog',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  scannedCode,
                  style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  'Link this code to an existing pack, register a new SKU, or send the code to POS search.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35, color: theme.hintColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: onLink,
            icon: const Icon(Icons.link_rounded, size: 20),
            label: const Text('Link to existing medicine'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: onAddMedicine,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add as new medicine'),
          ),
          if (forPos) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onSendToPos,
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text('Use code on POS search'),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Scan again'),
          ),
        ],
      ),
    );
  }
}

class _LinkMedicineSheet extends ConsumerStatefulWidget {
  const _LinkMedicineSheet({required this.scannedCode});

  final String scannedCode;

  @override
  ConsumerState<_LinkMedicineSheet> createState() => _LinkMedicineSheetState();
}

class _LinkMedicineSheetState extends ConsumerState<_LinkMedicineSheet> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meds = ref.watch(medicineCatalogProvider);
    final query = _q.text.trim().toLowerCase();
    final filtered = meds
        .where(
          (m) =>
              query.isEmpty ||
              m.name.toLowerCase().contains(query) ||
              (m.batchCode ?? '').toLowerCase().contains(query),
        )
        .take(80)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Link barcode',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose the medicine that matches this pack.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 4),
          Text(
            widget.scannedCode,
            style: theme.textTheme.titleSmall?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _q,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search catalog…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.42,
            child: filtered.isEmpty
                ? Center(child: Text('No matches', style: theme.textTheme.bodyMedium))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final m = filtered[i];
                      final conflict = (m.barcode ?? '').trim().isNotEmpty &&
                          (m.barcode ?? '').trim() != widget.scannedCode;
                      return ListTile(
                        title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          conflict
                              ? 'Replaces barcode ${m.barcode}'
                              : '${m.typeDisplayName} · Stock ${m.quantity}',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, m),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScanFramePainter extends CustomPainter {
  _ScanFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final inset = w * 0.12;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, h * 0.18, w - inset * 2, h * 0.52),
      const Radius.circular(12),
    );
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(rect, p);
  }

  @override
  bool shouldRepaint(covariant _ScanFramePainter oldDelegate) => oldDelegate.color != color;
}

class _ScanLinePainter extends CustomPainter {
  _ScanLinePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final inset = w * 0.12;
    final top = h * 0.18;
    final boxH = h * 0.52;
    final y = top + 8 + (boxH - 16) * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0),
          color,
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(inset, y - 2, w - inset * 2, 4));
    canvas.drawRect(Rect.fromLTWH(inset + 6, y, w - inset * 2 - 12, 2), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
