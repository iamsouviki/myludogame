import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

import 'services/notification_service.dart';
import 'ui/widgets/app_notification_banner.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init fallback: $e');
  }
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await NotificationBootstrap.init();
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
      home: const HomeScreen(),
      builder: (context, child) => AppNotificationBannerHost(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
