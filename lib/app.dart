import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/auth_service.dart';
import 'services/update_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme.dart';
class NasanApp extends ConsumerStatefulWidget {
  const NasanApp({super.key});

  @override
  ConsumerState<NasanApp> createState() => _NasanAppState();
}

class _NasanAppState extends ConsumerState<NasanApp> {
  @override
  void initState() {
    super.initState();
    _setupFCMListeners();
  }

  void _setupFCMListeners() {
    // Request permission (needed on Android 13+)
    FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      // Note: We no longer call triggerLocalRing() here because the native 
      // RingReceiver intercepts the FCM broadcast and handles it automatically 
      // in all app states, preventing double-ringing.
    });

    // Handle FCM token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      ref.read(authServiceProvider).updateFcmToken(token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Nasan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: authState.when(
        data: (user) {
          if (user == null) {
            return const LoginScreen();
          }
          // Check for app updates once per session after login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && !UpdateService.updateCheckedThisSession) {
              UpdateService.updateCheckedThisSession = true;
              UpdateService.checkForUpdate(context);
            }
          });
          return const HomeScreen();
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          body: Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
