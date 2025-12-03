import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../models/analytics_models.dart';

/// Reusable chart widget for analytics data
class AnalyticsChart extends StatelessWidget {
  final String title;
  final List<TimeSeriesData> data;
  final ChartType type;
  final bool showLegend;
  final bool showGrid;
  final String? yAxisTitle;
  final String? xAxisTitle;
  final Color? chartColor;
  final VoidCallback? onChartTapped;

  const AnalyticsChart({
    super.key,
    required this.title,
    required this.data,
    this.type = ChartType.line,
    this.showLegend = true,
    this.showGrid = true,
    this.yAxisTitle,
    this.xAxisTitle,
    this.chartColor,
    this.onChartTapped,
  });

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
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: SfCartesianChart(
                onDataLabelTapped: onChartTapped != null
                    ? (details) => onChartTapped!()
                    : null,
                primaryXAxis: CategoryAxis(
                  title: AxisTitle(text: xAxisTitle ?? ''),
                  labelRotation: -45,
                  majorGridLines: showGrid
                      ? const MajorGridLines(width: 1)
                      : const MajorGridLines(width: 0),
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: yAxisTitle ?? ''),
                  numberFormat: _getNumberFormat(), // must return NumberFormat?
                  majorGridLines: showGrid
                      ? const MajorGridLines(width: 1)
                      : const MajorGridLines(width: 0),
                ),
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  format: 'point.x : point.y',
                ),
                series: <CartesianSeries<TimeSeriesData, String>>[
                  if (type == ChartType.line)
                    LineSeries<TimeSeriesData, String>(
                      dataSource: data,
                      xValueMapper: (d, _) => d.label,
                      yValueMapper: (d, _) => d.value,
                      color: chartColor ?? theme.colorScheme.primary,
                      width: 2,
                      markerSettings: const MarkerSettings(isVisible: true, height: 4, width: 4),
                      dataLabelSettings: const DataLabelSettings(isVisible: false),
                    )
                  else
                    ColumnSeries<TimeSeriesData, String>(
                      dataSource: data,
                      xValueMapper: (d, _) => d.label,
                      yValueMapper: (d, _) => d.value,
                      color: chartColor ?? theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                      dataLabelSettings: const DataLabelSettings(isVisible: false),
                    ),
                ],
              ),
            )
,            if (showLegend && data.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildLegend(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: chartColor ?? theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${data.length} data points',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  NumberFormat? _getNumberFormat() {
    // Check if values look like currency (have decimal places)
    final hasDecimals = data.any((point) => point.value % 1 != 0);

    if (hasDecimals) {
      return NumberFormat.simpleCurrency(decimalDigits: 2); // e.g., $1,234.56
    } else {
      return NumberFormat('#,###'); // e.g., 1,234
    }
  }}

/// Chart type enum
enum ChartType {
  line,
  bar,
  column,
}