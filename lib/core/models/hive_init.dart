import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mpcm/core/models/app_order_model.dart';
import 'package:mpcm/core/models/product_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static Future<void> initHive() async {
    try {
      // Get application directory for Hive storage
      final appDocumentDir = await getApplicationDocumentsDirectory();

      // Initialize Hive with Flutter
      await Hive.initFlutter(appDocumentDir.path);

      // Optional: For web support
      // await Hive.initFlutter();

      debugPrint('✅ Hive initialized successfully');
      debugPrint('📁 Hive storage path: ${appDocumentDir.path}');

    } catch (e) {
      debugPrint('❌ Error initializing Hive: $e');
      rethrow;
    }
  }

  static Future<void> initAdapters() async {
    try {
      // Register all your Hive adapters here
      Example: Hive.registerAdapter(ProductAdapter());
      Example: Hive.registerAdapter(AppOrderAdapter());

      // You can also register adapters dynamically by calling:
      // await initializeAdapters(); // If you have a separate adapters init file

      debugPrint('✅ Hive adapters registered successfully');
    } catch (e) {
      debugPrint('❌ Error registering Hive adapters: $e');
      rethrow;
    }
  }

  static Future<Box<T>> openBox<T>(String boxName) async {
    try {
      // Open or create a Hive box
      final box = await Hive.openBox<T>(boxName);
      debugPrint('✅ Box "$boxName" opened successfully');
      return box;
    } catch (e) {
      debugPrint('❌ Error opening box "$boxName": $e');
      rethrow;
    }
  }

  static Future<void> closeBox<T>(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box<T>(boxName).close();
        debugPrint('✅ Box "$boxName" closed successfully');
      }
    } catch (e) {
      debugPrint('❌ Error closing box "$boxName": $e');
    }
  }

  static Future<void> clearBox(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).clear();
        debugPrint('✅ Box "$boxName" cleared successfully');
      }
    } catch (e) {
      debugPrint('❌ Error clearing box "$boxName": $e');
    }
  }

  static Future<void> deleteBox(String boxName) async {
    try {
      await Hive.deleteBoxFromDisk(boxName);
      debugPrint('✅ Box "$boxName" deleted from disk');
    } catch (e) {
      debugPrint('❌ Error deleting box "$boxName": $e');
    }
  }

  static Future<void> closeAllBoxes() async {
    try {
      await Hive.close();
      debugPrint('✅ All Hive boxes closed');
    } catch (e) {
      debugPrint('❌ Error closing all boxes: $e');
    }
  }

  static bool isBoxOpen(String boxName) {
    return Hive.isBoxOpen(boxName);
  }

  // Clear all Hive data (useful for logout or testing)
  static Future<void> clearAllData() async {
    try {
      await Hive.deleteFromDisk();
      debugPrint('✅ All Hive data cleared from disk');
    } catch (e) {
      debugPrint('❌ Error clearing all Hive data: $e');
    }
  }
}

// Alternative: Function-based initialization
Future<void> initializeHive() async {
  await HiveService.initHive();
  await HiveService.initAdapters();
}