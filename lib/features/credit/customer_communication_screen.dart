import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../customerBase/customer_base.dart';
import '../main_navigation/main_navigation_base.dart';
import 'credit_models.dart';
import 'credit_service.dart';

class CustomerCommunicationScreen extends StatefulWidget {
  final CreditService creditService;
  final EnhancedPOSService posService;

  const CustomerCommunicationScreen({
    super.key,
    required this.creditService,
    required this.posService,
  });

  @override
  _CustomerCommunicationScreenState createState() => _CustomerCommunicationScreenState();
}

class _CustomerCommunicationScreenState extends State<CustomerCommunicationScreen> {
  List<CreditSummary> _customersWithCredit = [];
  List<Customer> _allCustomers = [];
  bool _isLoading = true;
  Customer? _selectedCustomer;
  List<CreditTransaction> _customerTransactions = [];
  CommunicationType _selectedCommunicationType = CommunicationType.sms;
  String _customMessage = '';
  bool _includeBalance = true;
  bool _includeRecentTransactions = false;
  bool _includeOverdueAlert = true;
  bool _isSending = false;
  bool _showCustomMessageField = false;

  static const platform = MethodChannel('com.qsyncai.mpcm/messaging');

  // Message templates
  final Map<MessageTemplate, String> _messageTemplates = {
    MessageTemplate.paymentReminder:
    'Hi {customerName}, this is a friendly reminder about your outstanding balance of {currency}{currentBalance}. We appreciate your prompt attention to this matter. Thank you for your business! - {companyName}',

    MessageTemplate.overdueAlert:
    'URGENT: Your account has an overdue amount of {currency}{overdueAmount}. Please make payment immediately to avoid service interruptions. Contact us if you have questions. - {companyName}',

    MessageTemplate.statementSummary:
    'Account Statement: Current Balance: {currency}{currentBalance}, Overdue: {currency}{overdueAmount}. Recent transactions: {recentTransactions}. Thank you for your business! - {companyName}',

    MessageTemplate.orderConfirmation:
    'Thank you for your order! Total: {currency}{orderTotal}, Balance Due: {currency}{currentBalance}. Products: {productDetails}. We appreciate your business! - {companyName}',

    MessageTemplate.creditLimitAlert:
    'Credit Alert: Your utilization is {utilizationRate}% of {currency}{creditLimit} limit. Available: {currency}{availableCredit}. Consider a payment to free up credit. - {companyName}',
  };

  MessageTemplate _selectedTemplate = MessageTemplate.paymentReminder;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final creditCustomers = await widget.creditService.getAllCreditCustomers();
      final allCustomers = await widget.posService.getAllCustomers();

      setState(() {
        _customersWithCredit = creditCustomers;
        _allCustomers = allCustomers;
      });
    } catch (e) {
      _showError('Failed to load data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCustomerTransactions(String customerId) async {
    try {
      final transactions = await widget.creditService.getCustomerTransactions(customerId);
      setState(() {
        _customerTransactions = transactions;
      });
    } catch (e) {
      _showError('Failed to load transactions: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.greenAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _generateMessage() {
    if (_selectedCustomer == null) return '';

    String message = _showCustomMessageField && _customMessage.isNotEmpty
        ? _customMessage
        : _messageTemplates[_selectedTemplate]!;

    final customer = _selectedCustomer!;
    final creditSummary = _customersWithCredit.firstWhere(
          (c) => c.customerId == customer.id,
      orElse: () => CreditSummary(
        customerId: customer.id,
        customerName: customer.fullName,
        currentBalance: customer.currentBalance,
        creditLimit: customer.creditLimit,
        totalCreditGiven: 0,
        totalCreditPaid: 0,
        totalTransactions: 0,
        overdueAmount: customer.overdueAmount,
      ),
    );

    // Replace template variables
    message = message.replaceAll('{customerName}', customer.fullName);
    message = message.replaceAll('{currentBalance}', customer.currentBalance.toStringAsFixed(2));
    message = message.replaceAll('{overdueAmount}', creditSummary.overdueAmount.toStringAsFixed(2));
    message = message.replaceAll('{creditLimit}', customer.creditLimit.toStringAsFixed(2));
    message = message.replaceAll('{availableCredit}', customer.availableCredit.toStringAsFixed(2));
    message = message.replaceAll('{utilizationRate}', customer.creditUtilization.toStringAsFixed(1));
    message = message.replaceAll('{currency}', Constants.CURRENCY_NAME);
    message = message.replaceAll('{companyName}', 'Your Business');
    message = message.replaceAll('{month}', DateFormat('MMMM').format(DateTime.now()));
    message = message.replaceAll('{year}', DateTime.now().year.toString());

    // Add recent transactions if enabled
    if (_includeRecentTransactions && _customerTransactions.isNotEmpty) {
      final recentTransactions = _customerTransactions.take(3).map((t) {
        final type = t.isPayment ? 'Payment' : 'Sale';
        final date = DateFormat('MM/dd').format(t.transactionDate);
        return '$date $type ${Constants.CURRENCY_NAME}${t.amount.toStringAsFixed(0)}';
      }).join(', ');
      message = message.replaceAll('{recentTransactions}', recentTransactions);
    } else {
      message = message.replaceAll('{recentTransactions}', '');
    }

    // Add product details for order confirmation
    if (_selectedTemplate == MessageTemplate.orderConfirmation) {
      final productDetails = _customerTransactions
          .where((t) => t.hasProductDetails)
          .take(1)
          .expand((t) => t.productDetails!)
          .take(2)
          .map((product) => '${product.productName} x${product.quantity}')
          .join(', ');
      message = message.replaceAll('{productDetails}', productDetails);
      message = message.replaceAll('{orderTotal}', customer.currentBalance.toStringAsFixed(2));
    }

    return message;
  }

  Future<void> _sendDirectSMS() async {
    if (_selectedCustomer == null) {
      _showError('Please select a customer');
      return;
    }

    final message = _generateMessage();
    final phone = _selectedCustomer!.phone;

    if (phone.isEmpty) {
      _showError('Customer phone number is not available');
      return;
    }

    setState(() => _isSending = true);

    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');

      final result = await platform.invokeMethod('sendSMS', {
        'phone': cleanPhone,
        'message': message,
      });

      if (result == true) {
        await _recordCommunication('sms', message);
        _showSuccess('SMS sent successfully!');
      } else {
        _showError('Failed to send SMS');
      }
    } on PlatformException catch (e) {
      _showError('SMS Error: ${e.message}');
    } catch (e) {
      _showError('Failed to send SMS: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendDirectWhatsApp() async {
    if (_selectedCustomer == null) {
      _showError('Please select a customer');
      return;
    }

    final message = _generateMessage();
    final phone = _selectedCustomer!.phone;

    if (phone.isEmpty) {
      _showError('Customer phone number is not available');
      return;
    }

    setState(() => _isSending = true);

    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');

      final result = await platform.invokeMethod('sendWhatsApp', {
        'phone': cleanPhone,
        'message': message,
      });

      if (result == true) {
        await _recordCommunication('whatsapp', message);
        _showSuccess('WhatsApp message sent successfully!');
      } else {
        _showError('Failed to send WhatsApp message');
      }
    } on PlatformException catch (e) {
      _showError('WhatsApp Error: ${e.message}');
    } catch (e) {
      _showError('Failed to send WhatsApp message: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _recordCommunication(String method, String message) async {
    try {
      await widget.creditService.recordCustomerContact(
        customerId: _selectedCustomer!.id,
        transactionId: _customerTransactions.isNotEmpty ? _customerTransactions.first.id : '',
        contactMethod: method,
        notes: 'Sent: ${_selectedTemplate.name}\n$message',
        contactedBy: 'User',
      );
    } catch (e) {
      print('Failed to record communication: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Customer Communication',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _loadData,
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
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Colors.blueAccent),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Loading Customer Data...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 16),

                  _buildCustomerSelection(),
                  const SizedBox(height: 16),

                  if (_selectedCustomer != null) ...[
                    _buildCommunicationControls(),
                    const SizedBox(height: 16),

                    _buildMessagePreview(),
                    const SizedBox(height: 16),

                    _buildActionButtons(),
                  ] else
                    Expanded(
                      child: _buildEmptyState(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blueAccent, Colors.lightBlueAccent],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_outlined, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Send Reminders',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Send automated reminders to customers about credits and purchases',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSelection() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_search, color: Colors.blueAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Select Customer',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.white,
            ),
            child: DropdownButtonFormField<Customer>(
              value: _selectedCustomer,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Choose a customer',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              selectedItemBuilder: (BuildContext context) {
                // This builder controls what's shown in the field AFTER selection
                return _customersWithCredit.isEmpty
                    ? _allCustomers.map((customer) {
                  return _buildSelectedCustomerView(customer);
                }).toList()
                    : _customersWithCredit.map((summary) {
                  final customer = _allCustomers.firstWhere(
                        (c) => c.id == summary.customerId,
                    orElse: () => Customer(
                      id: summary.customerId,
                      firstName: summary.customerName.split(' ').first,
                      lastName: summary.customerName.split(' ').skip(1).join(' '),
                      email: '',
                      phone: '',
                      currentBalance: summary.currentBalance,
                    ),
                  );
                  return _buildSelectedCustomerView(customer);
                }).toList();
              },
              items: _customersWithCredit.isEmpty
                  ? _allCustomers.map((customer) {
                return DropdownMenuItem(
                  value: customer,
                  child: _buildDropdownCustomerItem(customer),
                );
              }).toList()
                  : _customersWithCredit.map((summary) {
                final customer = _allCustomers.firstWhere(
                      (c) => c.id == summary.customerId,
                  orElse: () => Customer(
                    id: summary.customerId,
                    firstName: summary.customerName.split(' ').first,
                    lastName: summary.customerName.split(' ').skip(1).join(' '),
                    email: '',
                    phone: '',
                    currentBalance: summary.currentBalance,
                  ),
                );
                return DropdownMenuItem(
                  value: customer,
                  child: _buildDropdownCustomerItem(customer, summary: summary),
                );
              }).toList(),
              onChanged: (Customer? customer) async {
                setState(() => _selectedCustomer = customer);
                if (customer != null) {
                  await _loadCustomerTransactions(customer.id);
                }
              },
            ),
          ),        ],
      ),
    );
  }
// Simple text widget for selected state (shown in the field)
  Widget _buildSelectedCustomerView(Customer customer) {
    return Container(
      alignment: Alignment.centerLeft,
      child: Text(
        '${customer.firstName} ${customer.lastName}'.trim(),
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey[800],
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

// Detailed widget for dropdown items (shown in the dropdown menu)
  Widget _buildDropdownCustomerItem(Customer customer, {CreditSummary? summary}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              color: Colors.blue[600],
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${customer.firstName} ${customer.lastName}'.trim(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[800],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  summary != null
                      ? 'Credit: \$${summary.currentBalance.toStringAsFixed(2)}'
                      : customer.email.isNotEmpty
                      ? customer.email
                      : customer.phone,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (summary != null && summary.currentBalance > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Due',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange[700],
                ),
              ),
            ),
        ],
      ),
    );
  }
  // Widget _buildCustomerItem(Customer customer, {CreditSummary? summary}) {
  //   return Container(
  //     padding: EdgeInsets.symmetric(vertical: 8),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           customer.fullName,
  //           style: TextStyle(
  //             fontWeight: FontWeight.w600,
  //             fontSize: 14,
  //           ),
  //         ),
  //         SizedBox(height: 4),
  //         Text(
  //           customer.phone.isNotEmpty ? customer.phone : 'No phone number',
  //           style: TextStyle(
  //             fontSize: 12,
  //             color: Colors.grey[600],
  //           ),
  //         ),
  //         if (summary != null) ...[
  //           SizedBox(height: 4),
  //           Text(
  //             'Balance: ${Constants.CURRENCY_NAME}${summary.currentBalance.toStringAsFixed(2)}',
  //             style: TextStyle(
  //               fontSize: 12,
  //               color: summary.currentBalance > 0 ? Colors.orangeAccent : Colors.green,
  //               fontWeight: FontWeight.w500,
  //             ),
  //           ),
  //         ],
  //       ],
  //     ),
  //   );
  // }

  Widget _buildCommunicationControls() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_outlined, color: Colors.blueAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Communication Settings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          Text(
            'Send Via',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPlatformCard(
                  CommunicationType.sms,
                  'SMS',
                  Icons.sms_outlined,
                  Colors.greenAccent,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _buildPlatformCard(
                  CommunicationType.whatsapp,
                  'WhatsApp',
                  Icons.chat_outlined,
                  Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          Text(
            'Message Template',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: DropdownButtonFormField<MessageTemplate>(
              value: _selectedTemplate,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: Icon(Icons.message_outlined, color: Colors.grey[600]),
              ),
              items: MessageTemplate.values.map((template) {
                return DropdownMenuItem(
                  value: template,
                  child: Text(
                    _getTemplateDisplayName(template),
                    style: TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (template) {
                setState(() => _selectedTemplate = template!);
              },
            ),
          ),
          SizedBox(height: 16),

          Row(
            children: [
              Switch(
                value: _showCustomMessageField,
                onChanged: (value) => setState(() => _showCustomMessageField = value),
                activeColor: Colors.blueAccent,
              ),
              SizedBox(width: 8),
              Text(
                'Use Custom Message',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildOptionChip('Include Balance', _includeBalance, Icons.attach_money),
              _buildOptionChip('Recent Transactions', _includeRecentTransactions, Icons.receipt),
              _buildOptionChip('Overdue Alert', _includeOverdueAlert, Icons.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformCard(CommunicationType type, String label, IconData icon, Color color) {
    final isSelected = _selectedCommunicationType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedCommunicationType = type),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey[600], size: 24),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionChip(String label, bool selected, IconData icon) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) => setState(() {
        if (label == 'Include Balance') _includeBalance = value;
        if (label == 'Recent Transactions') _includeRecentTransactions = value;
        if (label == 'Overdue Alert') _includeOverdueAlert = value;
      }),
      checkmarkColor: Colors.white,
      selectedColor: Colors.blueAccent,
      backgroundColor: Colors.grey[200],
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey[600]),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.grey[700],
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }

  Widget _buildMessagePreview() {
    final message = _generateMessage();

    return Expanded(
      child: Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.preview_outlined, color: Colors.blueAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Message Preview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${message.length} chars',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            if (_showCustomMessageField) ...[
              TextField(
                decoration: InputDecoration(
                  labelText: 'Custom Message',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[400]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blueAccent),
                  ),
                  hintText: 'Type your custom message here...',
                  contentPadding: EdgeInsets.all(16),
                ),
                maxLines: 3,
                onChanged: (value) => setState(() => _customMessage = value),
              ),
              SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSending ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.grey[400]!),
              ),
              child: Text(
                'CANCEL',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSending ? null : () {
                if (_selectedCommunicationType == CommunicationType.sms) {
                  _sendDirectSMS();
                } else {
                  _sendDirectWhatsApp();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedCommunicationType == CommunicationType.sms
                    ? Colors.greenAccent
                    : Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isSending
                  ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedCommunicationType == CommunicationType.sms
                        ? Icons.sms
                        : Icons.chat,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _selectedCommunicationType == CommunicationType.sms
                        ? 'SEND SMS'
                        : 'SEND WHATSAPP',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 20),
            Text(
              'No Customer Selected',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please select a customer to start communication',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getTemplateDisplayName(MessageTemplate template) {
    switch (template) {
      case MessageTemplate.paymentReminder:
        return 'Payment Reminder';
      case MessageTemplate.overdueAlert:
        return 'Overdue Alert';
      case MessageTemplate.statementSummary:
        return 'Statement Summary';
      case MessageTemplate.orderConfirmation:
        return 'Order Confirmation';
      case MessageTemplate.creditLimitAlert:
        return 'Credit Limit Alert';
    }
  }
}

enum CommunicationType {
  sms,
  whatsapp,
}

enum MessageTemplate {
  paymentReminder,
  overdueAlert,
  statementSummary,
  orderConfirmation,
  creditLimitAlert,
}