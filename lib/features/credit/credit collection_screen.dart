import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../customerBase/customer_base.dart';
import 'credit_models.dart';
import 'credit_service.dart';

class CreditCollectionScreen extends StatefulWidget {
  final CreditService creditService;

  const CreditCollectionScreen({super.key, required this.creditService});

  @override
  _CreditCollectionScreenState createState() => _CreditCollectionScreenState();
}

class _CreditCollectionScreenState extends State<CreditCollectionScreen> {
  List<CreditSummary> _customersWithCredit = [];
  List<CreditTransaction> _recentPayments = [];
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  Customer? _selectedCustomer;
  double _paymentAmount = 0.0;
  String _selectedPaymentMethod = 'cash';
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  // Track which customer is currently being processed to prevent double clicks
  String? _processingCustomerId;

  // Payment methods
  final List<String> _paymentMethods = [
    'cash',
    'easypaisa/bank transfer',
    'bank_transfer',
    'cheque',
    'other'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final customers = await widget.creditService.getAllCreditCustomers();
      final recentPayments = await _getRecentPayments();

      setState(() {
        _customersWithCredit = customers.where((c) => c.currentBalance > 0).toList();
        _recentPayments = recentPayments;
      });
    } catch (e) {
      _showError('Failed to load data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<CreditTransaction>> _getRecentPayments() async {
    try {
      final allTransactions = await widget.creditService.getAllTransactions();
      return allTransactions
          .where((t) => t.isPayment)
          .take(20)
          .toList();
    } catch (e) {
      return [];
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _selectCustomerForPayment(CreditSummary customerSummary) async {
    // Prevent double-clicking on the same customer
    if (_processingCustomerId == customerSummary.customerId) {
      return;
    }

    try {
      // Create minimal Customer object from CreditSummary
      final customer = Customer(
        id: customerSummary.customerId,
        firstName: customerSummary.customerName.split(' ').first,
        lastName: customerSummary.customerName.split(' ').skip(1).join(' '),
        email: '',
        phone: '',
        currentBalance: customerSummary.currentBalance,
        creditLimit: customerSummary.creditLimit,
        overdueAmount: customerSummary.overdueAmount,
      );

      setState(() {
        _selectedCustomer = customer;
        _paymentAmount = customerSummary.currentBalance;
        _amountController.text = customerSummary.currentBalance.toStringAsFixed(2);
        _processingCustomerId = customerSummary.customerId;
      });

      _showPaymentDialog();
    } catch (e) {
      _showError('Failed to load customer details: $e');
      _resetProcessingState();
    }
  }

  void _showPaymentDialog() {
    if (_selectedCustomer == null) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.payment, color: Colors.green),
                SizedBox(width: 12),
                Text(
                  'Record Payment',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer Info Card
                  _buildCustomerInfoCard(),
                  SizedBox(height: 20),

                  // Payment Amount Section
                  _buildPaymentAmountSection(setDialogState),
                  SizedBox(height: 16),

                  // Payment Method
                  _buildPaymentMethodSection(setDialogState),
                  SizedBox(height: 16),

                  // Notes
                  _buildNotesSection(),

                  // Validation Messages
                  if (_paymentAmount <= 0)
                    _buildValidationMessage('Please enter a valid payment amount', Colors.orange)
                  else if (_paymentAmount > _selectedCustomer!.currentBalance)
                    _buildValidationMessage('Payment cannot exceed current balance', Colors.red)
                  else if (_selectedCustomer!.overdueAmount > 0 && _paymentAmount < _selectedCustomer!.overdueAmount)
                      _buildValidationMessage('Consider paying overdue amount: ${Constants.CURRENCY_NAME}${_selectedCustomer!.overdueAmount.toStringAsFixed(2)}', Colors.orange),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isProcessingPayment ? null : () {
                  _resetProcessingState();
                  Navigator.pop(context);
                },
                child: Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: _isProcessingPayment ? null : _isValidPayment ? () => _processPayment(setDialogState) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isProcessingPayment
                    ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text('RECORD PAYMENT'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      // Reset processing state when dialog closes
      _resetProcessingState();
    });
  }

  Widget _buildCustomerInfoCard() {
    return Card(
      elevation: 2,
      color: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Icon(Icons.person, color: Colors.blue[800], size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedCustomer?.displayName ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildInfoRow('Current Balance', _selectedCustomer!.currentBalance),
            if (_selectedCustomer!.creditLimit > 0)
              _buildInfoRow('Credit Limit', _selectedCustomer!.creditLimit),
            if (_selectedCustomer!.overdueAmount > 0)
              _buildInfoRow(
                'Overdue Amount',
                _selectedCustomer!.overdueAmount,
                isWarning: true,
              ),
            if (_selectedCustomer!.availableCredit > 0)
              _buildInfoRow(
                'Available Credit',
                _selectedCustomer!.availableCredit,
                isPositive: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, double value, {bool isWarning = false, bool isPositive = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            '${Constants.CURRENCY_NAME}${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isWarning ? Colors.red : (isPositive ? Colors.green : Colors.blue[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAmountSection(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Amount',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          decoration: InputDecoration(
            labelText: 'Enter payment amount',
            prefixText: Constants.CURRENCY_NAME,
            border: OutlineInputBorder(),
            suffixIcon: PopupMenuButton<double>(
              icon: Icon(Icons.attach_money),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _selectedCustomer!.currentBalance,
                  child: Text('Full Balance'),
                ),
                if (_selectedCustomer!.overdueAmount > 0)
                  PopupMenuItem(
                    value: _selectedCustomer!.overdueAmount,
                    child: Text('Overdue Amount Only'),
                  ),
                PopupMenuItem(
                  value: _selectedCustomer!.currentBalance * 0.5,
                  child: Text('50% of Balance'),
                ),
              ],
              onSelected: (value) {
                setDialogState(() {
                  _paymentAmount = value;
                  _amountController.text = value.toStringAsFixed(2);
                });
              },
            ),
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) {
            setDialogState(() {
              _paymentAmount = double.tryParse(value) ?? 0.0;
            });
          },
        ),
        SizedBox(height: 8),
        Text(
          'Current Balance: ${Constants.CURRENCY_NAME}${_selectedCustomer!.currentBalance.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSection(StateSetter setDialogState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedPaymentMethod,
          decoration: InputDecoration(
            labelText: 'Select payment method',
            border: OutlineInputBorder(),
          ),
          items: _paymentMethods.map((method) {
            return DropdownMenuItem(
              value: method,
              child: Row(
                children: [
                  Icon(_getPaymentMethodIcon(method), size: 20),
                  SizedBox(width: 8),
                  Text(_getPaymentMethodName(method)),
                ],
              ),
            );
          }).toList(),
          onChanged: _isProcessingPayment ? null : (value) {
            setDialogState(() {
              _selectedPaymentMethod = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: 'Add any notes about this payment...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          maxLength: 200,
        ),
      ],
    );
  }

  Widget _buildValidationMessage(String message, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: color),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isValidPayment {
    return _paymentAmount > 0 &&
        _paymentAmount <= _selectedCustomer!.currentBalance;
  }

  Future<void> _processPayment(StateSetter setDialogState) async {
    if (_selectedCustomer == null || !_isValidPayment) return;

    setDialogState(() {
      _isProcessingPayment = true;
    });

    try {
      await widget.creditService.recordPayment(
        customerId: _selectedCustomer!.id,
        amount: _paymentAmount,
        paymentMethod: _selectedPaymentMethod,
        notes: _notesController.text.trim(),
      );

      // Close dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Show success message
      _showSuccess('Payment of ${Constants.CURRENCY_NAME}${_paymentAmount.toStringAsFixed(2)} recorded successfully!');

      // Reset form and reload data
      _resetForm();
      await _loadData();

    } catch (e) {
      _showError('Failed to record payment: $e');
    } finally {
      _resetProcessingState();
    }
  }

  void _resetForm() {
    setState(() {
      _selectedCustomer = null;
      _paymentAmount = 0.0;
      _selectedPaymentMethod = 'cash';
      _notesController.clear();
      _amountController.clear();
    });
  }

  void _resetProcessingState() {
    setState(() {
      _isProcessingPayment = false;
      _processingCustomerId = null;
    });
  }

  IconData _getPaymentMethodIcon(String method) {
    switch (method) {
      case 'cash':
        return Icons.money;
      case 'easypaisa/bank transfer':
        return Icons.phone_iphone;
      case 'bank_transfer':
        return Icons.account_balance;
      case 'cheque':
        return Icons.description;
      case 'other':
        return Icons.payment;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'easypaisa/bank transfer':
        return 'Easypaisa/Bank Transfer';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'cheque':
        return 'Cheque';
      case 'other':
        return 'Other';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Credit Collection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text(
            'Loading Credit Data...',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Quick Stats
        _buildQuickStats(),

        // Tabs
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                // Tab Bar
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: TabBar(
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Colors.grey[600],
                    labelStyle: TextStyle(fontWeight: FontWeight.w600),
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    tabs: [
                      Tab(
                        text: 'Credit Customers (${_customersWithCredit.length})',
                        icon: Icon(Icons.people, size: 20),
                      ),
                      Tab(
                        text: 'Recent Payments (${_recentPayments.length})',
                        icon: Icon(Icons.history, size: 20),
                      ),
                    ],
                  ),
                ),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildCustomersList(),
                      _buildRecentPaymentsList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    final totalOutstanding = _customersWithCredit.fold(0.0, (sum, c) => sum + c.currentBalance);
    final totalCustomers = _customersWithCredit.length;
    final totalOverdue = _customersWithCredit.fold(0.0, (sum, c) => sum + c.overdueAmount);
    final customersOverdue = _customersWithCredit.where((c) => c.overdueAmount > 0).length;

    return Card(
      margin: EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total Outstanding', totalOutstanding, Icons.attach_money),
                _buildStatItem('Customers', totalCustomers.toDouble(), Icons.people, isCount: true),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Overdue Amount', totalOverdue, Icons.warning),
                _buildStatItem('Overdue Customers', customersOverdue.toDouble(), Icons.error, isCount: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, double value, IconData icon, {bool isCount = false}) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.blue[700]),
              SizedBox(width: 4),
              Text(
                isCount ? value.toInt().toString() : '${Constants.CURRENCY_NAME}${value.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomersList() {
    if (_customersWithCredit.isEmpty) {
      return _buildEmptyState(
        icon: Icons.credit_card_off,
        title: 'No Credit Customers',
        message: 'There are no customers with outstanding credit balances.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _customersWithCredit.length,
        itemBuilder: (context, index) {
          final customer = _customersWithCredit[index];
          final isProcessing = _processingCustomerId == customer.customerId;

          return _buildCustomerItem(customer, isProcessing);
        },
      ),
    );
  }

  Widget _buildCustomerItem(CreditSummary customer, bool isProcessing) {
    final isOverLimit = customer.currentBalance > customer.creditLimit && customer.creditLimit > 0;
    final isOverdue = customer.overdueAmount > 0;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isOverLimit
                  ? Colors.red[100]
                  : (isOverdue ? Colors.orange[100] : Colors.blue[100]),
              child: Icon(
                isOverLimit ? Icons.warning : Icons.person,
                color: isOverLimit
                    ? Colors.red
                    : (isOverdue ? Colors.orange : Colors.blue),
              ),
            ),
            if (isProcessing)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          customer.customerName,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Balance: ${Constants.CURRENCY_NAME}${customer.currentBalance.toStringAsFixed(2)}'),
            if (customer.creditLimit > 0)
              Text('Limit: ${Constants.CURRENCY_NAME}${customer.creditLimit.toStringAsFixed(2)}'),
            if (isOverdue)
              Text(
                'Overdue: ${Constants.CURRENCY_NAME}${customer.overdueAmount.toStringAsFixed(2)}',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
              ),
          ],
        ),
        trailing: ElevatedButton.icon(
          onPressed: isProcessing ? null : () => _selectCustomerForPayment(customer),
          icon: Icon(Icons.payment, size: 16),
          label: isProcessing ? SizedBox() : Text('Collect'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isOverdue ? Colors.orange : Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentPaymentsList() {
    if (_recentPayments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'No Recent Payments',
        message: 'Payment history will appear here once payments are recorded.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _recentPayments.length,
        itemBuilder: (context, index) {
          final payment = _recentPayments[index];
          return _buildPaymentItem(payment);
        },
      ),
    );
  }

  Widget _buildPaymentItem(CreditTransaction payment) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green[100],
          child: Icon(Icons.payment, color: Colors.green, size: 20),
        ),
        title: Text(
          payment.customerName,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_getPaymentMethodName(payment.paymentMethod ?? 'cash')}'),
            Text(
              DateFormat('MMM dd, yyyy - HH:mm').format(payment.transactionDate),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (payment.notes?.isNotEmpty == true)
              Text(
                'Note: ${payment.notes!}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${Constants.CURRENCY_NAME}${payment.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
                fontSize: 16,
              ),
            ),
            Text(
              'Paid',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String message}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}