import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../theme.dart';

class AppNotificationBannerHost extends StatefulWidget {
  final Widget child;

  const AppNotificationBannerHost({super.key, required this.child});

  @override
  State<AppNotificationBannerHost> createState() => _AppNotificationBannerHostState();
}

class _AppNotificationBannerHostState extends State<AppNotificationBannerHost> {
  StreamSubscription<AppNotification>? _sub;
  AppNotification? _current;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _sub = NotificationService.instance.bannerStream.listen((notification) {
      if (!mounted) return;
      _timer?.cancel();
      setState(() => _current = notification);
      _timer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _current = null);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: SafeArea(
              child: AnimatedSlide(
                offset: _current == null ? const Offset(0, -0.24) : Offset.zero,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _current == null ? 0 : 1,
                  duration: const Duration(milliseconds: 260),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _current == null
                          ? const SizedBox.shrink()
                          : _NotificationBannerCard(notification: _current!),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationBannerCard extends StatelessWidget {
  final AppNotification notification;

  const _NotificationBannerCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final accent = notification.accentColor.color;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.surface.withValues(alpha: 0.96),
              AppTheme.bg3.withValues(alpha: 0.92),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent, Color.lerp(accent, Colors.white, 0.15)!]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              notification.category.toUpperCase(),
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
