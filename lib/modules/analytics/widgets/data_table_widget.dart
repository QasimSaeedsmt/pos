import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Reusable data table widget for analytics data
class AnalyticsDataTable extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> data;
  final List<DataTableColumn> columns;
  final bool sortable;
  final bool paginated;
  final int itemsPerPage;
  final VoidCallback? onRefresh;
  final bool isLoading;

  const AnalyticsDataTable({
    super.key,
    required this.title,
    required this.data,
    required this.columns,
    this.sortable = true,
    this.paginated = true,
    this.itemsPerPage = 10,
    this.onRefresh,
    this.isLoading = false,
  });

  @override
  _AnalyticsDataTableState createState() => _AnalyticsDataTableState();
}

class _AnalyticsDataTableState extends State<AnalyticsDataTable> {
  List<Map<String, dynamic>> _sortedData = [];
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _sortedData = List.from(widget.data);
  }

  @override
  void didUpdateWidget(covariant AnalyticsDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _sortedData = List.from(widget.data);
      _sortData();
    }
  }

  void _sortData() {
    if (!widget.sortable || _sortedData.isEmpty) return;

    final column = widget.columns[_sortColumnIndex];
    _sortedData.sort((a, b) {
      final valueA = a[column.key];
      final valueB = b[column.key];

      if (valueA == null && valueB == null) return 0;
      if (valueA == null) return _sortAscending ? 1 : -1;
      if (valueB == null) return _sortAscending ? -1 : 1;

      int comparison;
      if (valueA is num && valueB is num) {
        comparison = valueA.compareTo(valueB);
      } else if (valueA is DateTime && valueB is DateTime) {
        comparison = valueA.compareTo(valueB);
      } else {
        comparison = valueA.toString().compareTo(valueB.toString());
      }

      return _sortAscending ? comparison : -comparison;
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _sortData();
    });
  }

  List<Map<String, dynamic>> get _visibleData {
    if (!widget.paginated) return _sortedData;

    final start = _currentPage * widget.itemsPerPage;
    final end = start + widget.itemsPerPage;
    return _sortedData.sublist(
      start,
      end > _sortedData.length ? _sortedData.length : end,
    );
  }

  int get _totalPages {
    return (widget.data.length / widget.itemsPerPage).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (widget.onRefresh != null)
                  IconButton(
                    icon: Icon(
                      Icons.refresh,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: widget.isLoading ? null : widget.onRefresh,
                    tooltip: 'Refresh',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_sortedData.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No data available',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: widget.columns.map((column) {
                        return DataColumn(
                          label: Text(
                            column.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          numeric: column.numeric,
                          onSort: widget.sortable ? _onSort : null,
                        );
                      }).toList(),
                      rows: _visibleData.map((row) {
                        return DataRow(
                          cells: widget.columns.map((column) {
                            final value = row[column.key];
                            return DataCell(
                              column.formatter != null
                                  ? Text(column.formatter!(value))
                                  : _formatCellValue(value, column),
                            );
                          }).toList(),
                        );
                      }).toList(),
                      sortColumnIndex: widget.sortable ? _sortColumnIndex : null,
                      sortAscending: _sortAscending,
                      headingRowHeight: 48,
                      dataRowHeight: 48,
                    ),
                  ),
                  if (widget.paginated && _totalPages > 1) ...[
                    const SizedBox(height: 16),
                    _buildPaginationControls(theme),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _formatCellValue(dynamic value, DataTableColumn column) {
    if (value == null) {
      return Text(
        '-',
        style: TextStyle(color: Colors.grey[500]),
      );
    }

    if (value is DateTime) {
      return Text(
        DateFormat('MMM dd, yyyy').format(value),
        style: const TextStyle(fontFamily: 'monospace'),
      );
    }

    if (value is num) {
      if (column.isCurrency) {
        return Text(
          NumberFormat.currency(symbol: '\$').format(value),
          style: const TextStyle(fontFamily: 'monospace'),
        );
      }
      return Text(
        NumberFormat.decimalPattern().format(value),
        style: const TextStyle(fontFamily: 'monospace'),
      );
    }

    return Text(value.toString());
  }

  Widget _buildPaginationControls(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _currentPage > 0
              ? () => setState(() => _currentPage--)
              : null,
          iconSize: 20,
        ),
        Text(
          'Page ${_currentPage + 1} of $_totalPages',
          style: theme.textTheme.bodyMedium,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _currentPage < _totalPages - 1
              ? () => setState(() => _currentPage++)
              : null,
          iconSize: 20,
        ),
      ],
    );
  }
}

/// Data table column definition
class DataTableColumn {
  final String key;
  final String label;
  final bool numeric;
  final bool isCurrency;
  final String Function(dynamic value)? formatter;

  const DataTableColumn({
    required this.key,
    required this.label,
    this.numeric = false,
    this.isCurrency = false,
    this.formatter,
  });
}