import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../theme.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  String _filter = 'all';

  List<AppNotification> get _items {
    final items = NotificationService.instance.items;
    return switch (_filter) {
      'unread' => items.where((n) => !n.isRead).toList(),
      'game' => items.where((n) => n.category == 'game').toList(),
      'social' => items.where((n) => n.category == 'social').toList(),
      'reward' => items.where((n) => n.category == 'reward').toList(),
      _ => items,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.artisticBackground(),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Notifications',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        NotificationService.instance.markAllRead();
                        setState(() {});
                      },
                      child: const Text('Mark all read'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('All', 'all'),
                    _chip('Unread', 'unread'),
                    _chip('Game', 'game'),
                    _chip('Social', 'social'),
                    _chip('Rewards', 'reward'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final accent = item.accentColor.color;
                    return Dismissible(
                      key: ValueKey(item.id),
                      background: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      onDismissed: (_) => NotificationService.instance.clearAll(),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.glassCard(glowColor: accent),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [accent, Color.lerp(accent, Colors.white, 0.2)!]),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                item.isRead ? Icons.mark_email_read_rounded : Icons.notifications_active_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      Text(
                                        item.category.toUpperCase(),
                                        style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.body,
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                                  ),
                                  if (item.deepLink != null) ...[
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: OutlinedButton(
                                        onPressed: () {
                                          NotificationService.instance.markRead(item.id);
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Open'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: const Color(0xFFEC4899).withValues(alpha: 0.25),
      backgroundColor: AppTheme.bg3,
      labelStyle: TextStyle(color: selected ? Colors.white : AppTheme.textSecondary),
      side: BorderSide(color: selected ? const Color(0xFFEC4899) : AppTheme.border),
    );
  }
}
