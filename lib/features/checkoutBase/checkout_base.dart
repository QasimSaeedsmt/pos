
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../constants.dart';
import '../../printing/bottom_sheet.dart';
import '../../theme_utils.dart';
import '../cartBase/cart_base.dart';
import '../clientDashboard/client_dashboard.dart';
import '../credit/credit_sale_modal.dart';
import '../credit/credit_sale_model.dart';
import '../customerBase/customer_base.dart';
import '../invoiceBase/invoice_and_printing_base.dart';
import '../main_navigation/main_navigation_base.dart';
import '../orderBase/order_base.dart';



class CheckoutScreen extends StatefulWidget {
  final EnhancedCartManager cartManager;
  final List<CartItem> cartItems;

  const CheckoutScreen({
    super.key,
    required this.cartManager,
    required this.cartItems,
  });

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  bool _isProcessing = false;
  AppOrder? _completedOrder;
  int? _pendingOrderId;
  String? _errorMessage;
  CustomerSelection _customerSelection = CustomerSelection(useDefault: true);

  // Settings data
  Map<String, dynamic> _invoiceSettings = {};
  Map<String, dynamic> _businessInfo = {};
  bool _isLoadingSettings = true;
  bool _isCreditSale = false;
  CreditSaleData? _creditSaleData;
  // Payment methods
  final List<String> _paymentMethods = [
    'cash',
    'easypaisa/bank transfer',
    'credit', // Add credit option


  ];
  String _selectedPaymentMethod = 'cash';

  // Additional charges/discounts
  final TextEditingController _additionalDiscountController =
  TextEditingController();
  final TextEditingController _shippingController = TextEditingController();
  final TextEditingController _tipController = TextEditingController();

  double _additionalDiscount = 0.0;
  double _shippingAmount = 0.0;
  double _tipAmount = 0.0;

  // Track if we should reset the screen
  bool _shouldResetScreen = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupCartListeners();
  }

  void _setupCartListeners() {
    widget.cartManager.totalStream.listen((total) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoadingSettings = true);

    try {
      final settings = await _posService.getInvoiceSettings();
      final businessInfo = await _posService.getBusinessInfo();

      if (mounted) {
        setState(() {
          _invoiceSettings = settings;
          _businessInfo = businessInfo;
          _isLoadingSettings = false;
        });

        // Apply default discount rate from settings if no manual discount is set
        final defaultDiscountRate = _invoiceSettings['discountRate'] ?? 0.0;
        if (defaultDiscountRate > 0 &&
            widget.cartManager.cartDiscountPercent == 0) {
          widget.cartManager.applyCartDiscount(
            discountPercent: defaultDiscountRate,
          );
        }

        // Apply tax rate from settings
        final taxRate = _invoiceSettings['taxRate'] ?? 0.0;
        widget.cartManager.updateTaxRate(taxRate);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSettings = false;
        });
      }
    }
  }
  // Add this method to show credit sale modal
  void _showCreditSaleModal() {
    if (!_customerSelection.hasCustomer) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a customer for credit sale'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // This is crucial
      backgroundColor: Colors.transparent,
      builder: (context) => CreditSaleModal(
        selectedCustomer: _customerSelection.customer!,
        orderTotal: _finalTotal,
        onConfirm: (creditData) {
          setState(() {
            _creditSaleData = creditData;
            _selectedPaymentMethod = 'credit';
            _isCreditSale = true;
          });
          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Credit sale configured successfully'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onCancel: () {
          setState(() {
            _isCreditSale = false;
            _creditSaleData = null;
            _selectedPaymentMethod = 'cash';
          });
          Navigator.pop(context);
        },
      ),
    );
  }
  // Update the payment section to handle credit selection
  Widget _buildPaymentSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _paymentMethods.map((method) {
                final isSelected = _selectedPaymentMethod == method;
                return ChoiceChip(
                  label: Text(_getPaymentMethodName(method)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      if (method == 'credit') {
                        _showCreditSaleModal();
                      } else {
                        setState(() {
                          _selectedPaymentMethod = method;
                          _isCreditSale = false;
                          _creditSaleData = null;
                        });
                      }
                    }
                  },
                  selectedColor: method == 'credit' ? Colors.orange[100] : Colors.blue[100],
                  labelStyle: TextStyle(
                    color: isSelected ?
                    (method == 'credit' ? Colors.orange[800] : Colors.blue[800]) :
                    Colors.grey[800],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),

            // Show credit sale details if selected
            if (_isCreditSale && _creditSaleData != null)
              _buildCreditSaleDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditSaleDetails() {
    final creditData = _creditSaleData!;
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card, size: 16, color: Colors.orange),
              SizedBox(width: 8),
              Text(
                'Credit Sale Details',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[800]),
              ),
            ],
          ),
          SizedBox(height: 8),
          _buildCreditDetailRow('Amount Paid', creditData.paidAmount),
          _buildCreditDetailRow('Credit Amount', creditData.creditAmount),
          if (creditData.dueDate != null)
            _buildCreditDetailRow(
              'Due Date',
              0, // We'll handle this specially
              textValue: DateFormat('MMM dd, yyyy').format(creditData.dueDate!),
            ),
          if (creditData.notes.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text(
                  'Notes: ${creditData.notes}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          SizedBox(height: 8),
          TextButton(
            onPressed: _showCreditSaleModal,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size(50, 30),
            ),
            child: Text(
              'Edit Credit Terms',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditDetailRow(String label, double amount, {String? textValue}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          Text(
            textValue ?? '${Constants.CURRENCY_NAME}${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.orange[800],
            ),
          ),
        ],
      ),
    );
  }
  void _showInvoiceOptions(AppOrder order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => InvoiceOptionsBottomSheetWithOptions(
        order: order,
        customer: _customerSelection.hasCustomer
            ? _customerSelection.customer
            : null,
        // businessInfo: _businessInfo,
        // invoiceSettings: _invoiceSettings,
      ),
    ).then((_) {
      // After invoice dialog is closed, reset the screen
      _resetCheckoutScreen();
    });
  }

  void _showOfflineInvoiceOptions(int pendingOrderId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => OfflineInvoiceBottomSheet(
        pendingOrderId: pendingOrderId,
        customer: _customerSelection.hasCustomer
            ? _customerSelection.customer
            : null,
        businessInfo: _businessInfo,
        invoiceSettings: _invoiceSettings,
        finalTotal: _finalTotal,
        paymentMethod: _selectedPaymentMethod,
      ),
    ).then((_) {
      // After invoice dialog is closed, reset the screen
      _resetCheckoutScreen();
    });
  }

  Future<void> _selectCustomer() async {
    final result = await Navigator.push<CustomerSelection>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerSelectionScreen(
          posService: _posService,
          initialSelection: _customerSelection,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _customerSelection = result;
      });
    }
  }

  void _showAdditionalDiscountDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Additional Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current taxable amount: ${Constants.CURRENCY_NAME}${_taxableAmount.toStringAsFixed(2)}',
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Discount Amount (${Constants.CURRENCY_NAME})',
                prefixText: Constants.CURRENCY_NAME,
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          if (_additionalDiscount > 0)
            TextButton(
              onPressed: () {
                setState(() => _additionalDiscount = 0.0);
                _additionalDiscountController.clear();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Additional discount removed')),
                );
              },
              child: Text(
                'Remove Discount',
                style: TextStyle(color: Colors.red),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final discount = double.tryParse(controller.text);
              if (discount != null && discount > 0) {
                setState(() => _additionalDiscount = discount);
                _additionalDiscountController.text = discount.toStringAsFixed(
                  2,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Additional discount applied')),
                );
              }
            },
            child: Text('Apply Discount'),
          ),
        ],
      ),
    );
  }

  void _showShippingDialog() {
    final controller = TextEditingController(
      text: _shippingAmount.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Shipping Amount'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Shipping Amount (${Constants.CURRENCY_NAME})',
            prefixText: Constants.CURRENCY_NAME,
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final shipping = double.tryParse(controller.text) ?? 0.0;
              setState(() => _shippingAmount = shipping);
              _shippingController.text = shipping.toStringAsFixed(2);
              Navigator.pop(context);
            },
            child: Text('Apply Shipping'),
          ),
        ],
      ),
    );
  }

  void _showTipDialog() {
    final controller = TextEditingController(
      text: _tipAmount.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tip Amount'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Tip Amount (${Constants.CURRENCY_NAME})',
            prefixText: Constants.CURRENCY_NAME,
          ),
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final tip = double.tryParse(controller.text) ?? 0.0;
              setState(() => _tipAmount = tip);
              _tipController.text = tip.toStringAsFixed(2);
              Navigator.pop(context);
            },
            child: Text('Apply Tip'),
          ),
        ],
      ),
    );
  }

  // Enhanced total calculations with additional charges/discounts
  double get _subtotal => widget.cartManager.subtotal;
  double get _itemDiscounts => widget.cartManager.items.fold(
    0.0,
        (sum, item) => sum + item.discountAmount,
  );
  double get _cartDiscount =>
      widget.cartManager.cartDiscount +
          (_subtotal * widget.cartManager.cartDiscountPercent / 100);
  double get _totalDiscount =>
      _itemDiscounts + _cartDiscount + _additionalDiscount;
  double get _taxableAmount => _subtotal - _totalDiscount;
  double get _taxAmount => _taxableAmount * widget.cartManager.taxRate / 100;
  double get _finalTotal =>
      _taxableAmount + _taxAmount + _shippingAmount + _tipAmount;

  // Update reset method to clear credit data
  void _resetCheckoutScreen() {
    if (mounted) {
      setState(() {
        _additionalDiscount = 0.0;
        _shippingAmount = 0.0;
        _tipAmount = 0.0;
        _selectedPaymentMethod = 'cash';
        _customerSelection = CustomerSelection(useDefault: true);
        _completedOrder = null;
        _pendingOrderId = null;
        _errorMessage = null;
        _isCreditSale = false;
        _creditSaleData = null;

        // Clear controllers
        _additionalDiscountController.clear();
        _shippingController.clear();
        _tipController.clear();
      });
    }
  }

// In checkout_base.dart - UPDATE the _processOrder method
  // Update the process order method to include credit data
  Future<void> _processOrder() async {
    if (widget.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cart is empty')));
      return;
    }

    // Validate credit sale requirements
    if (_isCreditSale && !_customerSelection.hasCustomer) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Customer selection is required for credit sales')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Create enhanced order data with all discount information
      final orderData = {
        'cartData': widget.cartManager.getCartDataForOrder(),
        'additionalDiscount': _additionalDiscount,
        'shippingAmount': _shippingAmount,
        'tipAmount': _tipAmount,
        'finalTotal': _finalTotal,
        'paymentMethod': _selectedPaymentMethod,
        'invoiceSettings': _invoiceSettings,
        'businessInfo': _businessInfo,
      };

      // Use the enhanced order creation method with credit data
      final result = await _posService.createOrderWithEnhancedData(
        widget.cartItems,
        _customerSelection,
        additionalData: orderData,
        cartManager: widget.cartManager,
        creditSaleData: _isCreditSale ? _creditSaleData : null,
      );

      if (result.success) {
        // Clear cart first
        await widget.cartManager.clearCart();

        if (result.isOffline) {
          setState(() => _pendingOrderId = result.pendingOrderId);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isCreditSale ?
              'Credit sale saved offline. Will sync when online.' :
              'Order saved offline. Will sync when online.'),
              backgroundColor: Colors.orange,
            ),
          );

          // Show invoice for offline order
          if (result.pendingOrderId != null) {
            _showOfflineInvoiceOptions(result.pendingOrderId!);
          } else if (result.order != null) {
            _showEnhancedInvoiceOptions(result.order!, orderData);
          } else {
            _resetCheckoutScreen();
          }
        } else {
          setState(() => _completedOrder = result.order);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isCreditSale ?
              'Credit sale processed successfully!' :
              'Order processed successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Show enhanced invoice for online order
          if (result.order != null) {
            _showEnhancedInvoiceOptions(result.order!, orderData);
          } else {
            _resetCheckoutScreen();
          }
        }
      } else {
        setState(() => _errorMessage = result.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order failed: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
// Add this method to show enhanced invoice options
  void _showEnhancedInvoiceOptions(AppOrder order, Map<String, dynamic> enhancedData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => InvoiceOptionsBottomSheetWithOptions(
        order: order,
        customer: _customerSelection.hasCustomer ? _customerSelection.customer : null,
        enhancedData: enhancedData,
      ),
    ).then((_) {
      _resetCheckoutScreen();
    });
  }
  Widget _buildCustomerSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Customer Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(onPressed: _selectCustomer, child: Text('Change')),
              ],
            ),
            SizedBox(height: 8),
            if (_customerSelection.hasCustomer)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _customerSelection.customer!.displayName,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(_customerSelection.customer!.email),
                  if (_customerSelection.customer!.phone.isNotEmpty)
                    Text(_customerSelection.customer!.phone),
                  if (_customerSelection.customer!.orderCount > 0)
                    Text(
                      '${_customerSelection.customer!.orderCount} previous orders',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                ],
              )
            else
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'Walk-in Customer (No customer information)',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            widget.cartItems.isEmpty
                ? Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No items in cart',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            )
                : ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: widget.cartItems.length,
              itemBuilder: (context, index) {
                final item = widget.cartItems[index];
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          item.product.name,
                          style: TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Qty: ${item.quantity}',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${Constants.CURRENCY_NAME}${item.subtotal.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.w500),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Price Breakdown',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            _buildPriceRow('Subtotal', _subtotal),
            if (_itemDiscounts > 0)
              _buildPriceRow(
                'Item Discounts',
                -_itemDiscounts,
                isDiscount: true,
              ),
            if (_cartDiscount > 0)
              _buildPriceRow('Cart Discount', -_cartDiscount, isDiscount: true),
            if (_additionalDiscount > 0)
              _buildPriceRow(
                'Additional Discount',
                -_additionalDiscount,
                isDiscount: true,
              ),
            if (widget.cartManager.taxRate > 0)
              _buildPriceRow(
                'Tax (${widget.cartManager.taxRate.toStringAsFixed(1)}%)',
                _taxAmount,
              ),
            if (_shippingAmount > 0)
              _buildPriceRow('Shipping', _shippingAmount),
            if (_tipAmount > 0) _buildPriceRow('Tip', _tipAmount),
            Divider(),
            _buildPriceRow('TOTAL', _finalTotal, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(
      String label,
      double amount, {
        bool isDiscount = false,
        bool isTotal = false,
      }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green : Colors.black,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}${Constants.CURRENCY_NAME}${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount
                  ? Colors.green
                  : (isTotal ? Colors.green[700] : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalOptions() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Options',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildAdditionalOptionButton(
                    'Additional Discount',
                    _additionalDiscount > 0
                        ? '${Constants.CURRENCY_NAME}${_additionalDiscount.toStringAsFixed(2)}'
                        : 'Add',
                    _showAdditionalDiscountDialog,
                    color: _additionalDiscount > 0 ? Colors.green : null,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _buildAdditionalOptionButton(
                    'Shipping',
                    _shippingAmount > 0
                        ? '${Constants.CURRENCY_NAME}${_shippingAmount.toStringAsFixed(2)}'
                        : 'Add',
                    _showShippingDialog,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildAdditionalOptionButton(
                    'Tip',
                    _tipAmount > 0
                        ? '${Constants.CURRENCY_NAME}${_tipAmount.toStringAsFixed(2)}'
                        : 'Add',
                    _showTipDialog,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Container(), // Empty for alignment
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalOptionButton(
      String title,
      String value,
      VoidCallback onTap, {
        Color? color,
      }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.blue[700],
              ),
            ),
          ],
        ),
      ),
    );
  }



  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'easypaisa/bank transfer':
        return         'easypaisa/bank transfer'
    ;
      case 'credit':
        return 'Credit Sale';
      default:
        return method;
    }
  }

  Widget _buildActionButtons() {
    final isOnline = _posService.isOnline;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        children: [
          if (_errorMessage != null)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                ],
              ),
            ),

          if (!isOnline)
            Container(
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline Mode - Order will be saved locally and synced when online',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: _isProcessing
                ? ElevatedButton(
              onPressed: null,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
                : ElevatedButton(
              onPressed: widget.cartItems.isEmpty ? null : _processOrder,
              child: Text(
                isOnline ? 'PROCESS PAYMENT' : 'SAVE OFFLINE ORDER',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSettings) {
      return SafeArea(
        child: Scaffold(
          appBar: AppBar(title: Text('Checkout',),backgroundColor: ThemeUtils.primary(context),),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading settings...'),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Checkout'),
          backgroundColor: _posService.isOnline
              ? ThemeUtils.primary(context)
              : ThemeUtils.secondary(context),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Customer Section
                    _buildCustomerSection(),
                    SizedBox(height: 16),

                    // Order Summary
                    _buildOrderSummary(),
                    SizedBox(height: 16),

                    // Additional Options
                    _buildAdditionalOptions(),
                    SizedBox(height: 16),

                    // Price Breakdown
                    _buildPriceBreakdown(),
                    SizedBox(height: 16),

                    // Payment Section
                    _buildPaymentSection(),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _additionalDiscountController.dispose();
    _shippingController.dispose();
    _tipController.dispose();
    super.dispose();
  }
}