// analytics_screen.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mpcm/sales/sales_management_screen.dart';
import 'package:mpcm/theme_utils.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:provider/provider.dart';
import 'constants.dart';
import 'app.dart';
import 'features/auth/auth_base.dart';
import 'features/customerBase/customer_base.dart';
import 'features/orderBase/order_base.dart';
import 'features/product_addition_restock_base/product_addition_restock_base.dart';
import 'features/product_selling/product_selling_base.dart';
import 'main.dart';
import 'modules/auth/providers/auth_provider.dart';

// Enhanced Analytics Data Models
class SalesAnalytics {
  final double totalSales;
  final int totalOrders;
  final int totalItemsSold;
  final double averageOrderValue;
  final Map<String, double> salesByHour;
  final Map<String, double> salesByDay;
  final List<ProductPerformance> topProducts;
  final List<CategoryPerformance> topCategories;

  // New financial breakdown fields
  final double subtotalAmount;
  final double totalDiscounts;
  final double itemDiscounts;
  final double cartDiscounts;
  final double additionalDiscounts;
  final double taxAmount;
  final double shippingAmount;
  final double tipAmount;
  final double taxableAmount;
  final Map<String, double> discountTypes;
  final Map<String, double> paymentMethodDistribution;

  SalesAnalytics({
    required this.totalSales,
    required this.totalOrders,
    required this.totalItemsSold,
    required this.averageOrderValue,
    required this.salesByHour,
    required this.salesByDay,
    required this.topProducts,
    required this.topCategories,

    // New financial breakdown
    required this.subtotalAmount,
    required this.totalDiscounts,
    required this.itemDiscounts,
    required this.cartDiscounts,
    required this.additionalDiscounts,
    required this.taxAmount,
    required this.shippingAmount,
    required this.tipAmount,
    required this.taxableAmount,
    required this.discountTypes,
    required this.paymentMethodDistribution,
  });
}

class FinancialBreakdown {
  final double subtotal;
  final double discounts;
  final double taxes;
  final double shipping;
  final double tips;
  final double total;

  FinancialBreakdown({
    required this.subtotal,
    required this.discounts,
    required this.taxes,
    required this.shipping,
    required this.tips,
    required this.total,
  });
}

class DiscountAnalytics {
  final double totalDiscounts;
  final double averageDiscountPerOrder;
  final double discountRate;
  final Map<String, double> discountByType;
  final List<AppOrder> highestDiscountOrders;

  DiscountAnalytics({
    required this.totalDiscounts,
    required this.averageDiscountPerOrder,
    required this.discountRate,
    required this.discountByType,
    required this.highestDiscountOrders,
  });
}

class TaxAnalytics {
  final double totalTaxCollected;
  final double averageTaxPerOrder;
  final double effectiveTaxRate;
  final Map<String, double> taxByType;

  TaxAnalytics({
    required this.totalTaxCollected,
    required this.averageTaxPerOrder,
    required this.effectiveTaxRate,
    required this.taxByType,
  });
}

class ProductPerformance {
  final Product product;
  final int quantitySold;
  final double revenue;
  final double percentage;
  final double discountAmount;
  final double netRevenue;

  ProductPerformance({
    required this.product,
    required this.quantitySold,
    required this.revenue,
    required this.percentage,
    required this.discountAmount,
    required this.netRevenue,
  });
}

class CategoryPerformance {
  final Category category;
  final int quantitySold;
  final double revenue;
  final double percentage;
  final double discountAmount;

  CategoryPerformance({
    required this.category,
    required this.quantitySold,
    required this.revenue,
    required this.percentage,
    required this.discountAmount,
  });
}

class TimePeriod {
  final String label;
  final DateTime startDate;
  final DateTime endDate;

  TimePeriod({
    required this.label,
    required this.startDate,
    required this.endDate,
  });
}

// Customer Analytics Data Models
class CustomerAnalytics {
  final int totalCustomers;
  final int newCustomers;
  final double? averageOrderValue;
  final double? repeatCustomerRate;
  final double customerGrowth;
  final List<CustomerSegment> customerSegmentation;
  final List<TopCustomer> topCustomers;
  final List<AcquisitionData> acquisitionData;
  final RetentionMetrics? retentionMetrics;
  final List<LocationData> locationData;

  CustomerAnalytics({
    required this.totalCustomers,
    required this.newCustomers,
    this.averageOrderValue,
    this.repeatCustomerRate,
    required this.customerGrowth,
    required this.customerSegmentation,
    required this.topCustomers,
    required this.acquisitionData,
    this.retentionMetrics,
    required this.locationData,
  });
}

class CustomerSegment {
  final String segment;
  final int count;
  final double percentage;

  CustomerSegment({
    required this.segment,
    required this.count,
    required this.percentage,
  });
}

class TopCustomer {
  final String customerId;
  final String customerName;
  final String email;
  final int totalOrders;
  final double totalSpent;
  final DateTime lastOrderDate;
  final String tier;

  TopCustomer({
    required this.customerId,
    required this.customerName,
    required this.email,
    required this.totalOrders,
    required this.totalSpent,
    required this.lastOrderDate,
    required this.tier,
  });
}

class AcquisitionData {
  final String period;
  final int newCustomers;
  final int returningCustomers;

  AcquisitionData({
    required this.period,
    required this.newCustomers,
    required this.returningCustomers,
  });
}

class RetentionMetrics {
  final double retention30Days;
  final double retention90Days;
  final double churnRate;
  final double averageLifetimeValue;

  RetentionMetrics({
    required this.retention30Days,
    required this.retention90Days,
    required this.churnRate,
    required this.averageLifetimeValue,
  });
}

class LocationData {
  final String city;
  final String state;
  final int customerCount;
  final double totalRevenue;

  LocationData({
    required this.city,
    required this.state,
    required this.customerCount,
    required this.totalRevenue,
  });
}

class ChartData {
  final String x;
  final double y;

  ChartData(this.x, this.y);
}

// Time Periods Utility
class TimePeriods {
  static final today = TimePeriod(
    label: 'Today',
    startDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    endDate: DateTime.now(),
  );

  static final yesterday = TimePeriod(
    label: 'Yesterday',
    startDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1),
    endDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day - 1, 23, 59, 59),
  );

  static final thisWeek = TimePeriod(
    label: 'This Week',
    startDate: DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)),
    endDate: DateTime.now(),
  );

  static final lastWeek = TimePeriod(
    label: 'Last Week',
    startDate: DateTime.now().subtract(Duration(days: DateTime.now().weekday + 6)),
    endDate: DateTime.now().subtract(Duration(days: DateTime.now().weekday)),
  );

  static final thisMonth = TimePeriod(
    label: 'This Month',
    startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
    endDate: DateTime.now(),
  );

  static final lastMonth = TimePeriod(
    label: 'Last Month',
    startDate: DateTime(DateTime.now().year, DateTime.now().month - 1, 1),
    endDate: DateTime(DateTime.now().year, DateTime.now().month, 0),
  );

  static final allPeriods = [today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth];
}

// Enhanced Analytics Service with Financial Breakdown
class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentTenantId;

  void setTenantId(String tenantId) {
    _currentTenantId = tenantId;
  }

  // Updated collection references with tenant isolation
  CollectionReference get ordersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('orders');

  CollectionReference get customersRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('customers');

  CollectionReference get productsRef => _firestore
      .collection('tenants')
      .doc(_currentTenantId)
      .collection('products');

// Enhanced Sales Analytics to include proper discount breakdown
  Future<SalesAnalytics> getSalesAnalytics(TimePeriod period) async {
    try {
      if (_currentTenantId == null) {
        throw Exception('Tenant ID not set');
      }

      final ordersSnapshot = await ordersRef
          .where('dateCreated', isGreaterThanOrEqualTo: period.startDate)
          .where('dateCreated', isLessThanOrEqualTo: period.endDate)
          .get();

      final orders = ordersSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AppOrder.fromFirestore(data, doc.id);
      }).toList();

      // Calculate comprehensive financial metrics
      double subtotalAmount = 0.0;
      double totalDiscounts = 0.0;
      double itemDiscounts = 0.0;
      double cartDiscounts = 0.0;
      double additionalDiscounts = 0.0;
      double taxAmount = 0.0;
      double shippingAmount = 0.0;
      double tipAmount = 0.0;
      double taxableAmount = 0.0;

      final discountTypes = <String, double>{
        'Item Discounts': 0.0,
        'Cart Discounts': 0.0,
        'Additional Discounts': 0.0,
      };

      final paymentMethodDistribution = <String, double>{};

      for (final order in orders) {
        final orderData = order.toFirestore();
        final cartData = orderData['cartData'] as Map<String, dynamic>?;
        final pricingBreakdown = cartData?['pricing_breakdown'] as Map<String, dynamic>?;

        // Extract financial data from cart data and order data
        if (pricingBreakdown != null) {
          // Subtotal
          subtotalAmount += (pricingBreakdown['subtotal'] ?? order.total) as double;

          // Discounts
          final orderItemDiscounts = (pricingBreakdown['item_discounts'] ?? 0.0) as double;
          final orderCartDiscounts = (pricingBreakdown['cart_discount_amount'] ?? 0.0) as double;
          final orderTotalDiscount = (pricingBreakdown['total_discount'] ?? 0.0) as double;

          itemDiscounts += orderItemDiscounts;
          cartDiscounts += orderCartDiscounts;
          totalDiscounts += orderTotalDiscount;

          discountTypes['Item Discounts'] = discountTypes['Item Discounts']! + orderItemDiscounts;
          discountTypes['Cart Discounts'] = discountTypes['Cart Discounts']! + orderCartDiscounts;

          // Taxes
          taxAmount += (pricingBreakdown['tax_amount'] ?? 0.0) as double;

          // Taxable amount
          taxableAmount += (pricingBreakdown['taxable_amount'] ?? order.total) as double;
        } else {
          // Fallback if pricing breakdown is not available
          subtotalAmount += order.total;
        }

        // Additional discount from order level
        final orderAdditionalDiscount = (orderData['additionalDiscount'] ?? 0.0) as double;
        additionalDiscounts += orderAdditionalDiscount;
        totalDiscounts += orderAdditionalDiscount;
        discountTypes['Additional Discounts'] = discountTypes['Additional Discounts']! + orderAdditionalDiscount;

        // Shipping and tips
        shippingAmount += (orderData['shippingAmount'] ?? 0.0) as double;
        tipAmount += (orderData['tipAmount'] ?? 0.0) as double;

        // Payment method distribution
        final paymentMethod = orderData['paymentMethod'] ?? 'cash';
        paymentMethodDistribution[paymentMethod] =
            (paymentMethodDistribution[paymentMethod] ?? 0.0) + order.total;
      }

      final totalSales = orders.fold(0.0, (sum, order) => sum + order.total);
      final totalOrders = orders.length;
      final totalItemsSold = orders.fold(0, (sum, order) {
        return sum + (order.lineItems).fold(0, (itemSum, item) {
          final itemMap = item as Map<String, dynamic>;
          return itemSum + (itemMap['quantity'] as int);
        });
      });

      final averageOrderValue = totalOrders > 0 ? totalSales / totalOrders : 0.0;

      // Rest of your existing code for salesByHour, salesByDay, topProducts, etc.
      final salesByHour = <String, double>{};
      for (int hour = 0; hour < 24; hour++) {
        final hourSales = orders.where((order) {
          return order.dateCreated.hour == hour;
        }).fold(0.0, (sum, order) => sum + order.total);
        salesByHour['${hour.toString().padLeft(2, '0')}:00'] = hourSales;
      }

      final salesByDay = <String, double>{};
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      for (final day in days) {
        salesByDay[day] = 0.0;
      }

      for (final order in orders) {
        final dayName = DateFormat('E').format(order.dateCreated);
        salesByDay[dayName] = (salesByDay[dayName] ?? 0) + order.total;
      }

      final productSales = <String, Map<String, dynamic>>{};
      for (final order in orders) {
        for (final item in order.lineItems) {
          final itemMap = item as Map<String, dynamic>;
          final productId = itemMap['productId'].toString();
          final quantity = itemMap['quantity'] as int;
          final price = (itemMap['price'] as num).toDouble();
          final discount = (itemMap['discountAmount'] ?? 0.0) as double;

          if (!productSales.containsKey(productId)) {
            productSales[productId] = {
              'product': await _getProductById(productId),
              'quantity': 0,
              'revenue': 0.0,
              'discount': 0.0,
            };
          }

          productSales[productId]!['quantity'] += quantity;
          productSales[productId]!['revenue'] += quantity * price;
          productSales[productId]!['discount'] += discount;
        }
      }

      final topProducts = productSales.values
          .where((data) => data['product'] != null)
          .map((data) => ProductPerformance(
        product: data['product'] as Product,
        quantitySold: data['quantity'] as int,
        revenue: data['revenue'] as double,
        percentage: totalSales > 0 ? (data['revenue'] as double) / totalSales * 100 : 0,
        discountAmount: data['discount'] as double,
        netRevenue: (data['revenue'] as double) - (data['discount'] as double),
      ))
          .toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue));

      final topCategories = <CategoryPerformance>[];

      return SalesAnalytics(
        totalSales: totalSales,
        totalOrders: totalOrders,
        totalItemsSold: totalItemsSold,
        averageOrderValue: averageOrderValue,
        salesByHour: salesByHour,
        salesByDay: salesByDay,
        topProducts: topProducts.take(5).toList(),
        topCategories: topCategories,

        // Corrected financial breakdown
        subtotalAmount: subtotalAmount,
        totalDiscounts: totalDiscounts,
        itemDiscounts: itemDiscounts,
        cartDiscounts: cartDiscounts,
        additionalDiscounts: additionalDiscounts,
        taxAmount: taxAmount,
        shippingAmount: shippingAmount,
        tipAmount: tipAmount,
        taxableAmount: taxableAmount,
        discountTypes: discountTypes,
        paymentMethodDistribution: paymentMethodDistribution,
      );
    } catch (e) {
      print('Error in getSalesAnalytics: $e');
      throw Exception('Failed to fetch analytics: $e');
    }
  }
  Future<FinancialBreakdown> getFinancialBreakdown(TimePeriod period) async {
    final analytics = await getSalesAnalytics(period);

    return FinancialBreakdown(
      subtotal: analytics.subtotalAmount,
      discounts: analytics.totalDiscounts,
      taxes: analytics.taxAmount,
      shipping: analytics.shippingAmount,
      tips: analytics.tipAmount,
      total: analytics.totalSales,
    );
  }

// Enhanced Discount Analytics in AnalyticsService class
  Future<DiscountAnalytics> getDiscountAnalytics(TimePeriod period) async {
    try {
      if (_currentTenantId == null) {
        throw Exception('Tenant ID not set');
      }

      final ordersSnapshot = await ordersRef
          .where('dateCreated', isGreaterThanOrEqualTo: period.startDate)
          .where('dateCreated', isLessThanOrEqualTo: period.endDate)
          .get();

      final orders = ordersSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AppOrder.fromFirestore(data, doc.id);
      }).toList();

      // Calculate comprehensive discount metrics
      double totalDiscounts = 0.0;
      double itemDiscounts = 0.0;
      double cartDiscounts = 0.0;
      double additionalDiscounts = 0.0;
      double subtotalAmount = 0.0;

      final discountByType = <String, double>{
        'Item Discounts': 0.0,
        'Cart Discounts': 0.0,
        'Additional Discounts': 0.0,
      };

      for (final order in orders) {
        final orderData = order.toFirestore();

        // Extract cart data which contains the detailed discount breakdown
        final cartData = orderData['cartData'] as Map<String, dynamic>?;
        final pricingBreakdown = cartData?['pricing_breakdown'] as Map<String, dynamic>?;

        if (pricingBreakdown != null) {
          // Extract discounts from pricing breakdown
          final orderItemDiscounts = (pricingBreakdown['item_discounts'] ?? 0.0) as double;
          final orderCartDiscounts = (pricingBreakdown['cart_discount_amount'] ?? 0.0) as double;
          final orderTotalDiscount = (pricingBreakdown['total_discount'] ?? 0.0) as double;

          itemDiscounts += orderItemDiscounts;
          cartDiscounts += orderCartDiscounts;
          totalDiscounts += orderTotalDiscount;

          discountByType['Item Discounts'] = discountByType['Item Discounts']! + orderItemDiscounts;
          discountByType['Cart Discounts'] = discountByType['Cart Discounts']! + orderCartDiscounts;
        }

        // Extract additional discount from order data
        final orderAdditionalDiscount = (orderData['additionalDiscount'] ?? 0.0) as double;
        additionalDiscounts += orderAdditionalDiscount;
        discountByType['Additional Discounts'] = discountByType['Additional Discounts']! + orderAdditionalDiscount;

        // Calculate subtotal for discount rate calculation
        subtotalAmount += (cartData?['subtotal'] ?? order.total + totalDiscounts) as double;
      }

      // Calculate rates and averages
      final averageDiscountPerOrder = orders.isNotEmpty ? totalDiscounts / orders.length : 0.0;
      final discountRate = subtotalAmount > 0 ? (totalDiscounts / subtotalAmount) * 100 : 0.0;

      // Get highest discount orders
      final highestDiscountOrders = await _getHighestDiscountOrders(period);

      return DiscountAnalytics(
        totalDiscounts: totalDiscounts,
        averageDiscountPerOrder: averageDiscountPerOrder,
        discountRate: discountRate,
        discountByType: discountByType,
        highestDiscountOrders: highestDiscountOrders,
      );
    } catch (e) {
      print('Error in getDiscountAnalytics: $e');
      throw Exception('Failed to fetch discount analytics: $e');
    }
  }

  Future<TaxAnalytics> getTaxAnalytics(TimePeriod period) async {
    final analytics = await getSalesAnalytics(period);

    return TaxAnalytics(
      totalTaxCollected: analytics.taxAmount,
      averageTaxPerOrder: analytics.totalOrders > 0 ? analytics.taxAmount / analytics.totalOrders : 0.0,
      effectiveTaxRate: analytics.taxableAmount > 0 ? (analytics.taxAmount / analytics.taxableAmount) * 100 : 0.0,
      taxByType: {}, // You can expand this with different tax types if available
    );
  }

// Enhanced method to get highest discount orders
  Future<List<AppOrder>> _getHighestDiscountOrders(TimePeriod period) async {
    final ordersSnapshot = await ordersRef
        .where('dateCreated', isGreaterThanOrEqualTo: period.startDate)
        .where('dateCreated', isLessThanOrEqualTo: period.endDate)
        .get();

    final orders = ordersSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return AppOrder.fromFirestore(data, doc.id);
    }).toList();

    // Calculate discount amount for each order and sort by discount
    final ordersWithDiscounts = orders.map((order) {
      final orderData = order.toFirestore();
      final cartData = orderData['cartData'] as Map<String, dynamic>?;
      final pricingBreakdown = cartData?['pricing_breakdown'] as Map<String, dynamic>?;

      double discountAmount = 0.0;

      if (pricingBreakdown != null) {
        discountAmount = (pricingBreakdown['total_discount'] ?? 0.0) as double;
      }

      // Include additional discount
      discountAmount += (orderData['additionalDiscount'] ?? 0.0) as double;

      return {
        'order': order,
        'discountAmount': discountAmount,
        'discountPercentage': (order.total + discountAmount) > 0 ?
        (discountAmount / (order.total + discountAmount)) * 100 : 0.0,
      };
    }).toList();

    // Sort by discount amount (descending)
    ordersWithDiscounts.sort((a, b) {
      final aDiscount = (a['discountAmount'] ?? 0) as num;
      final bDiscount = (b['discountAmount'] ?? 0) as num;
      return bDiscount.compareTo(aDiscount);
    });


    return ordersWithDiscounts.take(5).map((item) => item['order'] as AppOrder).toList();
  }
  // Existing customer analytics methods
  Future<CustomerAnalytics> getCustomerAnalytics(TimePeriod period) async {
    try {
      if (_currentTenantId == null) {
        throw Exception('Tenant ID not set');
      }

      final customersSnapshot = await customersRef.get();
      final customers = customersSnapshot.docs.map((doc) {
        return Customer.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      final ordersSnapshot = await ordersRef
          .where('dateCreated', isGreaterThanOrEqualTo: period.startDate)
          .where('dateCreated', isLessThanOrEqualTo: period.endDate)
          .get();

      final totalCustomers = customers.length;
      final newCustomers = customers.where((c) {
        return c.dateCreated != null && c.dateCreated!.isAfter(period.startDate);
      }).length;

      final segmentation = _calculateCustomerSegmentation(customers);
      final topCustomers = await _getTopCustomers();
      final acquisitionData = await _getAcquisitionData(period);
      final retentionMetrics = await _calculateRetentionMetrics();
      final locationData = await _getLocationData(customers);

      return CustomerAnalytics(
        totalCustomers: totalCustomers,
        newCustomers: newCustomers,
        averageOrderValue: await _calculateAverageOrderValue(period),
        repeatCustomerRate: await _calculateRepeatCustomerRate(period),
        customerGrowth: await _calculateCustomerGrowth(period),
        customerSegmentation: segmentation,
        topCustomers: topCustomers,
        acquisitionData: acquisitionData,
        retentionMetrics: retentionMetrics,
        locationData: locationData,
      );
    } catch (e) {
      throw Exception('Failed to fetch customer analytics: $e');
    }
  }

  List<CustomerSegment> _calculateCustomerSegmentation(List<Customer> customers) {
    final total = customers.length;
    if (total == 0) return [];

    final vipCount = customers.where((c) => c.totalSpent > 1000).length;
    final regularCount = customers.where((c) => c.totalSpent > 100 && c.totalSpent <= 1000).length;
    final newCount = customers.where((c) => c.orderCount <= 1).length;
    final atRiskCount = customers.where((c) => c.dateModified != null && DateTime.now().difference(c.dateModified!).inDays > 90).length;
    final lostCount = customers.where((c) => c.dateModified != null && DateTime.now().difference(c.dateModified!).inDays > 180).length;

    return [
      CustomerSegment(segment: 'VIP', count: vipCount, percentage: (vipCount / total) * 100),
      CustomerSegment(segment: 'Regular', count: regularCount, percentage: (regularCount / total) * 100),
      CustomerSegment(segment: 'New', count: newCount, percentage: (newCount / total) * 100),
      CustomerSegment(segment: 'At Risk', count: atRiskCount, percentage: (atRiskCount / total) * 100),
      CustomerSegment(segment: 'Lost', count: lostCount, percentage: (lostCount / total) * 100),
    ];
  }

  Future<List<TopCustomer>> _getTopCustomers() async {
    try {
      final customersSnapshot = await customersRef
          .orderBy('totalSpent', descending: true)
          .limit(10)
          .get();

      return customersSnapshot.docs.map((doc) {
        final data = doc.data();
        final customer = Customer.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
        String tier = 'Bronze';
        if (customer.totalSpent > 1000) {
          tier = 'Platinum';
        } else if (customer.totalSpent > 500) tier = 'Gold';
        else if (customer.totalSpent > 100) tier = 'Silver';

        return TopCustomer(
          customerId: customer.id,
          customerName: customer.fullName,
          email: customer.email,
          totalOrders: customer.orderCount,
          totalSpent: customer.totalSpent,
          lastOrderDate: customer.dateModified ?? customer.dateCreated ?? DateTime.now(),
          tier: tier,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<AcquisitionData>> _getAcquisitionData(TimePeriod period) async {
    final weeks = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
    return weeks.map((week) => AcquisitionData(
      period: week,
      newCustomers: Random().nextInt(20) + 5,
      returningCustomers: Random().nextInt(15) + 10,
    )).toList();
  }

  Future<RetentionMetrics?> _calculateRetentionMetrics() async {
    return RetentionMetrics(
      retention30Days: 65.5,
      retention90Days: 45.2,
      churnRate: 12.3,
      averageLifetimeValue: 180.0,
    );
  }

  Future<List<LocationData>> _getLocationData(List<Customer> customers) async {
    final locationMap = <String, LocationData>{};

    for (final customer in customers) {
      final city = customer.city ?? 'Unknown';
      final state = customer.state ?? 'Unknown';
      final key = '$city,$state';

      if (!locationMap.containsKey(key)) {
        locationMap[key] = LocationData(
          city: city,
          state: state,
          customerCount: 0,
          totalRevenue: 0,
        );
      }

      final location = locationMap[key]!;
      locationMap[key] = LocationData(
        city: city,
        state: state,
        customerCount: location.customerCount + 1,
        totalRevenue: location.totalRevenue + customer.totalSpent,
      );
    }

    return locationMap.values.toList()
      ..sort((a, b) => b.customerCount.compareTo(a.customerCount));
  }

  Future<double?> _calculateAverageOrderValue(TimePeriod period) async {
    final analytics = await getSalesAnalytics(period);
    return analytics.averageOrderValue;
  }

  Future<double?> _calculateRepeatCustomerRate(TimePeriod period) async {
    try {
      final customers = await customersRef.get();
      final totalCustomers = customers.size;
      final repeatCustomers = customers.docs.where((doc) {
        final data = doc.data();
        final mapData = data! as Map<String, dynamic>;
        return (mapData['orderCount'] as num? ?? 0) > 1;

      }).length;

      return totalCustomers > 0 ? (repeatCustomers / totalCustomers) * 100 : 0;
    } catch (e) {
      return null;
    }
  }

  Future<double> _calculateCustomerGrowth(TimePeriod period) async {
    final previousPeriod = TimePeriod(
      label: 'Previous',
      startDate: period.startDate.subtract(Duration(days: period.endDate.difference(period.startDate).inDays)),
      endDate: period.startDate.subtract(Duration(days: 1)),
    );

    try {
      final currentCustomers = (await customersRef
          .where('dateCreated', isGreaterThanOrEqualTo: period.startDate)
          .where('dateCreated', isLessThanOrEqualTo: period.endDate)
          .get()).size;

      final previousCustomers = (await customersRef
          .where('dateCreated', isGreaterThanOrEqualTo: previousPeriod.startDate)
          .where('dateCreated', isLessThanOrEqualTo: previousPeriod.endDate)
          .get()).size;

      return previousCustomers > 0 ? ((currentCustomers - previousCustomers) / previousCustomers) * 100 : 0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<Product?> _getProductById(String productId) async {
    try {
      final doc = await productsRef.doc(productId).get();
      if (doc.exists) {
        return Product.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<AppOrder>> getRecentOrders({int limit = 10}) async {
    final snapshot = await ordersRef
        .orderBy('dateCreated', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return AppOrder.fromFirestore(data, doc.id);
    }).toList();
  }

  Future<Map<String, dynamic>> getCashSummary(TimePeriod period) async {
    final analytics = await getSalesAnalytics(period);
    final financial = await getFinancialBreakdown(period);
    return {
      'totalCash': analytics.totalSales,
      'cashOrders': analytics.totalOrders,
      'averageTransaction': analytics.averageOrderValue,
      'peakHour': _findPeakHour(analytics.salesByHour),
      'subtotal': financial.subtotal,
      'discounts': financial.discounts,
      'taxes': financial.taxes,
      'shipping': financial.shipping,
      'tips': financial.tips,
    };
  }

  String _findPeakHour(Map<String, double> salesByHour) {
    if (salesByHour.isEmpty) return 'N/A';
    var peakHour = salesByHour.entries.first;
    for (final entry in salesByHour.entries) {
      if (entry.value > peakHour.value) {
        peakHour = entry;
      }
    }
    return peakHour.key;
  }
}

// Enhanced Sales Breakdown Models
class DetailedSalesBreakdown {
  final double grossSales;
  final double netSales;
  final double totalDiscounts;
  final double itemDiscounts;
  final double cartDiscounts;
  final double additionalDiscounts;
  final double taxAmount;
  final double shippingAmount;
  final double tipAmount;
  final double taxableAmount;
  final int totalOrders;
  final int totalItems;
  final double averageOrderValue;
  final double discountRate;
  final double effectiveTaxRate;

  DetailedSalesBreakdown({
    required this.grossSales,
    required this.netSales,
    required this.totalDiscounts,
    required this.itemDiscounts,
    required this.cartDiscounts,
    required this.additionalDiscounts,
    required this.taxAmount,
    required this.shippingAmount,
    required this.tipAmount,
    required this.taxableAmount,
    required this.totalOrders,
    required this.totalItems,
    required this.averageOrderValue,
    required this.discountRate,
    required this.effectiveTaxRate,
  });
}

class DiscountBreakdown {
  final double totalDiscounts;
  final double itemDiscounts;
  final double cartDiscounts;
  final double additionalDiscounts;
  final double discountRate;
  final double averageDiscountPerOrder;
  final List<OrderDiscount> highestDiscountOrders;

  DiscountBreakdown({
    required this.totalDiscounts,
    required this.itemDiscounts,
    required this.cartDiscounts,
    required this.additionalDiscounts,
    required this.discountRate,
    required this.averageDiscountPerOrder,
    required this.highestDiscountOrders,
  });
}

class OrderDiscount {
  final String orderId;
  final String orderNumber;
  final DateTime orderDate;
  final double totalAmount;
  final double discountAmount;
  final double discountPercentage;

  OrderDiscount({
    required this.orderId,
    required this.orderNumber,
    required this.orderDate,
    required this.totalAmount,
    required this.discountAmount,
    required this.discountPercentage,
  });
}

// Enhanced Analytics Dashboard Screen with Financial Tabs
class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  _AnalyticsDashboardScreenState createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> with SingleTickerProviderStateMixin {
  final AnalyticsService _analyticsService = AnalyticsService();
  TimePeriod _selectedPeriod = TimePeriods.today;
  SalesAnalytics? _analytics;
  List<AppOrder> _recentOrders = [];
  Map<String, dynamic> _cashSummary = {};
  CustomerAnalytics? _customerAnalytics;
  FinancialBreakdown? _financialBreakdown;
  DiscountAnalytics? _discountAnalytics;
  TaxAnalytics? _taxAnalytics;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _setTenantContext();
    _loadAnalytics();
  }

  void _setTenantContext() {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    final tenantId = authProvider.currentUser?.tenantId;

    if (tenantId != null && tenantId != 'super_admin') {
      _analyticsService.setTenantId(tenantId);
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final results = await Future.wait([
        _analyticsService.getSalesAnalytics(_selectedPeriod),
        _analyticsService.getRecentOrders(),
        _analyticsService.getCashSummary(_selectedPeriod),
        _analyticsService.getCustomerAnalytics(_selectedPeriod),
        _analyticsService.getFinancialBreakdown(_selectedPeriod),
        _analyticsService.getDiscountAnalytics(_selectedPeriod),
        _analyticsService.getTaxAnalytics(_selectedPeriod),
      ]);

      setState(() {
        _analytics = results[0] as SalesAnalytics;
        _recentOrders = results[1] as List<AppOrder>;
        _cashSummary = results[2] as Map<String, dynamic>;
        _customerAnalytics = results[3] as CustomerAnalytics;
        _financialBreakdown = results[4] as FinancialBreakdown;
        _discountAnalytics = results[5] as DiscountAnalytics;
        _taxAnalytics = results[6] as TaxAnalytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(TimePeriod period) {
    setState(() {
      _selectedPeriod = period;
    });
    _loadAnalytics();
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: DropdownButton<TimePeriod>(
        value: _selectedPeriod,
        isExpanded: true,
        underline: SizedBox(),
        items: TimePeriods.allPeriods.map((period) {
          return DropdownMenuItem<TimePeriod>(
            value: period,
            child: Text(period.label, style: TextStyle(fontWeight: FontWeight.w500)),
          );
        }).toList(),
        onChanged: (period) => _onPeriodChanged(period!),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(strokeWidth: 3),
          SizedBox(height: 16),
          Text('Loading Analytics...', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text('Failed to load analytics', style: TextStyle(fontSize: 18, color: Colors.grey[800])),
          SizedBox(height: 8),
          Text(_errorMessage, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadAnalytics,
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],

      body: Column(
        children: [
          // Tab Bar
          Container(
            color: ThemeUtils.appBar(context).first,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              isScrollable: true,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Sales'),
                Tab(text: 'Financials'),
                Tab(text: 'Discounts'),
                Tab(text: 'Products'),
                Tab(text: 'Customers'),
              ],
            ),
          ),

          // Period Selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildPeriodSelector(),
          ),

          // Tab Content
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _hasError
                ? _buildErrorState()
                : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildSalesTab(),
                _buildFinancialsTab(),
                _buildDiscountsTab(),
                _buildProductsTab(),
                _buildCustomersTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Overview Tab
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildKeyMetrics(),
          SizedBox(height: 20),
          _buildFinancialSummary(),
          SizedBox(height: 20),
          _buildRecentOrders(),
          SizedBox(height: 20),
          _buildCashSummary(),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics() {
    // Calculate net sales (total after all adjustments)
    final netSales = _financialBreakdown?.total ?? _analytics?.totalSales ?? 0.0;
    final grossSales = _financialBreakdown?.subtotal ?? _analytics?.subtotalAmount ?? 0.0;
    final totalDiscounts = _financialBreakdown?.discounts ?? _analytics?.totalDiscounts ?? 0.0;

    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildMetricCard(
          title: 'Net Sales',
          value: '${Constants.CURRENCY_NAME}${netSales.toStringAsFixed(0)}',
          subtitle: 'After all adjustments',
          icon: Icons.attach_money,
          color: Colors.green,
        ),
        _buildMetricCard(
          title: 'Gross Sales',
          value: '${Constants.CURRENCY_NAME}${grossSales.toStringAsFixed(0)}',
          subtitle: 'Before adjustments',
          icon: Icons.bar_chart,
          color: Colors.blue,
        ),
        _buildMetricCard(
          title: 'Total Orders',
          value: '${_analytics?.totalOrders ?? 0}',
          subtitle: 'Completed orders',
          icon: Icons.shopping_cart,
          color: Colors.orange,
        ),
        _buildMetricCard(
          title: 'Total Discounts',
          value: '-${Constants.CURRENCY_NAME}${totalDiscounts.toStringAsFixed(0)}',
          subtitle: 'Discounts given',
          icon: Icons.discount,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialSummary() {
    final netSales = _financialBreakdown?.total ?? _analytics?.totalSales ?? 0.0;
    final grossSales = _financialBreakdown?.subtotal ?? _analytics?.subtotalAmount ?? 0.0;
    final totalDiscounts = _financialBreakdown?.discounts ?? _analytics?.totalDiscounts ?? 0.0;
    final taxes = _financialBreakdown?.taxes ?? _analytics?.taxAmount ?? 0.0;
    final shipping = _financialBreakdown?.shipping ?? _analytics?.shippingAmount ?? 0.0;
    final tips = _financialBreakdown?.tips ?? _analytics?.tipAmount ?? 0.0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart, color: Colors.purple),
                SizedBox(width: 8),
                Text('Financial Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),

            // Net Sales Highlight
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[100]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NET SALES', style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Final amount after all adjustments', style: TextStyle(fontSize: 10, color: Colors.green[600])),
                    ],
                  ),
                  Text(
                    '${Constants.CURRENCY_NAME}${netSales.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green[700]),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Breakdown Grid
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildFinancialMetric(
                  'Gross Sales',
                  '${Constants.CURRENCY_NAME}${grossSales.toStringAsFixed(0)}',
                  'Before adjustments',
                  Colors.blue,
                ),
                _buildFinancialMetric(
                  'Total Discounts',
                  '-${Constants.CURRENCY_NAME}${totalDiscounts.toStringAsFixed(0)}',
                  'Discounts applied',
                  Colors.red,
                ),
                _buildFinancialMetric(
                  'Taxes',
                  '${Constants.CURRENCY_NAME}${taxes.toStringAsFixed(0)}',
                  'Tax collected',
                  Colors.orange,
                ),
                _buildFinancialMetric(
                  'Shipping',
                  '${Constants.CURRENCY_NAME}${shipping.toStringAsFixed(0)}',
                  'Shipping charges',
                  Colors.green,
                ),
                if (tips > 0)
                  _buildFinancialMetric(
                    'Tips',
                    '${Constants.CURRENCY_NAME}${tips.toStringAsFixed(0)}',
                    'Tips received',
                    Colors.purple,
                  ),
              ],
            ),

            // Net Sales Calculation Breakdown
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('Net Sales Calculation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  SizedBox(height: 8),
                  _buildCalculationRow('Gross Sales', '${Constants.CURRENCY_NAME}${grossSales.toStringAsFixed(0)}'),
                  _buildCalculationRow('Discounts', '-${Constants.CURRENCY_NAME}${totalDiscounts.toStringAsFixed(0)}'),
                  _buildCalculationRow('Taxes', '+${Constants.CURRENCY_NAME}${taxes.toStringAsFixed(0)}'),
                  _buildCalculationRow('Shipping', '+${Constants.CURRENCY_NAME}${shipping.toStringAsFixed(0)}'),
                  if (tips > 0)
                    _buildCalculationRow('Tips', '+${Constants.CURRENCY_NAME}${tips.toStringAsFixed(0)}'),
                  Divider(height: 16),
                  _buildCalculationRow('Net Sales', '${Constants.CURRENCY_NAME}${netSales.toStringAsFixed(0)}', isTotal: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialMetric(String label, String value, String subtitle, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green[700] : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.green[700] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // Sales Tab
  Widget _buildSalesTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSalesTrendsChart(),
          SizedBox(height: 20),
          _buildHourlySalesChart(),
          SizedBox(height: 20),
          _buildDailySalesChart(),
          ElevatedButton(onPressed: (){
            Navigator.push(context, MaterialPageRoute(builder: (context) => SalesManagementScreen(),));
          }, child: Text("Management"))
        ],
      ),
    );
  }

  Widget _buildSalesTrendsChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'Sales trends chart would appear here\n(Requires more historical data)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlySalesChart() {
    final hourlyData = _analytics?.salesByHour.entries.map((entry) => ChartData(entry.key, entry.value)).toList() ?? [];
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales by Hour', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                series: <ColumnSeries<ChartData, String>>[
                  ColumnSeries<ChartData, String>(
                    dataSource: hourlyData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    color: Colors.blue[400],
                    dataLabelSettings: DataLabelSettings(isVisible: true, labelAlignment: ChartDataLabelAlignment.outer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySalesChart() {
    final dailyData = _analytics?.salesByDay.entries.map((entry) => ChartData(entry.key, entry.value)).toList() ?? [];
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sales by Day', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                series: <ColumnSeries<ChartData, String>>[
                  ColumnSeries<ChartData, String>(
                    dataSource: dailyData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    color: Colors.green[400],
                    dataLabelSettings: DataLabelSettings(isVisible: true, labelAlignment: ChartDataLabelAlignment.outer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Financials Tab
  Widget _buildFinancialsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildRevenueBreakdown(),
          SizedBox(height: 20),
          _buildTaxAnalytics(),
          SizedBox(height: 20),
          _buildPaymentMethodDistribution(),
          SizedBox(height: 20),
          _buildFinancialEfficiency(),
        ],
      ),
    );
  }

  Widget _buildRevenueBreakdown() {
    final data = [
      ChartData('Subtotal', _financialBreakdown?.subtotal ?? 0),
      ChartData('Discounts', -(_financialBreakdown?.discounts ?? 0)),
      ChartData('Taxes', _financialBreakdown?.taxes ?? 0),
      ChartData('Shipping', _financialBreakdown?.shipping ?? 0),
      ChartData('Tips', _financialBreakdown?.tips ?? 0),
    ].where((item) => item.y != 0).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCartesianChart(
                primaryXAxis: CategoryAxis(),
                series: <BarSeries<ChartData, String>>[
                  BarSeries<ChartData, String>(
                    dataSource: data,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    dataLabelSettings: DataLabelSettings(isVisible: true),
                    color: Colors.blue[400],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxAnalytics() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tax Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildTaxMetric(
                  'Total Tax Collected',
                  '${Constants.CURRENCY_NAME}${_taxAnalytics?.totalTaxCollected.toStringAsFixed(0) ?? '0'}',
                  Colors.red,
                ),
                _buildTaxMetric(
                  'Avg Tax per Order',
                  '${Constants.CURRENCY_NAME}${_taxAnalytics?.averageTaxPerOrder.toStringAsFixed(2) ?? '0'}',
                  Colors.orange,
                ),
                _buildTaxMetric(
                  'Effective Tax Rate',
                  '${_taxAnalytics?.effectiveTaxRate.toStringAsFixed(1) ?? '0'}%',
                  Colors.purple,
                ),
                _buildTaxMetric(
                  'Taxable Amount',
                  '${Constants.CURRENCY_NAME}${_analytics?.taxableAmount.toStringAsFixed(0) ?? '0'}',
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxMetric(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodDistribution() {
    final paymentData = _analytics?.paymentMethodDistribution.entries
        .map((entry) => ChartData(_getPaymentMethodName(entry.key), entry.value))
        .toList() ?? [];

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Methods', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCircularChart(
                series: <PieSeries<ChartData, String>>[
                  PieSeries<ChartData, String>(
                    dataSource: paymentData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    dataLabelMapper: (ChartData data, _) => '${data.x}\n${Constants.CURRENCY_NAME}${data.y.toStringAsFixed(0)}',
                    dataLabelSettings: DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialEfficiency() {
    final discountRate = ((_financialBreakdown?.subtotal ?? 0) > 0)
        ? ((_financialBreakdown?.discounts ?? 0) / _financialBreakdown!.subtotal) * 100
        : 0;


    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Financial Efficiency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Row(
              children: [
                _buildEfficiencyMetric(
                  'Discount Rate',
                  '${discountRate.toStringAsFixed(1)}%',
                  discountRate > 10 ? Colors.orange : Colors.green,
                ),
                SizedBox(width: 12),
                _buildEfficiencyMetric(
                  'Tax Efficiency',
                  '${_taxAnalytics?.effectiveTaxRate.toStringAsFixed(1) ?? '0'}%',
                  Colors.blue,
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildEfficiencyMetric(
                  'Avg Order Value',
                  '${Constants.CURRENCY_NAME}${_analytics?.averageOrderValue.toStringAsFixed(0) ?? '0'}',
                  Colors.purple,
                ),
                SizedBox(width: 12),
                _buildEfficiencyMetric(
                  'Items per Order',
                  '${((_analytics?.totalOrders ?? 0) > 0
                      ? (_analytics!.totalItemsSold / _analytics!.totalOrders).toStringAsFixed(1)
                      : '0')}',
                  Colors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEfficiencyMetric(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // Discounts Tab
  Widget _buildDiscountsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDiscountOverview(),
          SizedBox(height: 20),
          _buildDiscountBreakdown(),
          SizedBox(height: 20),
          _buildHighestDiscountOrders(),
        ],
      ),
    );
  }

  Widget _buildDiscountOverview() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Discount Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildDiscountMetric(
                  'Total Discounts',
                  '-${Constants.CURRENCY_NAME}${_discountAnalytics?.totalDiscounts.toStringAsFixed(0) ?? '0'}',
                  Colors.red,
                ),
                _buildDiscountMetric(
                  'Avg Discount/Order',
                  '${Constants.CURRENCY_NAME}${_discountAnalytics?.averageDiscountPerOrder.toStringAsFixed(2) ?? '0'}',
                  Colors.orange,
                ),
                _buildDiscountMetric(
                  'Discount Rate',
                  '${_discountAnalytics?.discountRate.toStringAsFixed(1) ?? '0'}%',
                  Colors.purple,
                ),
                _buildDiscountMetric(
                  'Item Discounts',
                  '-${Constants.CURRENCY_NAME}${_analytics?.itemDiscounts.toStringAsFixed(0) ?? '0'}',
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountMetric(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
          SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildDiscountBreakdown() {
    final discountData = [
      ChartData('Item Discounts', _analytics?.itemDiscounts ?? 0),
      ChartData('Cart Discounts', _analytics?.cartDiscounts ?? 0),
      ChartData('Additional Discounts', _analytics?.additionalDiscounts ?? 0),
    ].where((item) => item.y > 0).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Discount Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCircularChart(
                series: <PieSeries<ChartData, String>>[
                  PieSeries<ChartData, String>(
                    dataSource: discountData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    dataLabelMapper: (ChartData data, _) => '${data.x}\n${Constants.CURRENCY_NAME}${data.y.toStringAsFixed(0)}',
                    dataLabelSettings: DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighestDiscountOrders() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Highest Discount Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            ..._discountAnalytics?.highestDiscountOrders.map((order) => _buildDiscountOrderItem(order)) ?? [
              Center(child: Text('No discount data available', style: TextStyle(color: Colors.grey[600]))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountOrderItem(AppOrder order) {
    final orderData = order.toFirestore();
    final discount = (orderData['totalDiscount'] ?? 0.0) as double;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.red[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.discount, color: Colors.red, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${order.number}', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy - HH:mm').format(order.dateCreated),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-${Constants.CURRENCY_NAME}${discount.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red[700]),
              ),
              SizedBox(height: 2),
              Text(
                '${Constants.CURRENCY_NAME}${order.total.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Products Tab
  Widget _buildProductsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTopProducts(),
          SizedBox(height: 20),
          _buildProductPerformance(),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 8),
                Text('Top Performing Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            ..._analytics?.topProducts.map((product) => _buildProductPerformanceItem(product)) ?? [
              Center(child: Text('No product data available', style: TextStyle(color: Colors.grey[600]))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductPerformanceItem(ProductPerformance performance) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              image: performance.product.imageUrl != null
                  ? DecorationImage(image: NetworkImage(performance.product.imageUrl!), fit: BoxFit.cover)
                  : null,
            ),
            child: performance.product.imageUrl == null ? Icon(Icons.shopping_bag, color: Colors.grey[400]) : null,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(performance.product.name, style: TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 4),
                Text(
                  '${performance.quantitySold} sold • ${Constants.CURRENCY_NAME}${performance.revenue.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
            child: Text(
              '${performance.percentage.toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductPerformance() {
    final productData = _analytics?.topProducts.map((p) => ChartData(p.product.name, p.revenue)).toList() ?? [];
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Product Revenue Distribution', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfCircularChart(
                series: <PieSeries<ChartData, String>>[
                  PieSeries<ChartData, String>(
                    dataSource: productData,
                    xValueMapper: (ChartData data, _) => data.x,
                    yValueMapper: (ChartData data, _) => data.y,
                    dataLabelMapper: (ChartData data, _) => '${data.x}\n${Constants.CURRENCY_NAME}${data.y.toStringAsFixed(0)}',
                    dataLabelSettings: DataLabelSettings(isVisible: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Customers Tab
  Widget _buildCustomersTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCustomerOverviewMetrics(),
          SizedBox(height: 20),
          _buildCustomerSegmentation(),
          SizedBox(height: 20),
          _buildTopCustomers(),
          SizedBox(height: 20),
          _buildCustomerAcquisitionRetention(),
          SizedBox(height: 20),
          _buildCustomerLocationAnalytics(),
        ],
      ),
    );
  }

  Widget _buildCustomerOverviewMetrics() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.purple),
                SizedBox(width: 8),
                Text('Customer Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildCustomerMetricCard(
                  title: 'Total Customers',
                  value: '${_customerAnalytics?.totalCustomers ?? 0}',
                  subtitle: 'Active customers',
                  icon: Icons.people_outline,
                  color: Colors.purple,
                  trend: _customerAnalytics?.customerGrowth ?? 0,
                ),
                _buildCustomerMetricCard(
                  title: 'New Customers',
                  value: '${_customerAnalytics?.newCustomers ?? 0}',
                  subtitle: 'This period',
                  icon: Icons.person_add,
                  color: Colors.green,
                ),
                _buildCustomerMetricCard(
                  title: 'Avg Order Value',
                  value: '${Constants.CURRENCY_NAME}${_customerAnalytics?.averageOrderValue?.toStringAsFixed(0) ?? '0'}',
                  subtitle: 'Per customer',
                  icon: Icons.attach_money,
                  color: Colors.blue,
                ),
                _buildCustomerMetricCard(
                  title: 'Repeat Rate',
                  value: '${_customerAnalytics?.repeatCustomerRate?.toStringAsFixed(1) ?? '0'}%',
                  subtitle: 'Returning customers',
                  icon: Icons.repeat,
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    double? trend,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 18),
                ),
                if (trend != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: trend >= 0 ? Colors.green[50]! : Colors.red[50]!,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          trend >= 0 ? Icons.trending_up : Icons.trending_down,
                          size: 14,
                          color: trend >= 0 ? Colors.green : Colors.red,
                        ),
                        SizedBox(width: 2),
                        Text(
                          '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: trend >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSegmentation() {
    return Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Customer Segmentation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: _customerAnalytics?.customerSegmentation != null
                    ? SfCircularChart(
                  series: <PieSeries<CustomerSegment, String>>[
                    PieSeries<CustomerSegment, String>(
                      dataSource: _customerAnalytics!.customerSegmentation,
                      xValueMapper: (CustomerSegment segment, _) => segment.segment,
                      yValueMapper: (CustomerSegment segment, _) => segment.count.toDouble(),
                      dataLabelMapper: (CustomerSegment segment, _) => '${segment.segment}\n${segment.count}',
                      dataLabelSettings: DataLabelSettings(isVisible: true),
                      explode: true,
                      explodeIndex: 0,
                    ),
                  ],
                )
                    : Center(child: Text('No segmentation data available', style: TextStyle(color: Colors.grey[600]))),
              ),
              SizedBox(height: 16),
              if (_customerAnalytics?.customerSegmentation != null)
                ..._customerAnalytics!.customerSegmentation.map((segment) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: _getSegmentColor(segment.segment), shape: BoxShape.circle),
                        ),
                        SizedBox(width: 8),
                        Expanded(child: Text(segment.segment, style: TextStyle(fontWeight: FontWeight.w500))),
                        Text('${segment.count} customers', style: TextStyle(color: Colors.grey[600])),
                        SizedBox(width: 8),
                        Text(
                          '${segment.percentage.toStringAsFixed(1)}%',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ));
    }

  Widget _buildTopCustomers() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber),
                SizedBox(width: 8),
                Text('Top Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Spacer(),
                Text('By Lifetime Value', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ),
            SizedBox(height: 16),
            ..._customerAnalytics?.topCustomers.take(10).map((customer) => _buildTopCustomerItem(customer)) ?? [
              Center(child: Text('No customer data available', style: TextStyle(color: Colors.grey[600]))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopCustomerItem(TopCustomer customer) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: Colors.purple[100], borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.person, color: Colors.purple, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.customerName, style: TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.email, size: 12, color: Colors.grey),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(customer.email, style: TextStyle(fontSize: 11, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.shopping_cart, size: 12, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('${customer.totalOrders} orders', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    SizedBox(width: 12),
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('Last: ${DateFormat('MMM dd').format(customer.lastOrderDate)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${Constants.CURRENCY_NAME}${customer.totalSpent.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[700]),
              ),
              SizedBox(height: 2),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _getCustomerTierColor(customer.tier), borderRadius: BorderRadius.circular(8)),
                child: Text(
                  customer.tier.toUpperCase(),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerAcquisitionRetention() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.green),
                SizedBox(width: 8),
                Text('Customer Acquisition & Retention', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            if (_customerAnalytics?.acquisitionData != null)
              SizedBox(
                height: 250,
                child: SfCartesianChart(
                  primaryXAxis: CategoryAxis(),
                  primaryYAxis: NumericAxis(),
                  series: <ColumnSeries<AcquisitionData, String>>[
                    ColumnSeries<AcquisitionData, String>(
                      dataSource: _customerAnalytics!.acquisitionData,
                      xValueMapper: (AcquisitionData data, _) => data.period,
                      yValueMapper: (AcquisitionData data, _) => data.newCustomers.toDouble(),
                      name: 'New Customers',
                      color: Colors.green[400],
                    ),
                    ColumnSeries<AcquisitionData, String>(
                      dataSource: _customerAnalytics!.acquisitionData,
                      xValueMapper: (AcquisitionData data, _) => data.period,
                      yValueMapper: (AcquisitionData data, _) => data.returningCustomers.toDouble(),
                      name: 'Returning Customers',
                      color: Colors.blue[400],
                    ),
                  ],
                  legend: Legend(isVisible: true),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: Center(child: Text('No acquisition data available', style: TextStyle(color: Colors.grey[600]))),
              ),
            SizedBox(height: 16),
            if (_customerAnalytics?.retentionMetrics != null)
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildRetentionMetric(
                    '30-Day Retention',
                    '${_customerAnalytics!.retentionMetrics!.retention30Days.toStringAsFixed(1)}%',
                    Colors.green,
                  ),
                  _buildRetentionMetric(
                    '90-Day Retention',
                    '${_customerAnalytics!.retentionMetrics!.retention90Days.toStringAsFixed(1)}%',
                    Colors.blue,
                  ),
                  _buildRetentionMetric(
                    'Churn Rate',
                    '${_customerAnalytics!.retentionMetrics!.churnRate.toStringAsFixed(1)}%',
                    Colors.red,
                  ),
                  _buildRetentionMetric(
                    'Avg Lifetime',
                    '${_customerAnalytics!.retentionMetrics!.averageLifetimeValue.toStringAsFixed(0)} days',
                    Colors.purple,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetentionMetric(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildCustomerLocationAnalytics() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.red),
                SizedBox(width: 8),
                Text('Customer Locations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            if (_customerAnalytics?.locationData != null && _customerAnalytics!.locationData.isNotEmpty)
              Column(
                children: _customerAnalytics!.locationData.take(5).map((location) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.location_city, size: 16, color: Colors.grey),
                        SizedBox(width: 8),
                        Expanded(child: Text(location.city, style: TextStyle(fontWeight: FontWeight.w500))),
                        Text('${location.customerCount} customers', style: TextStyle(color: Colors.grey[600])),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            '${Constants.CURRENCY_NAME}${location.totalRevenue.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            else
              SizedBox(
                height: 100,
                child: Center(child: Text('No location data available', style: TextStyle(color: Colors.grey[600]))),
              ),
          ],
        ),
      ),
    );
  }

  // Recent Orders and Cash Summary
  Widget _buildRecentOrders() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt, color: Colors.blue),
                SizedBox(width: 8),
                Text('Recent Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Spacer(),
                Text('${_recentOrders.length} orders', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            SizedBox(height: 16),
            ..._recentOrders.take(5).map((order) => _buildOrderListItem(order)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderListItem(AppOrder order) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.receipt_long, color: Colors.green),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order #${order.number}', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, yyyy - HH:mm').format(order.dateCreated),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            '${Constants.CURRENCY_NAME}${order.total.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildCashSummary() {
    final netSales = _financialBreakdown?.total ?? _analytics?.totalSales ?? 0.0;
    final grossSales = _financialBreakdown?.subtotal ?? _analytics?.subtotalAmount ?? 0.0;
    final totalDiscounts = _financialBreakdown?.discounts ?? _analytics?.totalDiscounts ?? 0.0;

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.money, color: Colors.green),
                SizedBox(width: 8),
                Text('Sales Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                _buildCashMetric('Net Sales', '${Constants.CURRENCY_NAME}${netSales.toStringAsFixed(0)}'),
                _buildCashMetric('Gross Sales', '${Constants.CURRENCY_NAME}${grossSales.toStringAsFixed(0)}'),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildCashMetric('Total Discounts', '-${Constants.CURRENCY_NAME}${totalDiscounts.toStringAsFixed(0)}'),
                _buildCashMetric('Transactions', '${_cashSummary['cashOrders'] ?? 0}'),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildCashMetric('Avg Transaction', '${Constants.CURRENCY_NAME}${_cashSummary['averageTransaction']?.toStringAsFixed(0) ?? '0'}'),
                _buildCashMetric('Peak Hour', _cashSummary['peakHour'] ?? 'N/A'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashMetric(String label, String value) {
    final isDiscount = label.contains('Discount') && value.startsWith('-');
    final isNetSales = label.contains('Net Sales');

    return Expanded(
      child: Container(
        margin: EdgeInsets.all(4),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isNetSales ? Colors.green[50] : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isNetSales ? Colors.green[100]! : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDiscount ? Colors.red[700] : (isNetSales ? Colors.green[700] : Colors.grey[800]),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Helper Methods
  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash': return 'Cash';
      case 'card': return 'Card';
      case 'mobile_money': return 'Mobile Money';
      case 'credit': return 'Credit';
      default: return method;
    }
  }

  Color _getSegmentColor(String segment) {
    switch (segment.toLowerCase()) {
      case 'vip':
        return Colors.amber;
      case 'regular':
        return Colors.blue;
      case 'new':
        return Colors.green;
      case 'at risk':
        return Colors.orange;
      case 'lost':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getCustomerTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum':
        return Colors.blue[800]!;
      case 'gold':
        return Colors.amber[700]!;
      case 'silver':
        return Colors.grey[600]!;
      case 'bronze':
        return Colors.orange[800]!;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}