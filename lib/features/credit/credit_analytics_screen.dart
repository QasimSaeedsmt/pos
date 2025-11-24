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
  bool _isLoading = true;

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

      setState(() {
        _customers = customers;
        _recentTransactions = transactions.take(50).toList();
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
                child: Text('Generate Full Report'),
                onTap: _generateFullPdfReport,
              ),
              PopupMenuItem(
                child: Text('Customer Statements'),
                onTap: _generateCustomerStatements,
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKeyMetrics(),
          SizedBox(height: 20),
          _buildChartsSection(),
          SizedBox(height: 20),
          _buildCustomerList(),
          SizedBox(height: 20),
          _buildRecentActivity(),
        ],
      ),
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
              'Summary',
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
            Container(
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

  Widget _buildCustomerList() {
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
                  'Credit Customers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                Text(
                  '${_customers.length} customers',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 12),
            ..._customers.map((customer) => _buildCustomerItem(customer)),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerItem(CreditSummary customer) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(customer.customerName[0]),
        ),
        title: Text(customer.customerName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Balance: ${Constants.CURRENCY_NAME}${customer.currentBalance.toStringAsFixed(2)}'),
            if (customer.overdueAmount > 0)
              Text(
                'Overdue: ${Constants.CURRENCY_NAME}${customer.overdueAmount.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.picture_as_pdf, size: 20),
          onPressed: () => _generateCustomerStatement(customer),
          tooltip: 'Generate Statement',
        ),
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
            Text(
              'Recent Transactions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
      leading: Icon(
        transaction.isPayment ? Icons.payment : Icons.shopping_cart,
        color: transaction.isPayment ? Colors.green : Colors.blue,
      ),
      title: Text(transaction.customerName),
      subtitle: Text(
        DateFormat('MMM dd, yyyy').format(transaction.transactionDate),
      ),
      trailing: Text(
        '${Constants.CURRENCY_NAME}${transaction.amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: transaction.isPayment ? Colors.green : Colors.blue,
        ),
      ),
    );
  }

  // PDF Generation Methods
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
      // Get customer-specific transactions
      final customerTransactions = _recentTransactions
          .where((t) => t.customerName == customer.customerName)
          .toList();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => [
            _buildPdfHeader('Statement for ${customer.customerName}'),
            _buildPdfCustomerDetails(customer),
            _buildPdfCustomerTransactions(customerTransactions),
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
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
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
            'Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Total Outstanding'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${_totalOutstanding.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(4)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Total Overdue'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${_totalOverdue.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(4)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Credit Customers'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text(_customers.length.toString()), padding: pw.EdgeInsets.all(4)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Average Balance'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${_averageBalance.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(4)),
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
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(child: pw.Text('Customer'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('Balance'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('Overdue'), padding: pw.EdgeInsets.all(4)),
                ],
              ),
              ..._customers.map((customer) => pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text(customer.customerName), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${customer.currentBalance.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${customer.overdueAmount.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(4)),
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
            'Account Summary',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Current Balance'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${customer.currentBalance.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(4)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Overdue Amount'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${customer.overdueAmount.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(4)),
                ],
              ),
              pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text('Credit Limit'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${customer.creditLimit.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(4)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfCustomerTransactions(List<CreditTransaction> transactions) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Recent Transactions',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(),
            columnWidths: {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(child: pw.Text('Date'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('Type'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('Amount'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('Balance'), padding: pw.EdgeInsets.all(4)),
                ],
              ),
              ...transactions.take(20).map((transaction) => pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text(DateFormat('MMM dd, yyyy').format(transaction.transactionDate)), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text(transaction.isPayment ? 'Payment' : 'Sale'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${transaction.amount.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(4)),
                  // pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${transaction.balanceAfter.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(4)),
                ],
              )),
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
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  pw.Padding(child: pw.Text('Customer'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('Date'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('Type'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('Amount'), padding: pw.EdgeInsets.all(4)),
                ],
              ),
              ..._recentTransactions.take(15).map((transaction) => pw.TableRow(
                children: [
                  pw.Padding(child: pw.Text(transaction.customerName), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text(DateFormat('MMM dd, yyyy').format(transaction.transactionDate)), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text(transaction.isPayment ? 'Payment' : 'Sale'), padding: pw.EdgeInsets.all(4)),
                  pw.Padding(child: pw.Text('${Constants.CURRENCY_NAME}${transaction.amount.toStringAsFixed(2)}'), padding: pw.EdgeInsets.all(4)),
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