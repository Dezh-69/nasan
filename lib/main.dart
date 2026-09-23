import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'package:flutter/services.dart';
import 'services/ring_service.dart';
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Note: Ringing is handled natively by RingReceiver in Kotlin.
  // We don't need to manually trigger MethodChannels here anymore.
}

@pragma('vm:entry-point')
void backgroundStopRing() {
  WidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.family.nasan/ring_background');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'sendAbort') {
      final targetUid = call.arguments['targetUid'] as String?;
      if (targetUid != null) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        // Using RingService to send abort request
        final ringService = RingService();
        await ringService.sendAbortRequest(targetUid);
      }
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    const ProviderScope(
      child: NasanApp(),
    ),
  );
}
