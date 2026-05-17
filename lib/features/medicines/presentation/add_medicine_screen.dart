import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_keyboard_aware_scroll.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../../notifications/application/kpms_pharmacy_success_notifications.dart';
import '../../barcode/domain/barcode_scan_pop_result.dart';
import '../data/custom_form_labels_notifier.dart';
import '../data/medicine_catalog_notifier.dart';
import '../domain/medicine.dart';
import '../domain/medicine_form_type.dart';
import '../domain/medicine_type_style.dart';

/// Full “Add medicine” flow — wire fields to Supabase insert later.
class AddMedicineScreen extends ConsumerStatefulWidget {
  const AddMedicineScreen({super.key, this.initialBarcode});

  /// Prefill from barcode scanner route (`?barcode=`).
  final String? initialBarcode;

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _qty = TextEditingController(text: '0');
  final _buy = TextEditingController();
  final _sell = TextEditingController();
  final _minStock = TextEditingController(text: '10');
  final _otherSpecify = TextEditingController();
  final _batch = TextEditingController();
  final _barcode = TextEditingController();

  DateTime? _expiry;
  Uint8List? _imageBytes;
  String _typeTag = MedicineFormType.tablet.name;

  @override
  void initState() {
    super.initState();
    final b = widget.initialBarcode?.trim();
    if (b != null && b.isNotEmpty) {
      _barcode.text = b;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _buy.dispose();
    _sell.dispose();
    _minStock.dispose();
    _otherSpecify.dispose();
    _batch.dispose();
    _barcode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (d != null) setState(() => _expiry = d);
  }

  Future<void> _promptNewType() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New medicine type'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Suppository, Spray…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && mounted) {
      final t = ctrl.text.trim();
      ctrl.dispose();
      if (t.isEmpty) return;
      ref.read(customFormLabelsProvider.notifier).add(t);
      setState(() => _typeTag = 'custom:$t');
      kpmsSnack(context, 'Type “$t” added');
    } else {
      ctrl.dispose();
    }
  }

  (MedicineFormType, String?) _resolveType() {
    if (_typeTag.startsWith('custom:')) {
      return (MedicineFormType.other, _typeTag.substring(7));
    }
    if (_typeTag == 'other_specify') {
      return (MedicineFormType.other, _otherSpecify.text.trim());
    }
    final ft = MedicineFormType.values.firstWhere((e) => e.name == _typeTag);
    return (ft, null);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _name.text.trim();
    final qty = int.tryParse(_qty.text) ?? 0;
    final buy = double.tryParse(_buy.text) ?? 0;
    final sell = double.tryParse(_sell.text) ?? 0;
    final minS = int.tryParse(_minStock.text) ?? 0;

    final resolved = _resolveType();
    if (resolved.$1 == MedicineFormType.other && (resolved.$2 == null || resolved.$2!.isEmpty)) {
      kpmsSnack(context, 'Enter a name for “Other” type', isError: true);
      return;
    }
    if (sell < buy) {
      kpmsSnack(context, 'Selling price cannot be below buying price', isError: true);
      return;
    }

    final id = 'med_${DateTime.now().millisecondsSinceEpoch}';
    final med = Medicine(
      id: id,
      name: name,
      expiryDate: _expiry,
      formType: resolved.$1,
      customFormLabel: resolved.$2,
      quantity: qty,
      buyingPrice: buy,
      sellingPrice: sell,
      minimumStockAlert: minS,
      imageBytes: _imageBytes,
      batchCode: _batch.text.trim().isEmpty ? null : _batch.text.trim(),
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
    );

    ref.read(medicineCatalogProvider.notifier).addMedicine(med);
    kpmsSnack(context, '${med.name} saved to catalog');
    unawaited(KpmsPharmacySuccessNotifications.medicineAdded(
      ref,
      medicineName: med.name,
      medicineId: med.id,
    ));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final custom = ref.watch(customFormLabelsProvider);

    final previewMedicine = Medicine(
      id: 'preview',
      name: _name.text.trim().isEmpty ? 'Medicine preview' : _name.text.trim(),
      formType: _resolveType().$1,
      customFormLabel: _resolveType().$2,
      quantity: 0,
      buyingPrice: 0,
      sellingPrice: 0,
      minimumStockAlert: 0,
    );
    final style = MedicineTypeStyle.resolve(previewMedicine);

    final items = <DropdownMenuItem<String>>[
      ...MedicineFormType.values.map(
        (e) => DropdownMenuItem(value: e.name, child: Text(e.label)),
      ),
      ...custom.map((c) => DropdownMenuItem(value: 'custom:$c', child: Text(c))),
      const DropdownMenuItem(value: 'other_specify', child: Text('Other — specify')),
    ];

    return KpmsPageShell(
      title: 'Add medicine',
      subtitle: 'Stock · pricing · presentation',
      body: Form(
        key: _formKey,
        child: KpmsKeyboardAwareScroll(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - t)),
                    child: child,
                  ),
                ),
                child: Material(
                  elevation: 0,
                  shadowColor: style.accent.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          style.softBg,
                          theme.colorScheme.surface,
                        ],
                      ),
                      border: Border.all(color: style.accent.withValues(alpha: 0.25)),
                    ),
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: style.accent.withValues(alpha: 0.25),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _imageBytes != null
                              ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                              : Icon(style.icon, size: 44, color: style.accent),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Medicine image',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Optional — tap to upload packaging photo.',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonalIcon(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                                    label: const Text('Gallery'),
                                  ),
                                  if (_imageBytes != null)
                                    TextButton(
                                      onPressed: () => setState(() => _imageBytes = null),
                                      child: const Text('Remove'),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _SectionCard(
                title: 'Details',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Medicine name *',
                        prefixIcon: Icon(Icons.badge_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use — controlled selection via setState
                      value: items.any((i) => i.value == _typeTag)
                          ? _typeTag
                          : MedicineFormType.tablet.name,
                      decoration: const InputDecoration(
                        labelText: 'Medicine type',
                        prefixIcon: Icon(Icons.category_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      ),
                      items: items,
                      onChanged: (v) => setState(() => _typeTag = v ?? MedicineFormType.tablet.name),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _promptNewType,
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text('Create custom type'),
                      ),
                    ),
                    if (_typeTag == 'other_specify') ...[
                      TextFormField(
                        controller: _otherSpecify,
                        decoration: const InputDecoration(
                          labelText: 'Specify type *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickExpiry,
                            icon: const Icon(Icons.event_rounded),
                            label: Text(
                              _expiry == null
                                  ? 'Expiry date (optional)'
                                  : '${_expiry!.year}-${_expiry!.month.toString().padLeft(2, '0')}-${_expiry!.day.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_expiry != null)
                          IconButton(
                            tooltip: 'Clear date',
                            onPressed: () => setState(() => _expiry = null),
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _batch,
                      decoration: const InputDecoration(
                        labelText: 'Batch code (optional)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _barcode,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'Barcode (optional)',
                              hintText: 'EAN · UPC · internal code',
                              prefixIcon: Icon(Icons.qr_code_2_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: IconButton.filledTonal(
                            tooltip: 'Scan barcode',
                            onPressed: () async {
                              final r = await context.push<BarcodeScanPopResult?>(
                                '${AppRoutes.barcodeScanner}?target=prefill',
                              );
                              if (!context.mounted) return;
                              if (r == null) return;
                              setState(() => _barcode.text = r.rawCode);
                              kpmsSnack(context, 'Barcode captured');
                            },
                            icon: const Icon(Icons.document_scanner_rounded),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Stock & pricing',
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _qty,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              prefixIcon: Icon(Icons.numbers_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 0) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _minStock,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Minimum stock alert',
                              prefixIcon: Icon(Icons.warning_amber_rounded),
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                            ),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 0) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _buy,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Buying price',
                              prefixText: r'$ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                            ),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              if (n == null || n < 0) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _sell,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Selling price',
                              prefixText: r'$ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                            ),
                            validator: (v) {
                              final n = double.tryParse(v ?? '');
                              if (n == null || n < 0) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  backgroundColor: AppColors.primary,
                ),
                onPressed: _submit,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save medicine'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
