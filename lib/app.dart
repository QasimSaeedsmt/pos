// // app.dart - Complete Flutter POS with Firestore & Product Management
//
//
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
//
// import 'package:camera/camera.dart';
// import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
// import 'package:connectivity_plus/connectivity_plus.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:synchronized/synchronized.dart';
//
// import 'constants.dart';
// import 'features/cartBase/cart_base.dart';
// import 'features/clientDashboard/client_dashboard.dart';
// import 'features/connectivityBase/local_db_base.dart';
// import 'features/customerBase/customer_base.dart';
// import 'features/main_navigation/main_navigation_base.dart';
// import 'features/orderBase/order_base.dart';
// import 'features/product_addition_restock_base/product_addition_restock_base.dart';
// import 'features/product_selling/product_selling_base.dart';
// import 'features/returnBase/return_base.dart';
// import 'modules/auth/providers/auth_provider.dart';
//
//
// /// Firestore Service - Replaces WooCommerce
//
// /// Enhanced POS Service with Offline Support
//
// /// Enhanced POS Service with Offline Support
//
// // Data Models
//
//
//
//
//
// // dashboard_offline_models.dart
// // Enhanced Cart Manager
//
// // // Main Application
// // class POSApp extends StatefulWidget {
// //   const POSApp({super.key});
// //
// //   @override
// //   State<POSApp> createState() => _POSAppState();
// // }
// //
// // class _POSAppState extends State<POSApp> {
// //   @override
// //   void initState() {
// //     super.initState();
// //     _loadTheme();
// //   }
// //
// //   Future<void> _loadTheme() async {
// //     setState(() {});
// //   }
// //
// //   final EnhancedPOSService _posService = EnhancedPOSService();
// //
// //   Future<bool> _onWillPop(BuildContext context) async {
// //     final shouldExit = await showDialog<bool>(
// //       context: context,
// //       builder: (context) => AlertDialog(
// //         title: const Text('Exit App'),
// //         content: const Text('Are you sure you want to exit the POS?'),
// //         actions: [
// //           TextButton(
// //             onPressed: () => Navigator.of(context).pop(false),
// //             child: const Text('No'),
// //           ),
// //           TextButton(
// //             onPressed: () => Navigator.of(context).pop(true),
// //             child: const Text('Yes'),
// //           ),
// //         ],
// //       ),
// //     );
// //     return shouldExit ?? false;
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return MaterialApp(
// //       title: '${Constants.TANENT_NAME} POS - Offline',
// //       theme: ThemeData(
// //         primarySwatch: Colors.blue,
// //         visualDensity: VisualDensity.adaptivePlatformDensity,
// //       ),
// //       home: PopScope(
// //         canPop: false, // Prevents back button entirely
// //         onPopInvoked: (didPop) async {
// //           if (!didPop) {
// //             final shouldPop = await _onWillPop(context);
// //             if (shouldPop && context.mounted) {
// //               // If you want to actually close the app
// //               SystemNavigator.pop();
// //             }
// //           }
// //         },
// //         child: MainPOSScreen(),
// //       ),
// //       debugShowCheckedModeBanner: false,
// //     );
// //   }
// // }
//
//
// // Modern Dashboard Screen
//
// // Supporting Models
//
// // class ChartData {
// //   final String day;
// //   final double revenue;
// //
// //   ChartData(this.day, this.revenue);
// // }
//
//
