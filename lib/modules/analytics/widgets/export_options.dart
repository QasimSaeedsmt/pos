import 'package:flutter/material.dart';

import '../models/export_models.dart';

/// Widget for selecting export options
class ExportOptionsDialog extends StatefulWidget {
  final ExportConfig initialConfig;
  final Function(ExportConfig) onExport;
  final bool isLoading;

  const ExportOptionsDialog({
    super.key,
    required this.initialConfig,
    required this.onExport,
    this.isLoading = false,
  });

  @override
  _ExportOptionsDialogState createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<ExportOptionsDialog> {
  late ExportConfig _config;
  late Map<String, bool> _selectedFields;
  final List<String> _availableFields = [
    'summary',
    'charts',
    'raw_data',
    'trends',
    'categories',
    'top_products',
  ];

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _selectedFields = { for (var field in _availableFields) field : widget.initialConfig.selectedFields.contains(field) };
  }

  void _updateFormat(ExportFormat format) {
    setState(() => _config = _config.copyWith(format: format));
  }

  void _updateOption(String key, bool value) {
    setState(() {
      if (key == 'includeCharts') {
        _config = _config.copyWith(includeCharts: value);
      } else if (key == 'includeRawData') {
        _config = _config.copyWith(includeRawData: value);
      }
    });
  }

  void _toggleField(String field, bool selected) {
    setState(() => _selectedFields[field] = selected);
  }

  void _applyExport() {
    final selectedFields = _selectedFields.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    final config = _config.copyWith(selectedFields: selectedFields);
    widget.onExport(config);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Export Options'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Format',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExportFormat.values.map((format) {
                final isSelected = _config.format == format;
                return ChoiceChip(
                  label: Text(_formatLabel(format)),
                  selected: isSelected,
                  onSelected: (selected) => _updateFormat(format),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Content',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Include Charts'),
              value: _config.includeCharts,
              onChanged: (value) => _updateOption('includeCharts', value ?? false),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: const Text('Include Raw Data'),
              value: _config.includeRawData,
              onChanged: (value) => _updateOption('includeRawData', value ?? false),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            Text(
              'Fields to Include',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableFields.map((field) {
                final isSelected = _selectedFields[field] ?? false;
                return FilterChip(
                  label: Text(_fieldLabel(field)),
                  selected: isSelected,
                  onSelected: (selected) => _toggleField(field, selected),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: widget.isLoading ? null : _applyExport,
          child: widget.isLoading
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Export'),
        ),
      ],
    );
  }

  String _formatLabel(ExportFormat format) {
    switch (format) {
      case ExportFormat.csv:
        return 'CSV';
      case ExportFormat.excel:
        return 'Excel';
      case ExportFormat.pdf:
        return 'PDF';
      case ExportFormat.json:
        return 'JSON';
      case ExportFormat.html:
        return 'HTML';
    }
  }

  String _fieldLabel(String field) {
    switch (field) {
      case 'summary':
        return 'Summary';
      case 'charts':
        return 'Charts';
      case 'raw_data':
        return 'Raw Data';
      case 'trends':
        return 'Trends';
      case 'categories':
        return 'Categories';
      case 'top_products':
        return 'Top Products';
      default:
        return field.replaceAll('_', ' ');
    }
  }
}