import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../core/models/app_order_model.dart';

class OrderCard extends StatelessWidget {
  final AppOrder order;
  final VoidCallback onSelect;

  const OrderCard({super.key, required this.order, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue[50],
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.receipt, color: Colors.blue),
        ),
        title: Text('Order ${order.number}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM dd, yyyy - HH:mm').format(order.dateCreated)),
            Text(
              '${order.lineItems.length} items • ${Constants.CURRENCY_NAME}${order.total.toStringAsFixed(2)}',
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onSelect,
      ),
    );
  }
}
// order_status.dart

enum OrderStatus {
  all,
  pending,
  confirmed,
  processing,
  ready,
  completed,
  cancelled,
  refunded,
  onHold,
  failed,
  partiallyRefunded
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.all:
        return 'All Orders';
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.processing:
        return 'Processing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
      case OrderStatus.refunded:
        return 'Refunded';
      case OrderStatus.onHold:
        return 'On Hold';
      case OrderStatus.failed:
        return 'Failed';
      case OrderStatus.partiallyRefunded:
        return 'Partially Refunded';
    }
  }

  String get description {
    switch (this) {
      case OrderStatus.all:
        return 'All orders regardless of status';
      case OrderStatus.pending:
        return 'Order received but payment pending';
      case OrderStatus.confirmed:
        return 'Payment confirmed, preparing order';
      case OrderStatus.processing:
        return 'Order is being processed';
      case OrderStatus.ready:
        return 'Order is ready for pickup/delivery';
      case OrderStatus.completed:
        return 'Order successfully delivered/fulfilled';
      case OrderStatus.cancelled:
        return 'Order was cancelled';
      case OrderStatus.refunded:
        return 'Order was fully refunded';
      case OrderStatus.onHold:
        return 'Order placed on hold';
      case OrderStatus.failed:
        return 'Order processing failed';
      case OrderStatus.partiallyRefunded:
        return 'Order was partially refunded';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.all:
        return Colors.grey;
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.processing:
        return Colors.lightBlue;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.refunded:
        return Colors.purple;
      case OrderStatus.onHold:
        return Colors.amber;
      case OrderStatus.failed:
        return Colors.red;
      case OrderStatus.partiallyRefunded:
        return Colors.deepPurple;
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.all:
        return Icons.list_alt;
      case OrderStatus.pending:
        return Icons.pending;
      case OrderStatus.confirmed:
        return Icons.verified;
      case OrderStatus.processing:
        return Icons.autorenew;
      case OrderStatus.ready:
        return Icons.assignment_turned_in;
      case OrderStatus.completed:
        return Icons.check_circle;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.refunded:
        return Icons.money_off;
      case OrderStatus.onHold:
        return Icons.pause_circle;
      case OrderStatus.failed:
        return Icons.error;
      case OrderStatus.partiallyRefunded:
        return Icons.payment;
    }
  }

  int get priority {
    switch (this) {
      case OrderStatus.pending:
        return 1;
      case OrderStatus.confirmed:
        return 2;
      case OrderStatus.processing:
        return 3;
      case OrderStatus.ready:
        return 4;
      case OrderStatus.completed:
        return 5;
      case OrderStatus.onHold:
        return 6;
      case OrderStatus.partiallyRefunded:
        return 7;
      case OrderStatus.refunded:
        return 8;
      case OrderStatus.cancelled:
        return 9;
      case OrderStatus.failed:
        return 10;
      case OrderStatus.all:
        return 0;
    }
  }

  bool get isActive {
    return this == OrderStatus.pending ||
        this == OrderStatus.confirmed ||
        this == OrderStatus.processing ||
        this == OrderStatus.ready ||
        this == OrderStatus.onHold;
  }

  bool get isCompleted {
    return this == OrderStatus.completed;
  }

  bool get isCancelled {
    return this == OrderStatus.cancelled || this == OrderStatus.failed;
  }

  bool get isRefunded {
    return this == OrderStatus.refunded || this == OrderStatus.partiallyRefunded;
  }
}

class OrderStatusUtils {
  static List<OrderStatus> get activeStatuses {
    return [
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.processing,
      OrderStatus.ready,
      OrderStatus.onHold,
    ];
  }

  static List<OrderStatus> get completedStatuses {
    return [
      OrderStatus.completed,
    ];
  }

  static List<OrderStatus> get cancelledStatuses {
    return [
      OrderStatus.cancelled,
      OrderStatus.failed,
    ];
  }

  static List<OrderStatus> get refundStatuses {
    return [
      OrderStatus.refunded,
      OrderStatus.partiallyRefunded,
    ];
  }

  static List<OrderStatus> get filterableStatuses {
    return OrderStatus.values.where((status) => status != OrderStatus.all).toList();
  }

  static OrderStatus fromString(String statusString) {
    switch (statusString.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'processing':
        return OrderStatus.processing;
      case 'ready':
        return OrderStatus.ready;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
      case 'canceled':
        return OrderStatus.cancelled;
      case 'refunded':
        return OrderStatus.refunded;
      case 'onhold':
      case 'on_hold':
        return OrderStatus.onHold;
      case 'failed':
        return OrderStatus.failed;
      case 'partially_refunded':
      case 'partiallyrefunded':
        return OrderStatus.partiallyRefunded;
      default:
        return OrderStatus.pending;
    }
  }

  static String toFirestoreValue(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.processing:
        return 'processing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.refunded:
        return 'refunded';
      case OrderStatus.onHold:
        return 'onHold';
      case OrderStatus.failed:
        return 'failed';
      case OrderStatus.partiallyRefunded:
        return 'partiallyRefunded';
      case OrderStatus.all:
        return 'all';
    }
  }

  static OrderStatus fromFirestoreValue(String value) {
    return fromString(value);
  }
}


