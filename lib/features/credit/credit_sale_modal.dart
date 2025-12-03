// New file: credit_sale_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../customerBase/customer_base.dart';
import 'credit_sale_model.dart';

class CreditSaleModal extends StatefulWidget {
  final Customer? selectedCustomer;
  final double orderTotal;
  final Function(CreditSaleData) onConfirm;
  final Function() onCancel;

  const CreditSaleModal({
    super.key,
    required this.selectedCustomer,
    required this.orderTotal,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  _CreditSaleModalState createState() => _CreditSaleModalState();
}

class _CreditSaleModalState extends State<CreditSaleModal> {
  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _dueDate;
  bool _showPreviousCredit = true;

  double get _creditAmount => widget.orderTotal - _paidAmount;
  double get _paidAmount => double.tryParse(_paidAmountController.text) ?? 0.0;
  double get _previousBalance => widget.selectedCustomer?.currentBalance ?? 0.0;
  double get _newBalance => _previousBalance + _creditAmount;
  double get _creditLimit => widget.selectedCustomer?.creditLimit ?? 0.0;
  bool get _isOverLimit => _newBalance > _creditLimit && _creditLimit > 0;

  @override
  void initState() {
    super.initState();
    // Auto-fill paid amount as 0 for full credit
    _paidAmountController.text = '0';
    _paidAmountController.addListener(_validatePayment);
  }

  void _validatePayment() {
    if (_paidAmount > widget.orderTotal) {
      _paidAmountController.text = widget.orderTotal.toStringAsFixed(2);
    }
    setState(() {});
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _confirmCreditSale() {
    if (widget.selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a customer for credit sale')),
      );
      return;
    }

    if (_isOverLimit) {
      _showCreditLimitWarning();
      return;
    }

    final creditData = CreditSaleData(
      isCreditSale: true,
      creditAmount: _creditAmount,
      paidAmount: _paidAmount,
      dueDate: _dueDate,
      notes: _notesController.text.trim(),
      previousBalance: _previousBalance,
      newBalance: _newBalance,
    );

    widget.onConfirm(creditData);
  }

  void _showCreditLimitWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Credit Limit Exceeded'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This sale will exceed the customer\'s credit limit:'),
            SizedBox(height: 8),
            Text('Current Balance: ${Constants.CURRENCY_NAME}${_previousBalance.toStringAsFixed(2)}'),
            Text('Credit Limit: ${Constants.CURRENCY_NAME}${_creditLimit.toStringAsFixed(2)}'),
            Text('New Balance: ${Constants.CURRENCY_NAME}${_newBalance.toStringAsFixed(2)}'),
            Text('Over Limit: ${Constants.CURRENCY_NAME}${(_newBalance - _creditLimit).toStringAsFixed(2)}'),
            SizedBox(height: 12),
            Text(
              'Are you sure you want to proceed?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final creditData = CreditSaleData(
                isCreditSale: true,
                creditAmount: _creditAmount,
                paidAmount: _paidAmount,
                dueDate: _dueDate,
                notes: _notesController.text.trim(),
                previousBalance: _previousBalance,
                newBalance: _newBalance,
              );
              widget.onConfirm(creditData);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Proceed Anyway'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                _buildHeader(),
                SizedBox(height: 24),

                // Customer Info
                _buildCustomerInfo(),
                SizedBox(height: 20),

                // Previous Credit Toggle
                _buildPreviousCreditToggle(),
                SizedBox(height: 16),

                // Previous Credit Info (Conditional)
                if (_showPreviousCredit && widget.selectedCustomer != null)
                  _buildPreviousCreditInfo(),

                // Payment Input
                _buildPaymentInput(),
                SizedBox(height: 20),

                // Due Date Selection
                _buildDueDateSelection(),
                SizedBox(height: 20),

                // Notes
                _buildNotesInput(),
                SizedBox(height: 24),

                // Summary
                _buildSummary(),
                SizedBox(height: 24),

                // Action Buttons
                _buildActionButtons(),

                // Extra padding for safe area
                SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(Icons.credit_card, size: 28, color: Colors.blue),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Credit Sale',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Setup payment terms for credit sale',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.close),
          onPressed: widget.onCancel,
        ),
      ],
    );
  }

  Widget _buildCustomerInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Information',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            SizedBox(height: 8),
            if (widget.selectedCustomer != null) ...[
              Text(widget.selectedCustomer!.displayName,
                  style: TextStyle(fontWeight: FontWeight.w500)),
              SizedBox(height: 4),
              Text(widget.selectedCustomer!.email),
              if (widget.selectedCustomer!.phone.isNotEmpty)
                Text(widget.selectedCustomer!.phone),
            ] else
              Text(
                'No customer selected',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousCreditToggle() {
    return Row(
      children: [
        Switch(
          value: _showPreviousCredit,
          onChanged: (value) => setState(() => _showPreviousCredit = value),
        ),
        SizedBox(width: 8),
        Text(
          'Show Previous Credit Information',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildPreviousCreditInfo() {
    final customer = widget.selectedCustomer!;
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Balance',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${Constants.CURRENCY_NAME}${_previousBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _previousBalance > 0 ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
            if (customer.hasCreditLimit) ...[
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Credit Limit'),
                  Text('${Constants.CURRENCY_NAME}${_creditLimit.toStringAsFixed(2)}'),
                ],
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Available Credit'),
                  Text(
                    '${Constants.CURRENCY_NAME}${customer.availableCredit.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: customer.availableCredit < 100 ? Colors.orange : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              LinearProgressIndicator(
                value: customer.creditUtilization / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation(
                  customer.creditUtilization > 80 ? Colors.red :
                  customer.creditUtilization > 50 ? Colors.orange : Colors.green,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '${customer.creditUtilization.toStringAsFixed(1)}% Utilized',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
            if (customer.lastPaymentDate != null) ...[
              SizedBox(height: 8),
              Text(
                'Last Payment: ${DateFormat('MMM dd, yyyy').format(customer.lastPaymentDate!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Amount',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _paidAmountController,
          decoration: InputDecoration(
            labelText: 'Amount Paid Now',
            prefixText: Constants.CURRENCY_NAME,
            border: OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(Icons.attach_money),
              onPressed: () {
                _paidAmountController.text = widget.orderTotal.toStringAsFixed(2);
              },
            ),
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
        SizedBox(height: 8),
        Text(
          'Order Total: ${Constants.CURRENCY_NAME}${widget.orderTotal.toStringAsFixed(2)}',
          style: TextStyle(color: Colors.grey[600]),
        ),
        if (_paidAmount > 0) ...[
          SizedBox(height: 8),
          Text(
            'Credit Amount: ${Constants.CURRENCY_NAME}${_creditAmount.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDueDateSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Due Date (Optional)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: _selectDueDate,
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[600]),
                SizedBox(width: 12),
                Text(
                  _dueDate != null
                      ? DateFormat('MMM dd, yyyy').format(_dueDate!)
                      : 'Select due date',
                  style: TextStyle(
                    color: _dueDate != null ? Colors.black : Colors.grey,
                  ),
                ),
                Spacer(),
                if (_dueDate != null)
                  IconButton(
                    icon: Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: 'e.g., "Will pay on Friday", "Partial payment"',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildSummary() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryRow('Order Total', widget.orderTotal),
            _buildSummaryRow('Amount Paid', _paidAmount, isPayment: true),
            _buildSummaryRow('Credit Amount', _creditAmount, isCredit: true),
            if (widget.selectedCustomer != null) ...[
              Divider(),
              _buildSummaryRow('Previous Balance', _previousBalance),
              _buildSummaryRow('New Balance', _newBalance, isTotal: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {
    bool isPayment = false,
    bool isCredit = false,
    bool isTotal = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isPayment ? Colors.green :
              isCredit ? Colors.blue :
              isTotal ? Colors.blue[800] : Colors.black,
            ),
          ),
          Text(
            '${Constants.CURRENCY_NAME}${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isPayment ? Colors.green :
              isCredit ? Colors.blue :
              isTotal ? Colors.blue[800] : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: widget.onCancel,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text('CANCEL'),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _confirmCreditSale,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isOverLimit ? Colors.orange : Colors.blue,
              padding: EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _isOverLimit ? 'PROCEED ANYWAY' : 'CONFIRM CREDIT SALE',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}