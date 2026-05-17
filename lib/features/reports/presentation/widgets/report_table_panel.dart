import 'package:flutter/material.dart';

import '../../../../core/responsive/responsive_helpers.dart';
import '../../../../core/theme/app_colors.dart';

class ReportTablePanel extends StatefulWidget {
  const ReportTablePanel({
    super.key,
    required this.columns,
    required this.rows,
    this.rowsPerPage = 6,
  });

  final List<String> columns;
  final List<List<String>> rows;
  final int rowsPerPage;

  @override
  State<ReportTablePanel> createState() => _ReportTablePanelState();
}

class _ReportTablePanelState extends State<ReportTablePanel> {
  final _search = TextEditingController();
  int _sortColumn = 0;
  bool _sortAsc = true;
  int _page = 0;

  @override
  void didUpdateWidget(ReportTablePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pc = (widget.rows.length / widget.rowsPerPage).ceil().clamp(1, 9999);
    if (_page >= pc) {
      setState(() => _page = (pc - 1).clamp(0, 999));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<List<String>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    var list = [...widget.rows];
    if (q.isNotEmpty) {
      list = list.where((r) => r.any((c) => c.toLowerCase().contains(q))).toList();
    }
    list.sort((a, b) {
      if (_sortColumn >= a.length || _sortColumn >= b.length) return 0;
      final cmp = a[_sortColumn].compareTo(b[_sortColumn]);
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline.withValues(alpha: 0.28);
    final data = _filtered;
    final rowsPerPage = isDesktop(context) ? widget.rowsPerPage.clamp(10, 24) : widget.rowsPerPage;
    final pageCount = (data.length / rowsPerPage).ceil().clamp(1, 9999);
    final safePage = _page.clamp(0, pageCount - 1);
    if (safePage != _page) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _page = safePage);
      });
    }
    final start = safePage * rowsPerPage;
    final pageRows = data.skip(start).take(rowsPerPage).toList();

    Widget toolbarRow(double maxW) {
      final narrow = maxW < 520;
      final search = TextField(
        controller: _search,
        onChanged: (_) => setState(() {
          _page = 0;
        }),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search…',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
      final sort = InputDecorator(
        decoration: InputDecoration(
          labelText: 'Sort',
          isDense: true,
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            isExpanded: true,
            value: _sortColumn.clamp(0, widget.columns.length - 1),
            items: [
              for (var i = 0; i < widget.columns.length; i++)
                DropdownMenuItem(value: i, child: Text(widget.columns[i], overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _sortColumn = v);
            },
          ),
        ),
      );
      final dir = IconButton(
        tooltip: _sortAsc ? 'Ascending' : 'Descending',
        onPressed: () => setState(() => _sortAsc = !_sortAsc),
        icon: Icon(_sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
      );

      if (narrow) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            search,
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: sort),
                dir,
              ],
            ),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: search),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: sort),
          dir,
        ],
      );
    }

    return Material(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isDesktop(context) ? 20 : 14,
          14,
          isDesktop(context) ? 20 : 14,
          14,
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                toolbarRow(c.maxWidth),
                const SizedBox(height: 14),
                Text(
                  'Data (${data.length} rows)',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: outline),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: LayoutBuilder(
                      builder: (context, inner) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: inner.maxWidth),
                            child: Table(
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
                                  ),
                                  children: [
                                    for (final col in widget.columns)
                                      _HeaderCell(text: col, theme: theme),
                                  ],
                                ),
                                for (final row in pageRows)
                                  TableRow(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                                      ),
                                    ),
                                    children: [
                                      for (final cell in row) _BodyCell(text: cell, theme: theme),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Page ${safePage + 1} of $pageCount',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: safePage > 0 ? () => setState(() => _page = safePage - 1) : null,
                      child: const Text('Previous'),
                    ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(foregroundColor: AppColors.primaryDark),
                      onPressed: safePage < pageCount - 1 ? () => setState(() => _page = safePage + 1) : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.2),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell({required this.text, required this.theme});

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(height: 1.25),
      ),
    );
  }
}
