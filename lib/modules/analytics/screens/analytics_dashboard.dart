import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/logger.dart';
import '../controllers/analytics_controller.dart';
import '../models/analytics_models.dart';
import '../models/export_models.dart';
import '../widgets/export_options.dart';
import '../widgets/metric_card.dart';
import '../widgets/chart_widget.dart';
import '../widgets/filter_panel.dart';

/// Main analytics dashboard screen
class AnalyticsDashboard extends StatefulWidget {
  const AnalyticsDashboard({super.key});

  @override
  _AnalyticsDashboardState createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  final Logger _logger = Logger('AnalyticsDashboard');
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller = context.read<AnalyticsController>();
      await controller.initialize();
      setState(() => _isInitialized = true);
      _logger.info('Analytics dashboard initialized');
    } catch (e) {
      _logger.error('Failed to initialize dashboard', error: e);
      // Handle error appropriately
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<AnalyticsController>().loadMetrics();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
      ),
      body: _isInitialized ? _buildDashboard() : _buildLoading(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildDashboard() {
    return Consumer<AnalyticsController>(
      builder: (context, controller, child) {
        if (controller.isLoading && !_isInitialized) {
          return _buildLoading();
        }

        return RefreshIndicator(
          onRefresh: () => controller.loadMetrics(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusBar(controller),
                const SizedBox(height: 16),
                _buildFilterPanel(controller),
                const SizedBox(height: 24),
                _buildMetricsGrid(controller),
                const SizedBox(height: 24),
                _buildChartsSection(controller),
                const SizedBox(height: 24),
                _buildQuickActions(controller),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBar(AnalyticsController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              controller.isOnline ? Icons.wifi : Icons.wifi_off,
              color: controller.isOnline ? Colors.green : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              controller.isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                color: controller.isOnline ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (controller.error != null)
              Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    'Error',
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPanel(AnalyticsController controller) {
    return AnalyticsFilterPanel(
      initialQuery: controller.currentQuery,
      onFilterChanged: (query) {
        controller.updateQuery(query);
        controller.loadMetrics();
      },
      availableCategories: const [], // Load from your data
      availableSegments: const [], // Load from your data
    );
  }

  Widget _buildMetricsGrid(AnalyticsController controller) {
    final metrics = controller.metrics;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.8,
      children: [
        MetricCard(
          title: 'Total Revenue',
          value: metrics.totalRevenue,
          subtitle: 'All-time revenue',
          icon: Icons.attach_money,
          color: Colors.green,
          trend: metrics.revenueGrowth,
          isCurrency: true,
        ),
        MetricCard(
          title: 'Total Orders',
          value: metrics.totalOrders.toDouble(),
          subtitle: 'Number of transactions',
          icon: Icons.shopping_cart,
          color: Colors.blue,
          trend: 0.0, // Would need historical data
        ),
        MetricCard(
          title: 'Avg Order Value',
          value: metrics.averageOrderValue,
          subtitle: 'Average per transaction',
          icon: Icons.trending_up,
          color: Colors.purple,
          trend: 0.0,
          isCurrency: true,
        ),
        MetricCard(
          title: 'Conversion Rate',
          value: metrics.conversionRate,
          valueSuffix: '%',
          subtitle: 'Customer conversion',
          icon: Icons.people,
          color: Colors.orange,
          trend: 0.0,
        ),
      ],
    );
  }

  Widget _buildChartsSection(AnalyticsController controller) {
    // Placeholder chart data - in production, use real data
    final chartData = [
      TimeSeriesData(
        timestamp: DateTime.now().subtract(const Duration(days: 6)),
        value: 1200,
        label: 'Mon',
      ),
      TimeSeriesData(
        timestamp: DateTime.now().subtract(const Duration(days: 5)),
        value: 1800,
        label: 'Tue',
      ),
      TimeSeriesData(
        timestamp: DateTime.now().subtract(const Duration(days: 4)),
        value: 1500,
        label: 'Wed',
      ),
      TimeSeriesData(
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        value: 2200,
        label: 'Thu',
      ),
      TimeSeriesData(
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        value: 1900,
        label: 'Fri',
      ),
      TimeSeriesData(
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        value: 2500,
        label: 'Sat',
      ),
      TimeSeriesData(
        timestamp: DateTime.now(),
        value: 2100,
        label: 'Sun',
      ),
    ];

    return AnalyticsChart(
      title: 'Weekly Revenue Trend',
      data: chartData,
      type: ChartType.line,
      yAxisTitle: 'Revenue (\$)',
      xAxisTitle: 'Day',
      onChartTapped: () {
        // Navigate to detailed view
      },
    );
  }

  Widget _buildQuickActions(AnalyticsController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
              children: [
                _buildActionButton(
                  icon: Icons.bar_chart,
                  label: 'Sales Report',
                  color: Colors.blue,
                  onTap: () => _generateReport(controller, 'sales'),
                ),
                _buildActionButton(
                  icon: Icons.inventory,
                  label: 'Inventory',
                  color: Colors.green,
                  onTap: () => _generateReport(controller, 'inventory'),
                ),
                _buildActionButton(
                  icon: Icons.people,
                  label: 'Customers',
                  color: Colors.purple,
                  onTap: () => _generateReport(controller, 'customer'),
                ),
                _buildActionButton(
                  icon: Icons.download,
                  label: 'Export',
                  color: Colors.orange,
                  onTap: _exportData,
                ),
                _buildActionButton(
                  icon: Icons.history,
                  label: 'History',
                  color: Colors.teal,
                  onTap: _viewHistory,
                ),
                _buildActionButton(
                  icon: Icons.settings,
                  label: 'Settings',
                  color: Colors.grey,
                  onTap: _openSettings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _generateReport(AnalyticsController controller, String reportType) {
    if (controller.isGeneratingReport) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Report'),
        content: const Text('This will generate a detailed report. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (reportType == 'sales') {
                await controller.generateSalesReport();
                // Navigate to report view
              } else if (reportType == 'inventory') {
                await controller.generateInventoryReport();
              }
            },
            child: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    // Show export options dialog
    showDialog(
      context: context,
      builder: (context) => ExportOptionsDialog(
        initialConfig: ExportConfig(format: ExportFormat.csv),
        onExport: (config) {
          Navigator.pop(context);
          // Handle export
        },
      ),
    );
  }

  void _viewHistory() {
    // Navigate to history screen
    _logger.info('Navigating to history');
  }

  void _openSettings() {
    // Navigate to settings screen
    _logger.info('Navigating to settings');
  }
}