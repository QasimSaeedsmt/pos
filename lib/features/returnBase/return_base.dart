


import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../../constants.dart';
import '../clientDashboard/client_dashboard.dart';
import '../invoiceBase/invoice_and_printing_base.dart';
import '../main_navigation/main_navigation_base.dart';
import '../orderBase/order_base.dart';
import '../product_selling/product_selling_base.dart';

class ReturnReason {
  final String id;
  final String name;
  final String description;
  final bool requiresApproval;

  ReturnReason({
    required this.id,
    required this.name,
    required this.description,
    this.requiresApproval = false,
  });

  @override
  String toString() => name;
}

// Enhanced ReturnItem model
class ReturnItem {
  final String productId;
  final String productName;
  final String productSku;
  final int quantity;
  final double price;
  final String returnReason;
  final String? notes;

  ReturnItem({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.price,
    required this.returnReason,
    this.notes,
  });

  double get subtotal => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productSku': productSku,
      'quantity': quantity,
      'price': price,
      'returnReason': returnReason,
      'notes': notes,
      'subtotal': subtotal,
    };
  }

  // In ReturnItem class - ENHANCE the fromMap method:

  factory ReturnItem.fromMap(Map<String, dynamic> map) {
    return ReturnItem(
      productId: map['productId']?.toString() ?? '',
      productName: map['productName']?.toString() ?? '',
      productSku: map['productSku']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      returnReason: map['returnReason']?.toString() ?? '',
      notes: map['notes']?.toString(),
    );
  }
}

// Enhanced Return models with offline support
class ReturnRequest {
  final String id;
  final String orderId;
  final String orderNumber;
  final List<ReturnItem> items;
  final String reason;
  final String status; // pending, approved, rejected, completed, refunded
  final String? notes;
  final DateTime dateCreated;
  final DateTime? dateUpdated;
  final double refundAmount;
  final String refundMethod; // original, cash, credit, store_credit
  final String? customerId;
  final Map<String, dynamic>? customerInfo;
  final String? processedBy;
  final bool isOffline;
  final String? offlineId;
  final String syncStatus; // pending, synced, failed

  ReturnRequest({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.items,
    required this.reason,
    required this.status,
    this.notes,
    required this.dateCreated,
    this.dateUpdated,
    required this.refundAmount,
    required this.refundMethod,
    this.customerId,
    this.customerInfo,
    this.processedBy,
    this.isOffline = false,
    this.offlineId,
    this.syncStatus = 'synced',
  });

  bool get isCompleted => status == 'completed' || status == 'refunded';
  bool get canRefund => status == 'approved' || status == 'completed';
  bool get needsSync => isOffline && syncStatus == 'pending';

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'items': items.map((item) => item.toMap()).toList(),
      'reason': reason,
      'status': status,
      'notes': notes,
      'dateCreated': Timestamp.fromDate(dateCreated),
      'dateUpdated': dateUpdated != null
          ? Timestamp.fromDate(dateUpdated!)
          : FieldValue.serverTimestamp(),
      'refundAmount': refundAmount,
      'refundMethod': refundMethod,
      'customerId': customerId,
      'customerInfo': customerInfo,
      'processedBy': processedBy,
      'isOffline': isOffline,
      'offlineId': offlineId,
      'syncStatus': syncStatus,
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'items': items.map((item) => item.toMap()).toList(),
      'reason': reason,
      'status': status,
      'notes': notes,
      'dateCreated': dateCreated.toIso8601String(),
      'dateUpdated': dateUpdated?.toIso8601String(),
      'refundAmount': refundAmount,
      'refundMethod': refundMethod,
      'customerId': customerId,
      'customerInfo': customerInfo,
      'processedBy': processedBy,
      'isOffline': isOffline,
      'offlineId': offlineId,
      'syncStatus': syncStatus,
    };
  }

  factory ReturnRequest.fromFirestore(Map<String, dynamic> data, String id) {
    return ReturnRequest(
      id: id,
      orderId: data['orderId'] ?? '',
      orderNumber: data['orderNumber'] ?? '',
      items: (data['items'] as List? ?? [])
          .map((item) => ReturnItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      notes: data['notes'],
      dateCreated: (data['dateCreated'] as Timestamp).toDate(),
      dateUpdated: data['dateUpdated'] != null
          ? (data['dateUpdated'] as Timestamp).toDate()
          : null,
      refundAmount: (data['refundAmount'] as num?)?.toDouble() ?? 0.0,
      refundMethod: data['refundMethod'] ?? 'original',
      customerId: data['customerId'],
      customerInfo: data['customerInfo'] != null
          ? Map<String, dynamic>.from(data['customerInfo'])
          : null,
      processedBy: data['processedBy'],
      isOffline: data['isOffline'] ?? false,
      offlineId: data['offlineId'],
      syncStatus: data['syncStatus'] ?? 'synced',
    );
  }

  factory ReturnRequest.fromLocalMap(Map<String, dynamic> data) {
    return ReturnRequest(
      id: data['id'] ?? '',
      orderId: data['orderId'] ?? '',
      orderNumber: data['orderNumber'] ?? '',
      items: (data['items'] as List? ?? [])
          .map((item) => ReturnItem.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      notes: data['notes'],
      dateCreated: DateTime.parse(data['dateCreated']),
      dateUpdated: data['dateUpdated'] != null
          ? DateTime.parse(data['dateUpdated'])
          : null,
      refundAmount: (data['refundAmount'] as num?)?.toDouble() ?? 0.0,
      refundMethod: data['refundMethod'] ?? 'original',
      customerId: data['customerId'],
      customerInfo: data['customerInfo'] != null
          ? Map<String, dynamic>.from(data['customerInfo'])
          : null,
      processedBy: data['processedBy'],
      isOffline: data['isOffline'] ?? false,
      offlineId: data['offlineId'],
      syncStatus: data['syncStatus'] ?? 'pending',
    );
  }

  ReturnRequest copyWith({
    String? status,
    String? notes,
    double? refundAmount,
    String? refundMethod,
    String? processedBy,
    String? syncStatus,
  }) {
    return ReturnRequest(
      id: id,
      orderId: orderId,
      orderNumber: orderNumber,
      items: items,
      reason: reason,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      dateCreated: dateCreated,
      dateUpdated: DateTime.now(),
      refundAmount: refundAmount ?? this.refundAmount,
      refundMethod: refundMethod ?? this.refundMethod,
      customerId: customerId,
      customerInfo: customerInfo,
      processedBy: processedBy ?? this.processedBy,
      isOffline: isOffline,
      offlineId: offlineId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class ReturnCreationResult {
  final bool success;
  final ReturnRequest? returnRequest;
  final String? pendingReturnId;
  final String? error;

  ReturnCreationResult.success(this.returnRequest)
      : success = true,
        pendingReturnId = null,
        error = null;

  ReturnCreationResult.offline(this.pendingReturnId)
      : success = true,
        returnRequest = null,
        error = null;

  ReturnCreationResult.error(this.error)
      : success = false,
        returnRequest = null,
        pendingReturnId = null;

  bool get isOffline => pendingReturnId != null;
}
// REPLACE the entire ReturnsManagementScreen class:
class ReturnsManagementScreen extends StatefulWidget {
  const ReturnsManagementScreen({super.key});

  @override
  _ReturnsManagementScreenState createState() =>
      _ReturnsManagementScreenState();
}

class _ReturnsManagementScreenState extends State<ReturnsManagementScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final List<ReturnRequest> _returns = [];
  bool _isLoading = true;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkOnlineStatus();
    _loadReturns();
  }

  Future<void> _checkOnlineStatus() async {
    final isOnline = _posService.isOnline;
    setState(() {
      _isOnline = isOnline;
    });
  }

  Future<void> _loadReturns() async {
    setState(() => _isLoading = true);

    try {
      final returns = await _posService.getAllReturns(limit: 50);
      setState(() {
        _returns.clear();
        _returns.addAll(returns);
      });
    } catch (e) {
      print('Failed to load returns: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load returns: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToCreateReturnWithOrder() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SearchOrderForReturnScreen()),
    ).then((selectedOrder) {
      if (selectedOrder != null && selectedOrder is AppOrder) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CreateReturnScreen(selectedOrder: selectedOrder),
          ),
        ).then((_) => _loadReturns());
      }
    });
  }

  void _navigateToReturnAnyProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReturnAnyProductScreen()),
    ).then((_) => _loadReturns());
  }

  void _viewReturnDetails(ReturnRequest returnRequest) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReturnDetailsScreen(returnRequest: returnRequest),
      ),
    );
  }

  void _showSyncStatus() {
    final pendingCount = _returns.where((ret) => ret.needsSync).length;

    if (pendingCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$pendingCount returns pending sync'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All returns are synced'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingSyncCount = _returns.where((ret) => ret.needsSync).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Returns & Refunds'),
        actions: [
          if (pendingSyncCount > 0)
            Badge(
              label: Text(pendingSyncCount.toString()),
              child: IconButton(
                icon: Icon(Icons.sync_problem),
                onPressed: _showSyncStatus,
                tooltip: '$pendingSyncCount returns pending sync',
              ),
            ),
          if (!_isOnline)
            IconButton(
              icon: Icon(Icons.cloud_off, color: Colors.orange),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Working in offline mode - Returns will sync when online',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              tooltip: 'Offline Mode',
            ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadReturns,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection Status Banner
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              color: Colors.orange[100],
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 20, color: Colors.orange[800]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Offline Mode - Returns will be saved locally and synced when online',
                      style: TextStyle(color: Colors.orange[800]),
                    ),
                  ),
                ],
              ),
            ),

          // Quick Actions
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Process New Return',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                // Option 1: Return with Order
                Card(
                  child: ListTile(
                    leading: Icon(Icons.receipt_long, color: Colors.blue),
                    title: Text('Return with Order'),
                    subtitle: Text('Find order by number or barcode'),
                    trailing: Icon(Icons.arrow_forward),
                    onTap: _navigateToCreateReturnWithOrder,
                  ),
                ),
                SizedBox(height: 12),
                // Option 2: Return Any Product
                Card(
                  child: ListTile(
                    leading: Icon(Icons.shopping_bag, color: Colors.green),
                    title: Text('Return Any Product'),
                    subtitle: Text('Return without order receipt'),
                    trailing: Icon(Icons.arrow_forward),
                    onTap: _navigateToReturnAnyProduct,
                  ),
                ),
              ],
            ),
          ),
          Divider(),

          // Recent Returns Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Returns',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_returns.length} returns',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Recent Returns List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _returns.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_return,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text('No returns processed yet'),
                  SizedBox(height: 8),
                  Text(
                    !_isOnline
                        ? 'Returns will be saved locally and synced when online'
                        : 'Choose an option above to process a return',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadReturns,
              child: ListView.builder(
                itemCount: _returns.length,
                itemBuilder: (context, index) {
                  final returnRequest = _returns[index];
                  return GestureDetector(
                    onTap: () => _viewReturnDetails(returnRequest),
                    child: EnhancedReturnRequestCard(
                      returnRequest: returnRequest,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// REPLACE the entire CreateReturnScreen class:
// ADD this new EnhancedReturnRequestCard class:
class EnhancedReturnRequestCard extends StatelessWidget {
  final ReturnRequest returnRequest;

  const EnhancedReturnRequestCard({super.key, required this.returnRequest});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Return #${returnRequest.id.substring(0, 8).toUpperCase()}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Row(
                  children: [
                    if (returnRequest.needsSync)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sync,
                              size: 12,
                              color: Colors.orange[800],
                            ),
                            SizedBox(width: 2),
                            Text(
                              'PENDING SYNC',
                              style: TextStyle(
                                color: Colors.orange[800],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(returnRequest.status),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        returnRequest.status.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Order: ${returnRequest.orderNumber}',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text('Items: ${returnRequest.items.length}'),
            Text(
              'Refund: ${Constants.CURRENCY_NAME}${returnRequest.refundAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.green[700],
              ),
            ),
            Text(
              'Method: ${_getRefundMethodDisplayName(returnRequest.refundMethod)}',
            ),
            Text(
              'Date: ${DateFormat('MMM dd, yyyy').format(returnRequest.dateCreated)}',
            ),
            if (returnRequest.isOffline)
              Text(
                'Created Offline',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            SizedBox(height: 8),
            if (returnRequest.notes != null && returnRequest.notes!.isNotEmpty)
              Text(
                'Notes: ${returnRequest.notes!}',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'approved':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'refunded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getRefundMethodDisplayName(String method) {
    switch (method) {
      case 'original':
        return 'Original Payment';
      case 'cash':
        return 'Cash';
      case 'credit':
        return 'Credit Card';
      case 'store_credit':
        return 'Store Credit';
      default:
        return method;
    }
  }
}

class CreateReturnScreen extends StatefulWidget {
  final AppOrder? selectedOrder;

  const CreateReturnScreen({super.key, this.selectedOrder});

  @override
  _CreateReturnScreenState createState() => _CreateReturnScreenState();
}
// ADD this new class for viewing return details:

class ReturnDetailsScreen extends StatelessWidget {
  final ReturnRequest returnRequest;

  const ReturnDetailsScreen({super.key, required this.returnRequest});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Return Details')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Return Header
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Return #${returnRequest.id.substring(0, 8).toUpperCase()}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(returnRequest.status),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            returnRequest.status.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('Order: ${returnRequest.orderNumber}'),
                    Text(
                      'Date: ${DateFormat('MMM dd, yyyy - HH:mm').format(returnRequest.dateCreated)}',
                    ),
                    if (returnRequest.dateUpdated != null)
                      Text(
                        'Updated: ${DateFormat('MMM dd, yyyy - HH:mm').format(returnRequest.dateUpdated!)}',
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Refund Summary
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Refund Summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Refund Amount:'),
                        Text(
                          '${Constants.CURRENCY_NAME}${returnRequest.refundAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Refund Method:'),
                        Text(
                          _getRefundMethodDisplayName(
                            returnRequest.refundMethod,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Return Reason:'),
                        Text(_getReasonName(returnRequest.reason)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Returned Items
            Text(
              'Returned Items (${returnRequest.items.length})',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: returnRequest.items.length,
                itemBuilder: (context, index) {
                  final item = returnRequest.items[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        Icons.assignment_return,
                        color: Colors.orange,
                      ),
                      title: Text(item.productName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.productSku.isNotEmpty)
                            Text('SKU: ${item.productSku}'),
                          Text(
                            'Qty: ${item.quantity} • ${Constants.CURRENCY_NAME}${item.price.toStringAsFixed(2)} each',
                          ),
                          Text(
                            'Subtotal: ${Constants.CURRENCY_NAME}${item.subtotal.toStringAsFixed(2)}',
                          ),
                          Text('Reason: ${_getReasonName(item.returnReason)}'),
                          if (item.notes != null && item.notes!.isNotEmpty)
                            Text('Notes: ${item.notes}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Notes
            if (returnRequest.notes != null &&
                returnRequest.notes!.isNotEmpty) ...[
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Additional Notes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(returnRequest.notes!),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'approved':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'refunded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getRefundMethodDisplayName(String method) {
    switch (method) {
      case 'original':
        return 'Original Payment Method';
      case 'cash':
        return 'Cash Refund';
      case 'credit':
        return 'Credit Card Refund';
      case 'store_credit':
        return 'Store Credit';
      default:
        return method;
    }
  }

  String _getReasonName(String reasonId) {
    final reasons = {
      'defective': 'Defective Product',
      'wrong_item': 'Wrong Item Received',
      'damaged': 'Damaged Product',
      'not_as_described': 'Not as Described',
      'customer_change_mind': 'Changed Mind',
      'size_issue': 'Size Issue',
      'quality_issue': 'Quality Issue',
      'no_receipt': 'No Receipt',
    };
    return reasons[reasonId] ?? reasonId;
  }
}

class _CreateReturnScreenState extends State<CreateReturnScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final List<ReturnItem> _returnItems = [];
  AppOrder? _selectedOrder;
  String _returnReason = 'defective';
  String _refundMethod = 'original';
  String? _notes;
  bool _isProcessing = false;

  final List<ReturnReason> _returnReasons = [
    ReturnReason(
      id: 'defective',
      name: 'Defective Product',
      description: 'Product not working properly',
    ),
    ReturnReason(
      id: 'wrong_item',
      name: 'Wrong Item Received',
      description: 'Received different product',
    ),
    ReturnReason(
      id: 'damaged',
      name: 'Damaged Product',
      description: 'Product arrived damaged',
    ),
    ReturnReason(
      id: 'not_as_described',
      name: 'Not as Described',
      description: 'Product different from description',
    ),
    ReturnReason(
      id: 'customer_change_mind',
      name: 'Changed Mind',
      description: 'Customer changed their mind',
    ),
    ReturnReason(
      id: 'size_issue',
      name: 'Size Issue',
      description: 'Wrong size ordered',
    ),
    ReturnReason(
      id: 'quality_issue',
      name: 'Quality Issue',
      description: 'Poor quality product',
    ),
  ];

  final List<String> _refundMethods = [
    'original',
    'cash',
    'credit',
    'store_credit',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate with selected order if provided
    if (widget.selectedOrder != null) {
      _selectedOrder = widget.selectedOrder;
    }
  }

  void _searchOrder() async {
    final selectedOrder = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SearchOrderForReturnScreen()),
    );

    if (selectedOrder != null && selectedOrder is AppOrder) {
      setState(() {
        _selectedOrder = selectedOrder;
      });
    }
  }

  void _showAddItemsDialog() {
    if (_selectedOrder == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Items to Return'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _selectedOrder!.lineItems.length,
            itemBuilder: (context, index) {
              final item = _selectedOrder!.lineItems[index];
              final productName =
                  item['productName']?.toString() ?? 'Unknown Product';
              final quantity = item['quantity'] as int;
              final price = (item['price'] as num).toDouble();

              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(productName),
                  subtitle: Text(
                    'Qty: $quantity • ${Constants.CURRENCY_NAME}${price.toStringAsFixed(2)} each',
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.add, color: Colors.green),
                    onPressed: () {
                      _addReturnItem(
                        productName,
                        item['productId']?.toString() ?? '',
                        '',
                        quantity,
                        price,
                        _returnReason,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added $productName to return'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _addReturnItem(
      String productName,
      String productId,
      String sku,
      int quantity,
      double price,
      String reason,
      ) {
    setState(() {
      _returnItems.add(
        ReturnItem(
          productId: productId,
          productName: productName,
          productSku: sku,
          quantity: quantity,
          price: price,
          returnReason: reason,
        ),
      );
    });
  }

  void _removeReturnItem(int index) {
    setState(() {
      _returnItems.removeAt(index);
    });
  }

  void _updateReturnItemQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeReturnItem(index);
      return;
    }

    setState(() {
      _returnItems[index] = ReturnItem(
        productId: _returnItems[index].productId,
        productName: _returnItems[index].productName,
        productSku: _returnItems[index].productSku,
        quantity: newQuantity,
        price: _returnItems[index].price,
        returnReason: _returnItems[index].returnReason,
        notes: _returnItems[index].notes,
      );
    });
  }

  double get _totalRefundAmount {
    return _returnItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  Future<void> _processReturn() async {
    if (_returnItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please add items to return')));
      return;
    }

    if (_selectedOrder == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please select an order')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final returnRequest = ReturnRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        orderId: _selectedOrder!.id,
        orderNumber: _selectedOrder!.number,
        items: _returnItems,
        reason: _returnReason,
        status: 'completed',
        notes: _notes,
        dateCreated: DateTime.now(),
        refundAmount: _totalRefundAmount,
        refundMethod: _refundMethod,
        customerId: _selectedOrder!.lineItems.isNotEmpty
            ? _selectedOrder!.lineItems[0]['customerId']?.toString()
            : null,
      );

      await _posService.createReturn(returnRequest);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Return processed successfully! Refund: ${Constants.CURRENCY_NAME}${_totalRefundAmount.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process return: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildOrderSelection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            if (_selectedOrder == null)
              ElevatedButton(
                onPressed: _searchOrder,
                child: Text('Select Order'),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order: ${_selectedOrder!.number}',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Date: ${DateFormat('MMM dd, yyyy').format(_selectedOrder!.dateCreated)}',
                            ),
                            Text(
                              'Original Total: ${Constants.CURRENCY_NAME}${_selectedOrder!.total.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: _searchOrder,
                        tooltip: 'Change Order',
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddItemsDialog,
                    icon: Icon(Icons.add_shopping_cart),
                    label: Text('Add Items from Order'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReturnItemCard(ReturnItem item, int index) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.assignment_return, color: Colors.orange, size: 40),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (item.productSku.isNotEmpty)
                        Text(
                          'SKU: ${item.productSku}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      Text(
                        '${Constants.CURRENCY_NAME}${item.price.toStringAsFixed(2)} each',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeReturnItem(index),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Quantity:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, size: 18),
                        onPressed: () =>
                            _updateReturnItemQuantity(index, item.quantity - 1),
                        padding: EdgeInsets.zero,
                      ),
                      Text(
                        item.quantity.toString(),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, size: 18),
                        onPressed: () =>
                            _updateReturnItemQuantity(index, item.quantity + 1),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                Spacer(),
                Text(
                  'Subtotal: ${Constants.CURRENCY_NAME}${item.subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Process Return')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildOrderSelection(),
            SizedBox(height: 16),

            // Return Items
            if (_returnItems.isNotEmpty) ...[
              Text(
                'Return Items (${_returnItems.length})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _returnItems.length,
                  itemBuilder: (context, index) {
                    return _buildReturnItemCard(_returnItems[index], index);
                  },
                ),
              ),
            ],

            if (_returnItems.isEmpty) ...[
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text('No items added for return'),
                      SizedBox(height: 8),
                      Text(
                        'Add products from the order to process return',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Return Details
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField(
                      initialValue: _returnReason,
                      items: _returnReasons.map((reason) {
                        return DropdownMenuItem(
                          value: reason.id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(reason.name),
                              Text(
                                reason.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _returnReason = value!),
                      decoration: InputDecoration(labelText: 'Return Reason'),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField(
                      initialValue: _refundMethod,
                      items: _refundMethods.map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(_getRefundMethodDisplayName(method)),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _refundMethod = value!),
                      decoration: InputDecoration(labelText: 'Refund Method'),
                    ),
                    SizedBox(height: 12),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => _notes = value,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),

            // Total and Action
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Refund:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${Constants.CURRENCY_NAME}${_totalRefundAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
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
                      onPressed:
                      _returnItems.isNotEmpty &&
                          _selectedOrder != null
                          ? _processReturn
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      child: Text(
                        'PROCESS RETURN & REFUND',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRefundMethodDisplayName(String method) {
    switch (method) {
      case 'original':
        return 'Original Payment Method';
      case 'cash':
        return 'Cash Refund';
      case 'credit':
        return 'Credit Card Refund';
      case 'store_credit':
        return 'Store Credit';
      default:
        return method;
    }
  }
}

class ReturnRequestCard extends StatelessWidget {
  final ReturnRequest returnRequest;

  const ReturnRequestCard({super.key, required this.returnRequest});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Return #${returnRequest.id.substring(0, 8).toUpperCase()}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(returnRequest.status),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    returnRequest.status.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Order: ${returnRequest.orderNumber}',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text('Items: ${returnRequest.items.length}'),
            Text(
              'Refund: ${Constants.CURRENCY_NAME}${returnRequest.refundAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.green[700],
              ),
            ),
            Text(
              'Method: ${_getRefundMethodDisplayName(returnRequest.refundMethod)}',
            ),
            Text(
              'Date: ${DateFormat('MMM dd, yyyy').format(returnRequest.dateCreated)}',
            ),
            SizedBox(height: 8),
            if (returnRequest.notes != null && returnRequest.notes!.isNotEmpty)
              Text(
                'Notes: ${returnRequest.notes!}',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'approved':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'refunded':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getRefundMethodDisplayName(String method) {
    switch (method) {
      case 'original':
        return 'Original Payment';
      case 'cash':
        return 'Cash';
      case 'credit':
        return 'Credit Card';
      case 'store_credit':
        return 'Store Credit';
      default:
        return method;
    }
  }
} // Search Order for Return Screen

class SearchOrderForReturnScreen extends StatefulWidget {
  const SearchOrderForReturnScreen({super.key});

  @override
  _SearchOrderForReturnScreenState createState() =>
      _SearchOrderForReturnScreenState();
}

class _SearchOrderForReturnScreenState
    extends State<SearchOrderForReturnScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final TextEditingController _searchController = TextEditingController();
  final List<AppOrder> _searchResults = [];
  bool _isSearching = false;
  String _searchError = '';
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    // Load recent orders initially
    _loadRecentOrders();
  }

  Future<void> _loadRecentOrders() async {
    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    try {
      final recentOrders = await _posService.getRecentOrders(limit: 20);
      setState(() {
        _searchResults.clear();
        _searchResults.addAll(recentOrders);
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchError = 'Failed to load recent orders: $e';
        _isSearching = false;
      });
    }
  }

  void _searchOrders(String query) {
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      _loadRecentOrders();
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await _posService.searchOrders(query);
        setState(() {
          _searchResults.clear();
          _searchResults.addAll(results);
          _isSearching = false;
          if (results.isEmpty && query.isNotEmpty) {
            _searchError = 'No orders found for "$query"';
          }
        });
      } catch (e) {
        setState(() {
          _searchError = 'Search failed: $e';
          _isSearching = false;
        });
      }
    });
  }

  void _selectOrder(AppOrder order) {
    Navigator.pop(context, order);
  }

  void _scanOrderBarcode() async {
    final barcode = await UniversalScanningService.scanBarcode(
      context,
      purpose: 'return',
    );
    if (barcode != null && barcode.isNotEmpty) {
      _searchController.text = barcode;
      _searchOrders(barcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Find Order for Return')),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by order number...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: _searchOrders,
                  ),
                ),
                SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.qr_code_scanner),
                  onPressed: _scanOrderBarcode,
                  tooltip: 'Scan Order Barcode',
                ),
              ],
            ),
          ),

          // Search Results
          Expanded(
            child: _isSearching
                ? Center(child: CircularProgressIndicator())
                : _searchError.isNotEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(_searchError, textAlign: TextAlign.center),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadRecentOrders,
                    child: Text('Show Recent Orders'),
                  ),
                ],
              ),
            )
                : _searchResults.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text('No orders found'),
                  SizedBox(height: 8),
                  Text(
                    'Search for orders or scan order barcode',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final order = _searchResults[index];
                return OrderCard(
                  order: order,
                  onSelect: () => _selectOrder(order),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}

class ReturnAnyProductScreen extends StatefulWidget {
  const ReturnAnyProductScreen({super.key});

  @override
  _ReturnAnyProductScreenState createState() => _ReturnAnyProductScreenState();
}

class _ReturnAnyProductScreenState extends State<ReturnAnyProductScreen> {
  final EnhancedPOSService _posService = EnhancedPOSService();
  final List<ReturnItem> _returnItems = [];
  String _returnReason = 'defective';
  String _refundMethod = 'cash';
  String? _notes;
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
  TextEditingController();
  bool _isProcessing = false;

  final List<ReturnReason> _returnReasons = [
    ReturnReason(
      id: 'defective',
      name: 'Defective Product',
      description: 'Product not working properly',
    ),
    ReturnReason(
      id: 'wrong_item',
      name: 'Wrong Item Received',
      description: 'Received different product',
    ),
    ReturnReason(
      id: 'damaged',
      name: 'Damaged Product',
      description: 'Product arrived damaged',
    ),
    ReturnReason(
      id: 'not_as_described',
      name: 'Not as Described',
      description: 'Product different from description',
    ),
    ReturnReason(
      id: 'customer_change_mind',
      name: 'Changed Mind',
      description: 'Customer changed their mind',
    ),
    ReturnReason(
      id: 'size_issue',
      name: 'Size Issue',
      description: 'Wrong size ordered',
    ),
    ReturnReason(
      id: 'quality_issue',
      name: 'Quality Issue',
      description: 'Poor quality product',
    ),
    ReturnReason(
      id: 'no_receipt',
      name: 'No Receipt',
      description: 'Return without proof of purchase',
    ),
  ];
  Future<void> _processReturn() async {
    if (_returnItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please add products to return')));
      return;
    }

    if (_customerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter customer name')));
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final returnRequest = ReturnRequest(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        orderId: 'no_order',
        orderNumber: 'N/A-${DateTime.now().millisecondsSinceEpoch}',
        items: _returnItems,
        reason: _returnReason,
        status: 'completed',
        notes: _notes,
        dateCreated: DateTime.now(),
        refundAmount: _totalRefundAmount,
        refundMethod: _refundMethod,
        customerId: null,
        customerInfo: {
          'name': _customerNameController.text.trim(),
          'phone': _customerPhoneController.text.trim().isEmpty
              ? 'N/A'
              : _customerPhoneController.text.trim(),
          'type': 'walk_in',
          'timestamp': DateTime.now().toIso8601String(),
        },
        isOffline: !_posService.isOnline,
      );

      final result = await _posService.createReturn(returnRequest);

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Return processed successfully! Refund: ${Constants.CURRENCY_NAME}${_totalRefundAmount.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else if (result.isOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Return saved offline. Will sync when online. Refund: ${Constants.CURRENCY_NAME}${_totalRefundAmount.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        throw Exception(result.error);
      }

      Navigator.of(context).pop();
    } catch (e) {
      print('Error processing return: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to process return: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  final List<String> _refundMethods = ['cash', 'store_credit', 'exchange'];

  void _searchAndAddProduct() async {
    final product = await showDialog<Product>(
      context: context,
      builder: (context) => ProductSearchDialog(posService: _posService),
    );

    if (product != null) {
      _showAddProductDialog(product);
    }
  }

  void _scanAndAddProduct() async {
    final barcode = await UniversalScanningService.scanBarcode(
      context,
      purpose: 'return',
    );
    if (barcode != null && barcode.isNotEmpty) {
      try {
        final products = await _posService.searchProductsBySKU(barcode);
        if (products.isNotEmpty) {
          _showAddProductDialog(products.first);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No product found with barcode: $barcode'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddProductDialog(Product product) {
    final quantityController = TextEditingController(text: '1');
    final priceController = TextEditingController(
      text: product.price.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Return ${product.name}'),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        image: product.imageUrl != null
                            ? DecorationImage(
                          image: NetworkImage(product.imageUrl!),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                      child: product.imageUrl == null
                          ? Icon(Icons.shopping_bag, color: Colors.grey)
                          : null,
                    ),
                    title: Text(
                      product.name,
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (product.sku.isNotEmpty) Text('SKU: ${product.sku}'),
                        Text('Current Stock: ${product.stockQuantity}'),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      // Validate quantity doesn't exceed stock
                      final quantity = int.tryParse(value) ?? 0;
                      if (quantity > product.stockQuantity) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Quantity cannot exceed available stock (${product.stockQuantity})',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: 'Refund Price',
                      border: OutlineInputBorder(),
                      prefixText: Constants.CURRENCY_NAME,
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField(
                    initialValue: _returnReason,
                    items: _returnReasons.map((reason) {
                      return DropdownMenuItem(
                        value: reason.id,
                        child: Text(reason.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        _returnReason = value!;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Return Reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final quantity = int.tryParse(quantityController.text) ?? 0;
                  final price =
                      double.tryParse(priceController.text) ?? product.price;

                  if (quantity <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Please enter valid quantity')),
                    );
                    return;
                  }

                  if (quantity > product.stockQuantity) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Quantity cannot exceed available stock'),
                      ),
                    );
                    return;
                  }

                  _addReturnItem(product, quantity, price, _returnReason);
                  Navigator.pop(context);
                },
                child: Text('Add to Return'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _addReturnItem(
      Product product,
      int quantity,
      double price,
      String reason,
      ) {
    setState(() {
      _returnItems.add(
        ReturnItem(
          productId: product.id,
          productName: product.name,
          productSku: product.sku,
          quantity: quantity,
          price: price,
          returnReason: reason,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${product.name} to return'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeReturnItem(int index) {
    setState(() {
      _returnItems.removeAt(index);
    });
  }

  void _updateReturnItemQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      _removeReturnItem(index);
      return;
    }

    setState(() {
      _returnItems[index] = ReturnItem(
        productId: _returnItems[index].productId,
        productName: _returnItems[index].productName,
        productSku: _returnItems[index].productSku,
        quantity: newQuantity,
        price: _returnItems[index].price,
        returnReason: _returnItems[index].returnReason,
        notes: _returnItems[index].notes,
      );
    });
  }

  double get _totalRefundAmount {
    return _returnItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  Widget _buildReturnItemCard(ReturnItem item, int index) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.shopping_bag, color: Colors.orange),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (item.productSku.isNotEmpty)
                        Text(
                          'SKU: ${item.productSku}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      Text(
                        '${Constants.CURRENCY_NAME}${item.price.toStringAsFixed(2)} each',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[700],
                        ),
                      ),
                      Text(
                        'Reason: ${_getReasonName(item.returnReason)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeReturnItem(index),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Quantity:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove, size: 18),
                        onPressed: () =>
                            _updateReturnItemQuantity(index, item.quantity - 1),
                        padding: EdgeInsets.zero,
                      ),
                      Text(
                        item.quantity.toString(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add, size: 18),
                        onPressed: () =>
                            _updateReturnItemQuantity(index, item.quantity + 1),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                Spacer(),
                Text(
                  '${Constants.CURRENCY_NAME}${item.subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Return Products (No Order)'),
        actions: [
          if (_returnItems.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep),
              onPressed: () {
                setState(() {
                  _returnItems.clear();
                });
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('All items removed')));
              },
              tooltip: 'Clear All Items',
            ),
        ],
      ),
      body: Column(
        children: [
          // Customer Information
          Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customer Information',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _customerNameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      hintText: 'Enter customer name',
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _customerPhoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number (Optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      hintText: 'Enter phone number',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),

          // Add Products Section
          Card(
            margin: EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Products to Return',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _searchAndAddProduct,
                          icon: Icon(Icons.search, size: 20),
                          label: Text('Search Product'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _scanAndAddProduct,
                          icon: Icon(Icons.qr_code_scanner, size: 20),
                          label: Text('Scan Barcode'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_returnItems.isNotEmpty) ...[
                    SizedBox(height: 12),
                    Text(
                      '${_returnItems.length} item${_returnItems.length > 1 ? 's' : ''} added',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 8),

          // Return Items List
          if (_returnItems.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Return Items (${_returnItems.length})',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Total: ${Constants.CURRENCY_NAME}${_totalRefundAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: _returnItems.length,
                itemBuilder: (context, index) {
                  return _buildReturnItemCard(_returnItems[index], index);
                },
              ),
            ),
          ],

          if (_returnItems.isEmpty) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No products added for return',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Use search or barcode scan to add products',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _searchAndAddProduct,
                      icon: Icon(Icons.add),
                      label: Text('Add First Product'),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Return Details and Action Section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                // Return Details
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        DropdownButtonFormField(
                          initialValue: _returnReason,
                          items: _returnReasons.map((reason) {
                            return DropdownMenuItem(
                              value: reason.id,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(reason.name),
                                  Text(
                                    reason.description,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _returnReason = value!),
                          decoration: InputDecoration(
                            labelText: 'Return Reason',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 12),
                        DropdownButtonFormField(
                          initialValue: _refundMethod,
                          items: _refundMethods.map((method) {
                            return DropdownMenuItem(
                              value: method,
                              child: Text(_getRefundMethodDisplayName(method)),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => _refundMethod = value!),
                          decoration: InputDecoration(
                            labelText: 'Refund Method',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Notes (Optional)',
                            border: OutlineInputBorder(),
                            hintText:
                            'Any additional notes about this return...',
                          ),
                          onChanged: (value) => _notes = value,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Total and Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Refund:', style: TextStyle(fontSize: 16)),
                        Text(
                          '${Constants.CURRENCY_NAME}${_totalRefundAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: 200,
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
                        onPressed:
                        _returnItems.isNotEmpty &&
                            _customerNameController.text
                                .trim()
                                .isNotEmpty
                            ? _processReturn
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: Text(
                          'PROCESS RETURN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRefundMethodDisplayName(String method) {
    switch (method) {
      case 'cash':
        return 'Cash Refund';
      case 'store_credit':
        return 'Store Credit';
      case 'exchange':
        return 'Exchange Only';
      default:
        return method;
    }
  }

  String _getReasonName(String reasonId) {
    final reason = _returnReasons.firstWhere(
          (reason) => reason.id == reasonId,
      orElse: () => _returnReasons.first,
    );
    return reason.name;
  }
}



class ProductSearchDialog extends StatefulWidget {
  final EnhancedPOSService posService;

  const ProductSearchDialog({super.key, required this.posService});

  @override
  _ProductSearchDialogState createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<ProductSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final List<Product> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    // Load some initial products
    _loadInitialProducts();
  }

  void _loadInitialProducts() async {
    setState(() => _isSearching = true);
    try {
      final products = await widget.posService.fetchProducts(limit: 20);
      setState(() {
        _searchResults.clear();
        _searchResults.addAll(products);
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  void _searchProducts(String query) {
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      _loadInitialProducts();
      return;
    }

    setState(() => _isSearching = true);

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await widget.posService.searchProducts(query);
        setState(() {
          _searchResults.clear();
          _searchResults.addAll(results);
          _isSearching = false;
        });
      } catch (e) {
        setState(() => _isSearching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.all(20),
      child: Container(
        padding: EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Text(
              'Search Product',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by product name or SKU...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _loadInitialProducts();
                  },
                )
                    : null,
              ),
              onChanged: _searchProducts,
              autofocus: true,
            ),
            SizedBox(height: 16),
            if (_isSearching)
              Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_searchResults.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Search for products to return'
                            : 'No products found for "${_searchController.text}"',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final product = _searchResults[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            image: product.imageUrl != null
                                ? DecorationImage(
                              image: NetworkImage(product.imageUrl!),
                              fit: BoxFit.cover,
                            )
                                : null,
                          ),
                          child: product.imageUrl == null
                              ? Icon(Icons.shopping_bag, color: Colors.grey)
                              : null,
                        ),
                        title: Text(
                          product.name,
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.sku.isNotEmpty)
                              Text('SKU: ${product.sku}'),
                            Text(
                              '${Constants.CURRENCY_NAME}${product.price.toStringAsFixed(2)} • Stock: ${product.stockQuantity}',
                            ),
                          ],
                        ),
                        trailing: Icon(Icons.arrow_forward, color: Colors.blue),
                        onTap: () => Navigator.pop(context, product),
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
