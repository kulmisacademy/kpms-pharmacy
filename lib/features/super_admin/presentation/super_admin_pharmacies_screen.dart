import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/navigation/kpms_breakpoints.dart';
import '../../../core/utils/kpms_feedback.dart';
import '../../../core/widgets/kpms_empty_state.dart';
import '../../../core/widgets/kpms_platform_admin_shell.dart';
import '../application/platform_admin_providers.dart';

/// Platform directory: search, status filter, live data from `super_admin_list_pharmacies`.
class SuperAdminPharmaciesScreen extends ConsumerStatefulWidget {
  const SuperAdminPharmaciesScreen({super.key});

  @override
  ConsumerState<SuperAdminPharmaciesScreen> createState() => _SuperAdminPharmaciesScreenState();
}

class _SuperAdminPharmaciesScreenState extends ConsumerState<SuperAdminPharmaciesScreen> {
  final _search = TextEditingController();
  String _status = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _applyFilters() {
    ref.read(superAdminPharmacyDirectoryQueryProvider.notifier).state = (_search.text.trim(), _status);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(superAdminPharmaciesProvider);
    return KpmsPlatformAdminShell(
      title: 'All pharmacies',
      subtitle: AppConstants.appFullName,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () {
            ref.invalidate(superAdminPharmaciesProvider);
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: KpmsBreakpoints.pageBodyInsets(context),
            child: LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 720;
                final searchField = TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: 'Search name, email, phone',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: 'Search',
                      icon: const Icon(Icons.search_rounded),
                      onPressed: _applyFilters,
                    ),
                  ),
                  onSubmitted: (_) => _applyFilters(),
                );
                final statusDD = DropdownButtonFormField<String>(
                  key: ValueKey(_status),
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'suspended', child: Text('Suspended')),
                    DropdownMenuItem(value: 'archived', child: Text('Archived')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _status = v);
                    _applyFilters();
                  },
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 10),
                      statusDD,
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.filter_alt_outlined),
                        label: const Text('Apply filters'),
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 12),
                    SizedBox(width: 200, child: statusDD),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton.tonalIcon(
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.filter_alt_outlined),
                        label: const Text('Apply'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => KpmsEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Could not load directory',
                message: '$e',
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return KpmsEmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'No pharmacies',
                    message: 'Adjust filters or create a tenant via pharmacy registration.',
                  );
                }
                return Scrollbar(
                  child: SingleChildScrollView(
                    padding: KpmsBreakpoints.pageScrollPadding(context),
                    scrollDirection: Axis.horizontal,
                    child: LayoutBuilder(
                      builder: (context, c) {
                        return ConstrainedBox(
                          constraints: BoxConstraints(minWidth: c.maxWidth.clamp(720, 1600)),
                          child: DataTable(
                            headingRowHeight: 44,
                            dataRowMinHeight: 48,
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('Pharmacy')),
                              DataColumn(label: Text('Owner')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Phone')),
                              DataColumn(label: Text('Plan')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Created')),
                              DataColumn(label: Text('Last activity')),
                              DataColumn(label: Text('')),
                            ],
                            rows: [
                              for (final r in rows)
                                DataRow(
                                  cells: [
                                    DataCell(Text(r['pharmacy_name']?.toString() ?? '—')),
                                    DataCell(Text(r['owner_name_display']?.toString() ?? r['owner_name']?.toString() ?? '—')),
                                    DataCell(Text(r['owner_email']?.toString() ?? '—')),
                                    DataCell(Text(r['owner_phone']?.toString() ?? r['pharmacy_phone']?.toString() ?? '—')),
                                    DataCell(Text(r['plan_name']?.toString() ?? '—')),
                                    DataCell(_StatusBadge(status: r['operational_status']?.toString() ?? '')),
                                    DataCell(Text(_shortDate(r['created_at']))),
                                    DataCell(Text(_shortDate(r['last_activity_at']))),
                                    DataCell(
                                      FilledButton.tonal(
                                        onPressed: () {
                                          final id = r['tenant_id']?.toString();
                                          if (id == null) {
                                            kpmsSnack(context, 'Missing tenant id', isError: true);
                                            return;
                                          }
                                          context.push(AppRoutes.superAdminPharmacyDetail(id));
                                        },
                                        child: const Text('Open'),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _shortDate(dynamic v) {
    if (v == null) return '—';
    final s = v.toString();
    if (s.length >= 10) return s.substring(0, 10);
    return s;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    switch (status) {
      case 'suspended':
        bg = scheme.tertiaryContainer;
        fg = scheme.onTertiaryContainer;
        break;
      case 'archived':
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
        break;
      default:
        bg = scheme.primaryContainer;
        fg = scheme.onPrimaryContainer;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        label: Text(status.isEmpty ? '—' : status),
        visualDensity: VisualDensity.compact,
        backgroundColor: bg,
        labelStyle: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
