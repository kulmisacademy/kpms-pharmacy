import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/kpms_inventory_permission_provider.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/kpms_feedback.dart';
import '../../application/medicine_catalog_service.dart';
import '../../domain/medicine.dart';
import 'medicine_delete_confirm_dialog.dart';

/// Inline edit/delete controls for medicine list cards (desktop hover + mobile menu).
class MedicineManageActions extends ConsumerWidget {
  const MedicineManageActions({
    super.key,
    required this.medicine,
    this.compact = false,
    this.onDeleted,
  });

  final Medicine medicine;
  final bool compact;
  final VoidCallback? onDeleted;

  static String editRouteFor(Medicine m) =>
      '${AppRoutes.addMedicine}?id=${Uri.encodeComponent(m.id)}';

  static Future<void> confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    Medicine medicine, {
    VoidCallback? onDeleted,
  }) async {
    final warnings = MedicineCatalogService.deleteWarnings(ref, medicine);
    final ok = await showMedicineDeleteConfirmDialog(context, medicine, warnings: warnings);
    if (!ok || !context.mounted) return;

    final result = await MedicineCatalogService.deleteMedicine(ref, medicine.id);
    if (!context.mounted) return;

    switch (result) {
      case MedicineDeleteResult.success:
        kpmsSnack(context, '${medicine.name} deleted');
        onDeleted?.call();
      case MedicineDeleteResult.notFound:
        kpmsSnack(context, 'Medicine not found', isError: true);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    await confirmAndDelete(context, ref, medicine, onDeleted: onDeleted);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canManage = ref.watch(kpmsCanManageInventoryProvider);
    if (!canManage) return const SizedBox.shrink();

    if (compact) {
      return PopupMenuButton<String>(
        tooltip: 'Medicine actions',
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (v) async {
          if (v == 'edit') {
            await context.push(editRouteFor(medicine));
          } else if (v == 'delete') {
            await _delete(context, ref);
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Edit medicine',
          visualDensity: VisualDensity.compact,
          onPressed: () => context.push(editRouteFor(medicine)),
          icon: const Icon(Icons.edit_outlined, size: 20),
        ),
        IconButton(
          tooltip: 'Delete medicine',
          visualDensity: VisualDensity.compact,
          onPressed: () => _delete(context, ref),
          icon: Icon(Icons.delete_outline_rounded, size: 20, color: Theme.of(context).colorScheme.error),
        ),
      ],
    );
  }
}
