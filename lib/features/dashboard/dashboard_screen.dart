// dashboard_screen.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../../theme_utils.dart';
import 'dashboard_models.dart';
import 'dashboard_provider.dart';
import 'dashboard_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late DashboardProvider _dashboardProvider;

  @override
  void initState() {
    super.initState();
    _initAnimations();

    _dashboardProvider = DashboardProvider(
      repository: DashboardRepository(),
      connectivity: Connectivity(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider =
      Provider.of<MyAuthProvider>(context, listen: false);

      final tenantId = authProvider.currentUser?.tenantId;

      if (tenantId != null && tenantId.isNotEmpty) {
        _dashboardProvider.loadDashboard(tenantId);
      }
    });
  }


  void _initAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final tenantId = authProvider.currentUser?.tenantId ?? '';

    return ChangeNotifierProvider.value(
      value: _dashboardProvider,

      child: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          return Scaffold(
            backgroundColor: Colors.grey[50],
            body: _buildDashboardContent(context, provider, tenantId),
          );
        },
      ),
    );
  }

  Widget _buildDashboardContent(
      BuildContext context,
      DashboardProvider provider,
      String tenantId,
      ) {
    if (provider.isLoading && provider.dashboardData == null) {
      return _buildLoadingState(provider.isOnline);
    }

    final dashboardData = provider.dashboardData;

    if (dashboardData == null && provider.error != null) {
      return _buildErrorState(provider.error!, provider, tenantId);
    }

    if (dashboardData == null) {
      return _buildEmptyState(provider, tenantId);
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: RefreshIndicator(
              onRefresh: provider.isOnline
                  ? () async => provider.refreshDashboard(tenantId)
                  : () async {},

              child: CustomScrollView(
                slivers: [
                  _buildHeader(context, provider, dashboardData),
                  _buildStatsGrid(dashboardData.stats),
                  _buildRevenueChart(dashboardData.revenueData),
                  _buildProductPerformance(dashboardData.productPerformance),
                  _buildInventoryInsights(dashboardData),
                  SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  double _calculateInventoryHealth(DashboardStats stats) {
    if (stats.totalProducts == 0) return 0.0;
    return ((stats.totalProducts - stats.lowStockProducts) / stats.totalProducts) * 100;
  }

  Color _getInventoryHealthColor(double health) {
    if (health >= 80) return Colors.green;
    if (health >= 50) return Colors.orange;
    return Colors.red;
  }

  String _getInventoryHealthLabel(double health) {
    if (health >= 80) return 'Healthy';
    if (health >= 50) return 'Warning';
    return 'Critical';
  }

  // ========== HEADER SECTION ==========
  SliverToBoxAdapter _buildHeader(
      BuildContext context,
      DashboardProvider provider,
      DashboardCache dashboardData,
      ) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: ThemeUtils.appBar(context),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good ${_getGreeting()},',
                        style: ThemeUtils.bodyLarge(context).copyWith(
                          color: ThemeUtils.textOnPrimary(context).withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Dashboard Overview',
                        style: ThemeUtils.headlineLarge(context).copyWith(
                          color: ThemeUtils.textOnPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildStatusIndicator(provider.isOnline),
                          const SizedBox(width: 12),
                          _buildLastUpdated(dashboardData.lastUpdated),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (provider.isOnline)
                      provider.isRefreshing
                          ? CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          ThemeUtils.textOnPrimary(context),
                        ),
                      )
                          : IconButton(
                        icon: Icon(Icons.refresh, color: ThemeUtils.textOnPrimary(context)),
                        tooltip: 'Refresh Data',
                        onPressed: () => provider.refreshDashboard(dashboardData.tenantId),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildQuickStatsBar(dashboardData.stats),
          ],
        ),
      ),
    );
  }


  Widget _buildStatusIndicator(bool isOnline) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isOnline ? Colors.green[400] : Colors.orange[400],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? Colors.green[400]! : Colors.orange[400]!)
                .withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6),
          Text(
            isOnline ? 'Live Data' : 'Offline Mode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isOnline) ...[
            SizedBox(width: 4),
            Icon(Icons.wifi_off, size: 12, color: Colors.white),
          ],
        ],
      ),
    );
  }

  Widget _buildLastUpdated(DateTime lastUpdated) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);
    String timeText;

    if (difference.inMinutes < 1) {
      timeText = 'Just now';
    } else if (difference.inMinutes < 60) {
      timeText = '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      timeText = '${difference.inHours}h ago';
    } else {
      timeText = DateFormat('MMM d').format(lastUpdated);
    }

    return Text(
      'Updated $timeText',
      style: TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 12,
      ),
    );
  }

  Widget _buildQuickStatsBar(DashboardStats stats) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _QuickStatItem(
            value: stats.todaySales.toString(),
            label: 'Today Sales',
            icon: Icons.shopping_cart,
          ),
          _QuickStatItem(
            value: '${Constants.CURRENCY_NAME}${stats.todayRevenue.toStringAsFixed(0)}',
            label: "Today's Revenue",
            icon: Icons.attach_money,
          ),
          _QuickStatItem(
            value: stats.pendingOrders.toString(),
            label: 'Pending Orders',
            icon: Icons.pending_actions,
          ),
          _QuickStatItem(
            value: stats.lowStockProducts.toString(),
            label: 'Low Stock',
            icon: Icons.warning,
          ),
        ],
      ),
    );
  }

  // ========== STATS GRID ==========
  SliverToBoxAdapter _buildStatsGrid(DashboardStats stats) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _StatCard(
              title: 'Total Revenue',
              value: '${Constants.CURRENCY_NAME}${stats.totalRevenue.toStringAsFixed(0)}',
              subtitle: '${Constants.CURRENCY_NAME}${stats.todayRevenue.toStringAsFixed(0)} today',
              icon: Icons.attach_money,
              color: Colors.green,
              trend: stats.revenueGrowth,
            ),
            _StatCard(
              title: 'Total Sales',
              value: stats.totalSales.toString(),
              subtitle: '${stats.todaySales} today',
              icon: Icons.shopping_cart,
              color: Colors.blue,
              trend: stats.salesGrowth,
            ),
            _StatCard(
              title: 'Inventory Value',
              value: '${Constants.CURRENCY_NAME}${stats.inventoryValue.toStringAsFixed(0)}',
              subtitle: 'Stock worth',
              icon: Icons.inventory,
              color: Colors.purple,
              trend: 0.0,
            ),
            _StatCard(
              title: 'Conversion Rate',
              value: '${stats.conversionRate.toStringAsFixed(1)}%',
              subtitle: 'Customer conversion',
              icon: Icons.people,
              color: Colors.orange,
              trend: 0.0,
            ),
          ],
        ),
      ),
    );
  }

  // ========== REVENUE CHART ==========
  SliverToBoxAdapter _buildRevenueChart(List<RevenueDataPoint> revenueData) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Revenue Trend (Last 7 Days)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Weekly',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: SfCartesianChart(
                  margin: EdgeInsets.zero,
                  plotAreaBorderWidth: 0,
                  primaryXAxis: CategoryAxis(
                    majorGridLines: MajorGridLines(width: 0),
                    labelStyle: TextStyle(fontSize: 11),
                  ),
                  primaryYAxis: NumericAxis(
                    numberFormat: NumberFormat.compactCurrency(
                      symbol: Constants.CURRENCY_NAME,
                    ),
                    majorGridLines: MajorGridLines(
                      width: 1,
                      color: Colors.grey[100],
                    ),
                    labelStyle: TextStyle(fontSize: 11),
                  ),
                  series: <CartesianSeries>[
                    ColumnSeries<RevenueDataPoint, String>(
                      dataSource: revenueData,
                      xValueMapper: (RevenueDataPoint data, _) =>
                          DateFormat('E').format(data.date),
                      yValueMapper: (RevenueDataPoint data, _) => data.revenue,
                      color: Colors.blueAccent.shade400,
                      width: 0.6,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMetricItem(
                    'Avg. Order',
                    '${Constants.CURRENCY_NAME}${_calculateAverageOrderValue(revenueData).toStringAsFixed(0)}',
                  ),
                  _buildMetricItem(
                    'Total Orders',
                    revenueData.fold(0, (sum, data) => sum + data.orders).toString(),
                  ),
                  _buildMetricItem(
                    'Customers',
                    revenueData.fold(0, (sum, data) => sum + data.customers).toString(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateAverageOrderValue(List<RevenueDataPoint> data) {
    final totalOrders = data.fold(0, (sum, item) => sum + item.orders);
    final totalRevenue = data.fold(0.0, (sum, item) => sum + item.revenue);
    return totalOrders > 0 ? totalRevenue / totalOrders : 0;
  }

  // ========== PRODUCT PERFORMANCE ==========
  SliverToBoxAdapter _buildProductPerformance(List<ProductPerformance> products) {
    final List<ProductPerformance> topProducts = products.take(5).toList();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Product Performance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Top ${topProducts.length}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              /// Empty State
              if (topProducts.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'No product performance data available',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                )
              else
                Column(
                  children: topProducts
                      .map((product) => _buildProductItem(product))
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductItem(ProductPerformance product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  product.sku,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${Constants.CURRENCY_NAME}${product.revenue.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.shopping_cart, size: 12, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    '${product.quantitySold} sold',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.inventory, size: 12, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    '${product.stockQuantity} in stock',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========== INVENTORY INSIGHTS ==========
  SliverToBoxAdapter _buildInventoryInsights(DashboardCache dashboardData) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inventory Insights',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInventoryMetric(
                      'Total Products',
                      dashboardData.stats.totalProducts.toString(),
                      Icons.category,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildInventoryMetric(
                      'Low Stock',
                      dashboardData.stats.lowStockProducts.toString(),
                      Icons.warning,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInventoryMetric(
                      'Inventory Value',
                      '${Constants.CURRENCY_NAME}${dashboardData.stats.inventoryValue.toStringAsFixed(0)}',
                      Icons.assessment,
                      Colors.green,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildInventoryMetric(
                      'Pending Sync',
                      '${dashboardData.stats.pendingOrders + dashboardData.stats.pendingReturns} items',
                      Icons.sync,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryMetric(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ========== LOADING/ERROR STATES ==========
  Widget _buildLoadingState(bool isOnline) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(
                isOnline ? Colors.blue[700]! : Colors.orange[700]!,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            isOnline ? 'Loading Dashboard...' : 'Loading Offline Data...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            isOnline ? 'Fetching from your database' : 'Using locally stored data',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          if (!isOnline) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Colors.orange[700]),
                  SizedBox(width: 8),
                  Text(
                    'Offline Mode',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, DashboardProvider provider, String tenantId) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            SizedBox(height: 20),
            Text(
              'Unable to Load Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.loadDashboard(tenantId),
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => provider.clearCache(tenantId),
              icon: Icon(Icons.delete_outline),
              label: Text('Clear Cache'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(DashboardProvider provider, String tenantId) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard_outlined,
              size: 64,
              color: Colors.blue[400],
            ),
            SizedBox(height: 20),
            Text(
              'Preparing your dashboard…',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Fetching your latest data',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== HELPER METHODS ==========
  Widget _buildMetricItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.blue[800],
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

// ========== WIDGET COMPONENTS ==========
class _QuickStatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _QuickStatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double trend;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;

        // Adjusted sizes (slightly smaller for more spacing)
        final double iconSize = width * 0.1;
        final double padding = width * 0.05;
        final double valueFontSize = width * 0.12; // smaller than before
        final double titleFontSize = width * 0.07;
        final double subtitleFontSize = width * 0.06;
        final double trendFontSize = width * 0.055;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: ThemeUtils.card(context),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(width * 0.08),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: width * 0.08,
                offset: Offset(0, width * 0.03),
              ),
            ],
          ),
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(padding * 0.5),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(width * 0.06),
                    ),
                    child: Icon(icon, size: iconSize, color: color),
                  ),
                  Spacer(),
                  if (trend != 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: padding * 0.4, vertical: padding * 0.2),
                      decoration: BoxDecoration(
                        color: trend >= 0
                            ? Colors.green.withOpacity(0.12)
                            : Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(width * 0.05),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            trend >= 0 ? Icons.trending_up : Icons.trending_down,
                            size: trendFontSize,
                            color: trend >= 0 ? Colors.green : Colors.red,
                          ),
                          SizedBox(width: padding * 0.2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${trend.abs().toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: trendFontSize,
                                fontWeight: FontWeight.w600,
                                color: trend >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: padding),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.bold,
                    color: ThemeUtils.textPrimary(context),
                  ),
                ),
              ),
              SizedBox(height: padding * 0.25),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w500,
                    color: ThemeUtils.textSecondary(context),
                  ),
                ),
              ),
              SizedBox(height: padding * 0.15),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: ThemeUtils.textSecondary(context).withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
