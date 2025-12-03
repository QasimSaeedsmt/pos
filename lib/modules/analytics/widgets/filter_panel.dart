import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/analytics_models.dart';

/// Filter panel for analytics queries
class AnalyticsFilterPanel extends StatefulWidget {
  final AnalyticsQuery initialQuery;
  final Function(AnalyticsQuery) onFilterChanged;
  final List<String> availableCategories;
  final List<String> availableSegments;

  const AnalyticsFilterPanel({
    super.key,
    required this.initialQuery,
    required this.onFilterChanged,
    this.availableCategories = const [],
    this.availableSegments = const [],
  });

  @override
  _AnalyticsFilterPanelState createState() => _AnalyticsFilterPanelState();
}

class _AnalyticsFilterPanelState extends State<AnalyticsFilterPanel> {
  late AnalyticsQuery _currentQuery;
  late DateTime _startDate;
  late DateTime _endDate;
  late Set<String> _selectedCategories;
  late Set<String> _selectedSegments;
  String? _reportType;

  @override
  void initState() {
    super.initState();
    _initializeFromQuery();
  }

  void _initializeFromQuery() {
    _currentQuery = widget.initialQuery;
    _startDate = _currentQuery.startDate;
    _endDate = _currentQuery.endDate;
    _selectedCategories = Set.from(_currentQuery.productCategories ?? []);
    _selectedSegments = Set.from(_currentQuery.customerSegments ?? []);
    _reportType = _currentQuery.reportType;
  }

  void _applyFilters() {
    final query = AnalyticsQuery(
      startDate: _startDate,
      endDate: _endDate,
      productCategories: _selectedCategories.isNotEmpty
          ? _selectedCategories.toList()
          : null,
      customerSegments: _selectedSegments.isNotEmpty
          ? _selectedSegments.toList()
          : null,
      reportType: _reportType ?? 'sales',
      customFilters: _currentQuery.customFilters,
    );

    widget.onFilterChanged(query);
  }

  void _resetFilters() {
    setState(() {
      _startDate = DateTime.now().subtract(const Duration(days: 30));
      _endDate = DateTime.now();
      _selectedCategories.clear();
      _selectedSegments.clear();
      _reportType = 'sales';
    });
    _applyFilters();
  }

  Future<void> _selectDate(
      BuildContext context,
      bool isStartDate,
      ) async {
    final initialDate = isStartDate ? _startDate : _endDate;
    final firstDate = DateTime(2020);
    final lastDate = DateTime.now().add(const Duration(days: 365));

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = selectedDate;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = selectedDate;
          if (_startDate.isAfter(_endDate)) {
            _startDate = _endDate.subtract(const Duration(days: 1));
          }
        }
      });
      _applyFilters();
    }
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
                Icon(
                  Icons.filter_alt,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Filters',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDateRangeFilter(),
            const SizedBox(height: 16),
            if (widget.availableCategories.isNotEmpty) ...[
              _buildCategoryFilter(),
              const SizedBox(height: 16),
            ],
            if (widget.availableSegments.isNotEmpty) ...[
              _buildSegmentFilter(),
              const SizedBox(height: 16),
            ],
            _buildReportTypeFilter(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date Range',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDateButton(
                'Start Date',
                _startDate,
                true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDateButton(
                'End Date',
                _endDate,
                false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateButton(String label, DateTime date, bool isStartDate) {
    return OutlinedButton(
      onPressed: () => _selectDate(context, isStartDate),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMM dd, yyyy').format(date),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Icon(
            Icons.calendar_today,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    if (widget.availableCategories.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.availableCategories.map((category) {
            final isSelected = _selectedCategories.contains(category);
            return FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategories.add(category);
                  } else {
                    _selectedCategories.remove(category);
                  }
                });
                _applyFilters();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSegmentFilter() {
    if (widget.availableSegments.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customer Segments',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.availableSegments.map((segment) {
            final isSelected = _selectedSegments.contains(segment);
            return FilterChip(
              label: Text(segment),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSegments.add(segment);
                  } else {
                    _selectedSegments.remove(segment);
                  }
                });
                _applyFilters();
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildReportTypeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report Type',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildReportTypeOption('Sales', 'sales'),
            _buildReportTypeOption('Inventory', 'inventory'),
            _buildReportTypeOption('Customer', 'customer'),
          ],
        ),
      ],
    );
  }

  Widget _buildReportTypeOption(String label, String value) {
    final isSelected = _reportType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _reportType = value);
          _applyFilters();
        }
      },
    );
  }
}