import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/kpms_empty_state.dart';
import '../../../core/widgets/kpms_keyboard_aware_scroll.dart';
import '../../../core/widgets/kpms_page_shell.dart';
import '../application/medicine_categories_notifier.dart';
import '../domain/medicine_category.dart';

/// Tenant-scoped medicine categories (nested via parent selection).
class MedicineCategoriesScreen extends ConsumerWidget {
  const MedicineCategoriesScreen({super.key});

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {MedicineCategory? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final categories = ref.read(medicineCategoriesProvider);
    String? parentId = existing?.parentId;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            padding: kpmsSheetScrollPadding(ctx),
            child: StatefulBuilder(
              builder: (ctx, setModal) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  Text(
                    existing == null ? 'Add category' : 'Edit category',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    key: ValueKey(parentId),
                    initialValue: parentId,
                    decoration: const InputDecoration(labelText: 'Parent category', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None (top level)')),
                      for (final c in categories)
                        if (c.id != existing?.id)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => setModal(() => parentId = v),
                  ),
                  const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) return;
                        Navigator.pop(ctx, true);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    if (saved != true) return;
    final notifier = ref.read(medicineCategoriesProvider.notifier);
    if (existing == null) {
      notifier.add(MedicineCategory(
        id: MedicineCategory.newClientId(),
        name: nameCtrl.text.trim(),
        parentId: parentId,
        sortOrder: categories.length,
      ));
    } else {
      notifier.update(existing.copyWith(name: nameCtrl.text.trim(), parentId: parentId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categories = ref.watch(medicineCategoriesProvider);
    final roots = ref.read(medicineCategoriesProvider.notifier).childrenOf(null);

    return KpmsPageShell(
      title: 'Categories',
      subtitle: '${categories.length} catalog groups',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: roots.isEmpty
          ? const KpmsEmptyState(
              icon: Icons.category_outlined,
              title: 'No categories yet',
              message: 'Organize medicines into groups for faster browsing and reporting.',
            )
          : ListView.separated(
              itemCount: roots.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = roots[i];
                final childCount = ref.read(medicineCategoriesProvider.notifier).countInSubtree(c.id);
                return Material(
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.25)),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(c.name),
                    subtitle: childCount > 0 ? Text('$childCount subcategories') : null,
                    onTap: () => _openEditor(context, ref, existing: c),
                    onLongPress: () async {
                      final err = ref.read(medicineCategoriesProvider.notifier).validateDelete(c.id);
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        return;
                      }
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete category?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (ok == true) ref.read(medicineCategoriesProvider.notifier).remove(c.id);
                    },
                  ),
                );
              },
            ),
    );
  }
}
