import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/activity_type.dart';

class UserActivityRepository {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> logUserActivity({
    required String tenantId,
    required String userId,
    required String userEmail,
    required String userDisplayName,
    required ActivityType action,
    required String description,
    Map<String, dynamic> metadata = const {},
    String ipAddress = '',
    String userAgent = '',
  }) async {
    try {
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('user_activities')
          .add({
        'tenantId': tenantId,
        'userId': userId,
        'userEmail': userEmail,
        'userDisplayName': userDisplayName,
        'action': action.toString().split('.').last,
        'description': description,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
        'ipAddress': ipAddress,
        'userAgent': userAgent,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to log activity: $e');
      }
    }
  }
}