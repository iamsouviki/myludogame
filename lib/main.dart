import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

import 'services/notification_service.dart';
import 'ui/widgets/app_notification_banner.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme.dart';

import 'ui/widgets/responsive_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init fallback: $e');
  }
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    debugPrint('Firebase auth fallback: $e');
  }
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase messaging fallback: $e');
  }
  unawaited(
    NotificationBootstrap.init().catchError((e) {
      debugPrint('NotificationBootstrap error: $e');
    }),
  );
  runApp(const MyLudoApp());
}

class MyLudoApp extends StatefulWidget {
  const MyLudoApp({super.key});

  @override
  State<MyLudoApp> createState() => _MyLudoAppState();
}

class _MyLudoAppState extends State<MyLudoApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Ludo',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNavigation.navigatorKey,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
      builder: (context, child) => AppNotificationBannerHost(
        child: ResponsiveWrapper(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
