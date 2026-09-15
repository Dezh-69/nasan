import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/foundation.dart';
final ringServiceProvider = Provider<RingService>((ref) => RingService());

class RingService {
  static const _platform = MethodChannel('com.family.nasan/ring');

  /// Send a ring request to a target user via direct FCM HTTP v1 API
  Future<bool> sendRingRequest(String targetUid) async {
    return _sendFcmMessage(targetUid, 'ring');
  }

  /// Send an abort request via FCM
  Future<bool> sendAbortRequest(String targetUid) async {
    return _sendFcmMessage(targetUid, 'abort');
  }

  Future<bool> _sendFcmMessage(String targetUid, String type) async {
    debugPrint("=== FCM REQUEST STARTED ($type) for $targetUid ===");
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    try {
      final targetDoc = await FirebaseFirestore.instance.collection('users').doc(targetUid).get();
      final fcmToken = targetDoc.data()?['fcmToken'];
      if (fcmToken == null) return false;

      final jsonString = await rootBundle.loadString('assets/service_account.json');
      final accountCredentials = ServiceAccountCredentials.fromJson(jsonString);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(accountCredentials, scopes);

      final response = await client.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/nasan-a98e6/messages:send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'data': {
              'type': type,
              'senderUid': currentUser.uid,
            },
            'android': {
              'priority': 'high',
            }
          }
        }),
      );
      
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("=== FCM REQUEST FAILED: $e ===");
      return false;
    }
  }

  /// Send a ring request via SMS (offline trigger)
  Future<bool> sendRingRequestSms(String phoneNumber) async {
    return _sendSms(phoneNumber, '<NASAN_RING_TRIGGER>');
  }

  /// Send an abort request via SMS
  Future<bool> sendAbortRequestSms(String phoneNumber) async {
    return _sendSms(phoneNumber, '<NASAN_ABORT_TRIGGER>');
  }

  Future<bool> _sendSms(String phoneNumber, String message) async {
    try {
      debugPrint("TRIGGERING SMS SEND TO $phoneNumber with message: $message");
      // Since background_sms can be flaky or require complex setup,
      // we can also use platform channels to send the SMS securely
      // For now we'll call the platform channel because we have one already
      final result = await _platform.invokeMethod<bool>('sendSms', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      return result ?? false;
    } catch (e) {
      debugPrint("Failed to send SMS: $e");
      return false;
    }
  }

  /// Trigger ring locally via MethodChannel
  Future<void> triggerLocalRing() async {
    try {
      debugPrint("TRIGGERING NATIVE RING!");
      await _platform.invokeMethod('triggerRing');
    } on PlatformException catch (e) {
      debugPrint("Failed to trigger ring: ${e.message}");
    }
  }

  /// Stop ringing locally
  Future<void> stopLocalRing() async {
    try {
      await _platform.invokeMethod('stopRing');
    } on PlatformException catch (e) {
      debugPrint("Failed to stop ring: ${e.message}");
    }
  }

  /// Request necessary permissions
  Future<void> requestPermissions() async {
    try {
      await _platform.invokeMethod('requestPermissions');
    } on PlatformException catch (e) {
      debugPrint("Failed to request permissions: ${e.message}");
    }
  }
}
