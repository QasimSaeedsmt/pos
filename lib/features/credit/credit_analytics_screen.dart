import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../constants.dart';
import 'credit_models.dart';
import 'credit_service.dart';

class CreditAnalyticsScreen extends StatefulWidget {
  final CreditService creditService;

  const CreditAnalyticsScreen({super.key, required this.creditService});

  @override
  _CreditAnalyticsScreenState createState() => _CreditAnalyticsScreenState();
}

class _CreditAnalyticsScreenState extends State<CreditAnalyticsScreen> {
  List<CreditSummary> _customers = [];
  List<CreditTransaction> _recentTransactions = [];
  List<CreditTransaction> _allTransactions = [];
  bool _isLoading = true;
  final Map<String, List<CreditTransaction>> _customerTransactions = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final customers = await widget.creditService.getAllCreditCustomers();
      final transactions = await widget.creditService.getAllTransactions();

      // Group transactions by customer
      final Map<String, List<CreditTransaction>> customerTransactionsMap = {};
      for (var transaction in transactions) {
        if (!customerTransactionsMap.containsKey(transaction.customerId)) {
          customerTransactionsMap[transaction.customerId] = [];
        }
        customerTransactionsMap[transaction.customerId]!.add(transaction);
      }

      setState(() {
        _customers = customers;
        _recentTransactions = transactions.take(50).toList();
        _allTransactions = transactions;
        _customerTransactions.addAll(customerTransactionsMap);
      });
    } catch (e) {
      _showError('Failed to load data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Analytics calculations
  double get _totalOutstanding => _customers.fold(0.0, (sum, c) => sum + c.currentBalance);
  double get _totalOverdue => _customers.fold(0.0, (sum, c) => sum + c.overdueAmount);
  int get _overdueCustomers => _customers.where((c) => c.overdueAmount > 0).length;
  double get _averageBalance => _customers.isEmpty ? 0 : _totalOutstanding / _customers.length;
  double get _totalCreditGiven => _customers.fold(0.0, (sum, c) => sum + c.totalCreditGiven);
  double get _totalCreditPaid => _customers.fold(0.0, (sum, c) => sum + c.totalCreditPaid);

  // Chart data
  List<ChartData> get _balanceDistributionData {
    final List<Map<String, dynamic>> ranges = [
      {'min': 0.0, 'max': 1000.0, 'label': '0-1K'},
      {'min': 1000.0, 'max': 5000.0, 'label': '1K-5K'},
      {'min': 5000.0, 'max': 10000.0, 'label': '5K-10K'},
      {'min': 10000.0, 'max': double.infinity, 'label': '10K+'},
    ];

    return ranges.map<ChartData>((range) {
      final count = _customers.where((c) =>
      c.currentBalance >= (range['min'] as num) &&
          c.currentBalance < (range['max'] as num)
      ).length;
      return ChartData(range['label'] as String, count.toDouble());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Credit Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: _generateFullPdfReport,
                child: Text('Generate Full Report'),
              ),
              PopupMenuItem(
                onTap: _generateCustomerStatements,
                child: Text('Customer Statements'),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading Credit Analytics...'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Customers'),
              Tab(text: 'Transactions'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildDashboardTab(),
                _buildCustomersTab(),
                _buildTransactionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKeyMetrics(),
          SizedBox(height: 20),
          _buildChartsSection(),
          SizedBox(height: 20),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildCustomersTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Credit Customers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Text(
                '${_customers.length} customers',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _customers.length,
            itemBuilder: (context, index) {
              final customer = _customers[index];
              return _buildCustomerItem(customer);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsTab() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'All Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              Text(
                '${_allTransactions.length} transactions',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _allTransactions.length,
            itemBuilder: (context, index) {
              final transaction = _allTransactions[index];
              return _buildTransactionItem(transaction);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKeyMetrics() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Credit Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildMetricCard(
                  'Total Outstanding',
                  '${Constants.CURRENCY_NAME}${_totalOutstanding.toStringAsFixed(0)}',
                  Icons.attach_money,
                  Colors.blue,
                ),
                _buildMetricCard(
                  'Total Overdue',
                  '${Constants.CURRENCY_NAME}${_totalOverdue.toStringAsFixed(0)}',
                  Icons.warning,
                  Colors.orange,
                ),
                _buildMetricCard(
                  'Credit Customers',
                  _customers.length.toString(),
                  Icons.people,
                  Colors.green,
                ),
                _buildMetricCard(
                  'Overdue Customers',
                  _overdueCustomers.toString(),
                  Icons.schedule,
                  Colors.red,
                ),
                _buildMetricCard(
                  'Average Balance',
                  '${Constants.CURRENCY_NAME}${_averageBalance.toStringAsFixed(0)}',
                  Icons.bar_chart,
                  Colors.purple,
                ),
                _buildMetricCard(
                  'Total Credit Given',
                  '${Constants.CURRENCY_NAME}${_totalCreditGiven.toStringAsFixed(0)}',
                  Icons.trending_up,
                  Colors.teal,
                ),
                _buildMetricCard(
                  'Total Credit Paid',
                  '${Constants.CURRENCY_NAME}${_totalCreditPaid.toStringAsFixed(0)}',
                  Icons.payment,
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 150,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Balance Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                series: <ColumnSeries<ChartData, String>>[
                  ColumnSeries<ChartData, String>(
                    dataSource: _balanceDistributionData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    color: Colors.blue,
                    dataLabelSettings: DataLabelSettings(isVisible: true),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerItem(CreditSummary customer) {
    final customerTransactions = _customerTransactions[customer.customerId] ?? [];

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(customer.customerName[0]),
        ),
        title: Text(
          customer.customerName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Balance: ${Constants.CURRENCY_NAME}${customer.currentBalance.toStringAsFixed(2)}'),
            Text('Credit Limit: ${Constants.CURRENCY_NAME}${customer.creditLimit.toStringAsFixed(2)}'),
            Text('Available: ${Constants.CURRENCY_NAME}${customer.availableCredit.toStringAsFixed(2)}'),
            if (customer.overdueAmount > 0)
              Text(
                'Overdue: ${Constants.CURRENCY_NAME}${customer.overdueAmount.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.red),
              ),
            Text('Transactions: ${customer.totalTransactions}'),
            Text('Utilization: ${customer.utilizationRate.toStringAsFixed(1)}%'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.visibility, size: 20),
              onPressed: () => _viewCustomerDetails(customer),
              tooltip: 'View Details',
            ),
            IconButton(
              icon: Icon(Icons.picture_as_pdf, size: 20),
              onPressed: () => _generateCustomerStatement(customer),
              tooltip: 'Generate Statement',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(CreditTransaction transaction) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: _getTransactionIcon(transaction.type),
        title: Text(
          transaction.customerName,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM dd, yyyy - HH:mm').format(transaction.transactionDate)),
            Text(
              _getTransactionTypeLabel(transaction.type),
              style: TextStyle(
                color: _getTransactionColor(transaction.type),
                fontWeight: FontWeight.w500,
              ),
            ),
            // ADD THIS: Show product info if available
            if (transaction.hasProductDetails)
              Text(
                '${transaction.productDetails!.length} product(s)',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            if (transaction.notes != null && transaction.notes!.isNotEmpty)
              Text(
                transaction.notes!,
                style: TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (transaction.isOverdue)
              Text(
                'Overdue: ${transaction.daysOverdue} days',
                style: TextStyle(fontSize: 12, color: Colors.red),
              ),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${Constants.CURRENCY_NAME}${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getTransactionColor(transaction.type),
              ),
            ),
            Text(
              'Balance: ${Constants.CURRENCY_NAME}${transaction.newBalance.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        onTap: () => _viewTransactionDetails(transaction),
      ),
    );
  }
  Widget _buildRecentActivity() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Recent Transactions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                TextButton(
                  onPressed: () {
                    DefaultTabController.of(context).animateTo(2);
                  },
                  child: Text('View All'),
                ),
              ],
            ),
            SizedBox(height: 12),
            ..._recentTransactions.take(10).map((transaction) =>
                _buildActivityItem(transaction)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(CreditTransaction transaction) {
    return ListTile(
      leading: _getTransactionIcon(transaction.type),
      title: Text(transaction.customerName),
      subtitle: Text(
        '${_getTransactionTypeLabel(transaction.type)} • ${DateFormat('MMM dd, yyyy').format(transaction.transactionDate)}',
      ),
      trailing: Text(
        '${Constants.CURRENCY_NAME}${transaction.amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _getTransactionColor(transaction.type),
        ),
      ),
      onTap: () => _viewTransactionDetails(transaction),
    );
  }

  // Helper methods for transaction display
  Icon _getTransactionIcon(String type) {
    switch (type) {
      case 'payment':
        return Icon(Icons.payment, color: Colors.green);
      case 'credit_sale':
        return Icon(Icons.shopping_cart, color: Colors.blue);
      case 'adjustment':
        return Icon(Icons.adjust, color: Colors.orange);
      default:
        return Icon(Icons.receipt, color: Colors.grey);
    }
  }

  String _getTransactionTypeLabel(String type) {
    switch (type) {
      case 'payment':
        return 'Payment';
      case 'credit_sale':
        return 'Credit Sale';
      case 'adjustment':
        return 'Adjustment';
      default:
        return type;
    }
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'payment':
        return Colors.green;
      case 'credit_sale':
        return Colors.blue;
      case 'adjustment':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // View Details Methods
  void _viewCustomerDetails(CreditSummary customer) {
    final customerTransactions = _customerTransactions[customer.customerId] ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Customer Details - ${customer.customerName}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Customer ID', customer.customerId),
              _buildDetailRow('Current Balance', '${Constants.CURRENCY_NAME}${customer.currentBalance.toStringAsFixed(2)}'),
              _buildDetailRow('Credit Limit', '${Constants.CURRENCY_NAME}${customer.creditLimit.toStringAsFixed(2)}'),
              _buildDetailRow('Available Credit', '${Constants.CURRENCY_NAME}${customer.availableCredit.toStringAsFixed(2)}'),
              _buildDetailRow('Utilization Rate', '${customer.utilizationRate.toStringAsFixed(1)}%'),
              _buildDetailRow('Total Credit Given', '${Constants.CURRENCY_NAME}${customer.totalCreditGiven.toStringAsFixed(2)}'),
              _buildDetailRow('Total Credit Paid', '${Constants.CURRENCY_NAME}${customer.totalCreditPaid.toStringAsFixed(2)}'),
              _buildDetailRow('Total Transactions', customer.totalTransactions.toString()),
              if (customer.overdueAmount > 0)
                _buildDetailRow('Overdue Amount', '${Constants.CURRENCY_NAME}${customer.overdueAmount.toStringAsFixed(2)}'),
              if (customer.overdueCount > 0)
                _buildDetailRow('Overdue Transactions', customer.overdueCount.toString()),
              if (customer.lastTransactionDate != null)
                _buildDetailRow('Last Transaction', DateFormat('MMM dd, yyyy').format(customer.lastTransactionDate!)),
              if (customer.lastPaymentDate != null)
                _buildDetailRow('Last Payment', DateFormat('MMM dd, yyyy').format(customer.lastPaymentDate!)),

              SizedBox(height: 16),
              Text(
                'Recent Transactions (${customerTransactions.length})',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              ...customerTransactions.take(10).map((transaction) =>
                  ListTile(
                    dense: true,
                    leading: _getTransactionIcon(transaction.type),
                    title: Text(
                      '${_getTransactionTypeLabel(transaction.type)} • ${DateFormat('MMM dd, yyyy').format(transaction.transactionDate)}',
                      style: TextStyle(fontSize: 12),
                    ),
                    subtitle: transaction.notes != null ?
                    Text(transaction.notes!, style: TextStyle(fontSize: 10)) :
                    (transaction.hasProductDetails ?
                    Text('${transaction.productDetails!.length} product(s)', style: TextStyle(fontSize: 10, color: Colors.blue)) : null),
                    trailing: Text(
                      '${Constants.CURRENCY_NAME}${transaction.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getTransactionColor(transaction.type),
                      ),
                    ),
                  )
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _generateCustomerStatement(customer);
            },
            child: Text('Generate PDF'),
          ),
        ],
      ),
    );
  }

  void _viewTransactionDetails(CreditTransaction transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transaction Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Transaction ID', transaction.id),
              _buildDetailRow('Customer', transaction.customerName),
              _buildDetailRow('Customer Email', transaction.customerEmail),
              _buildDetailRow('Date', DateFormat('MMM dd, yyyy - HH:mm').format(transaction.transactionDate)),
              _buildDetailRow('Type', _getTransactionTypeLabel(transaction.type)),
              _buildDetailRow('Amount', '${Constants.CURRENCY_NAME}${transaction.amount.toStringAsFixed(2)}'),
              _buildDetailRow('Previous Balance', '${Constants.CURRENCY_NAME}${transaction.previousBalance.toStringAsFixed(2)}'),
              _buildDetailRow('New Balance', '${Constants.CURRENCY_NAME}${transaction.newBalance.toStringAsFixed(2)}'),
              if (transaction.orderId != null && transaction.orderId!.isNotEmpty)
                _buildDetailRow('Order ID', transaction.orderId!),
              if (transaction.invoiceNumber != null && transaction.invoiceNumber!.isNotEmpty)
                _buildDetailRow('Invoice Number', transaction.invoiceNumber!),
              if (transaction.paymentMethod != null && transaction.paymentMethod!.isNotEmpty)
                _buildDetailRow('Payment Method', transaction.paymentMethod!),
              if (transaction.notes != null && transaction.notes!.isNotEmpty)
                _buildDetailRow('Notes', transaction.notes!),
              if (transaction.dueDate != null)
                _buildDetailRow('Due Date', DateFormat('MMM dd, yyyy').format(transaction.dueDate!)),
              if (transaction.isOverdue)
                _buildDetailRow('Days Overdue', '${transaction.daysOverdue} days'),
              if (transaction.createdBy != null && transaction.createdBy!.isNotEmpty)
                _buildDetailRow('Created By', transaction.createdBy!),
              if (transaction.createdDate != null)
                _buildDetailRow('Created Date', DateFormat('MMM dd, yyyy').format(transaction.createdDate!)),

              // PRODUCT DETAILS SECTION - ADD THIS
              if (transaction.hasProductDetails) ...[
                SizedBox(height: 16),
                Text(
                  'Products Purchased (${transaction.productDetails!.length} items)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                ...transaction.productDetails!.map((product) =>
                    Card(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.productName,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (product.productDescription != null)
                              Text(
                                product.productDescription!,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Quantity: ${product.quantity}'),
                                Text('Unit Price: ${Constants.CURRENCY_NAME}${product.unitPrice.toStringAsFixed(2)}'),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (product.discount != null && product.discount! > 0)
                                  Text('Discount: ${Constants.CURRENCY_NAME}${product.discount!.toStringAsFixed(2)}'),
                                Text(
                                  'Total: ${Constants.CURRENCY_NAME}${product.totalPrice.toStringAsFixed(2)}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            if (product.sku != null)
                              Text('SKU: ${product.sku!}', style: TextStyle(fontSize: 10)),
                            if (product.productCategory != null)
                              Text('Category: ${product.productCategory!}', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    )
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // Enhanced PDF Generation Methods with Product Information
  Future<void> _generateFullPdfReport() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            _buildPdfHeader('Credit Analytics Report'),
            _buildPdfSummary(),
            _buildPdfCustomerSummary(),
            _buildPdfRecentTransactions(),
            _buildPdfBalanceDistribution(),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      _showError('Failed to generate PDF: $e');
    }
  }

  Future<void> _generateCustomerStatements() async {
    try {
      for (final customer in _customers) {
        await _generateCustomerStatement(customer);
      }
    } catch (e) {
      _showError('Failed to generate statements: $e');
    }
  }

  Future<void> _generateCustomerStatement(CreditSummary customer) async {
    try {
      final customerTransactions = _customerTransactions[customer.customerId] ?? [];
      customerTransactions.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            _buildPdfHeader('Customer Statement - ${customer.customerName}'),
            _buildPdfCustomerDetails(customer),
            _buildPdfCustomerTransactions(customerTransactions, customer),
            _buildPdfAccountSummary(customer, customerTransactions),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      _showError('Failed to generate statement: $e');
    }
  }

  pw.Widget _buildPdfHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              DateFormat('yyyy-MM-dd').format(DateTime.now()),
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
            ),
          ],
        ),
        pw.Text(
          'Generated on: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPdfSummary() {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Credit Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(child: pw.Text('Metric', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Value', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Total Outstanding'), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${_totalOutstanding.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Total Overdue'), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${_totalOverdue.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Credit Customers'), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text(_customers.length.toString()), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Overdue Customers'), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text(_overdueCustomers.toString()), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Average Balance'), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${_averageBalance.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Total Credit Given'), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${_totalCreditGiven.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Total Credit Paid'), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${_totalCreditPaid.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfCustomerSummary() {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Customer Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(2),
              3: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(child: pw.Text('Customer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Balance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Overdue', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Credit Limit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              ..._customers.map((customer) => pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text(customer.customerName), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${customer.currentBalance.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${customer.overdueAmount.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${customer.creditLimit.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfCustomerDetails(CreditSummary customer) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Account Details',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Customer Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text(customer.customerName), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Customer ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text(customer.customerId), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Current Balance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${customer.currentBalance.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Overdue Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${customer.overdueAmount.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Credit Limit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${customer.creditLimit.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Available Credit', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${customer.availableCredit.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Utilization Rate', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${customer.utilizationRate.toStringAsFixed(1)}%'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Total Transactions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text(customer.totalTransactions.toString()), padding: pw.EdgeInsets.all(6)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfCustomerTransactions(List<CreditTransaction> transactions, CreditSummary customer) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Transaction History',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: {
              0: pw.FlexColumnWidth(1.5),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1.5),
              5: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Balance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Reference', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              ...transactions.take(50).map((transaction) => pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text(DateFormat('MM/dd/yyyy').format(transaction.transactionDate)), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text(_getTransactionTypeLabel(transaction.type)), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${transaction.amount.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${transaction.newBalance.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text(transaction.invoiceNumber ?? transaction.orderId ?? '-'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text(transaction.notes ?? (transaction.hasProductDetails ? '${transaction.productDetails!.length} product(s)' : '-'), maxLines: 2), padding: pw.EdgeInsets.all(4)),
                ],
              )),
            ],
          ),
          // Add product details for credit sales
          ...transactions.where((t) => t.hasProductDetails).take(10).map((transaction) =>
              _buildPdfProductDetails(transaction)
          ),
          if (transactions.length > 50)
            pw.Padding(
              padding: pw.EdgeInsets.all(8),
              child: pw.Text(
                '... and ${transactions.length - 50} more transactions',
                style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfProductDetails(CreditTransaction transaction) {
    if (!transaction.hasProductDetails) return pw.SizedBox();

    return pw.Container(
      margin: pw.EdgeInsets.only(top: 10, bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Products for ${DateFormat('MM/dd/yyyy').format(transaction.transactionDate)} - ${_getTransactionTypeLabel(transaction.type)}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  pw.Padding(child: pw.Text('Product', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('Unit Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('Discount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), padding: pw.EdgeInsets.all(4)),
                ],
              ),
              ...transaction.productDetails!.map((product) => pw.TableRow(
                children: [
                  pw.Padding(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(product.productName, style: pw.TextStyle(fontSize: 9)),
                        if (product.sku != null) pw.Text('SKU: ${product.sku!}', style: pw.TextStyle(fontSize: 8)),
                        if (product.productCategory != null) pw.Text('Category: ${product.productCategory!}', style: pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                    padding: pw.EdgeInsets.all(4),
                  ),
                  pw.Padding(child: pw.Text(product.quantity.toString(), style: pw.TextStyle(fontSize: 9)), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${product.unitPrice.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text(product.discount != null ? '${Constants.CURRENCY_NAME}${product.discount!.toStringAsFixed(2)}' : '-', style: pw.TextStyle(fontSize: 9)), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${product.totalPrice.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9)), padding: pw.EdgeInsets.all(4)),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }
  pw.Widget _buildPdfAccountSummary(CreditSummary customer, List<CreditTransaction> transactions) {
    final totalPayments = transactions.where((t) => t.isPayment).fold(0.0, (sum, t) => sum + t.amount);
    final totalCreditSales = transactions.where((t) => t.isCredit).fold(0.0, (sum, t) => sum + t.amount);
    final totalAdjustments = transactions.where((t) => t.type == 'adjustment').fold(0.0, (sum, t) => sum + t.amount);
    final lastPayment = transactions.where((t) => t.isPayment).isNotEmpty ?
    transactions.where((t) => t.isPayment).first.transactionDate : null;

    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Account Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Total Credit Sales', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${totalCreditSales.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Total Payments', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${totalPayments.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Total Adjustments', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${totalAdjustments.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Current Balance', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${customer.currentBalance.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              if (lastPayment != null)
                pw.TableRow(
                  children: [
                    pw.Padding(child: pw.Text('Last Payment Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                    pw.Padding(child: pw.Text(DateFormat('MMM dd, yyyy').format(lastPayment)), padding: pw.EdgeInsets.all(6)),
                  ],
                ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Statement Period', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Up to ${DateFormat('MMM dd, yyyy').format(DateTime.now())}'), padding: pw.EdgeInsets.all(6)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfRecentTransactions() {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Recent Activity',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(2),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(child: pw.Text('Customer', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Date', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Reference', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              ..._recentTransactions.take(20).map((transaction) => pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text(transaction.customerName), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text(DateFormat('MM/dd/yyyy').format(transaction.transactionDate)), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text(_getTransactionTypeLabel(transaction.type)), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${transaction.amount.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text(transaction.invoiceNumber ?? transaction.orderId ?? '-'), padding: pw.EdgeInsets.all(4)),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfBalanceDistribution() {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Balance Distribution',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(child: pw.Text('Balance Range', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text('Customers', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), padding: pw.EdgeInsets.all(6)),
                ],
              ),
              ..._balanceDistributionData.map((data) => pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text(data.x), padding: pw.EdgeInsets.all(6)),
                  pw.Padding(child: pw.Text(data.y.toInt().toString()), padding: pw.EdgeInsets.all(6)),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class ChartData {
  final String x;
  final double y;

  ChartData(this.x, this.y);
}