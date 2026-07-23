import '../utils/constants.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String category;
  final String? deepLink;
  final String? imageUrl;
  final String? senderName;
  final int timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timestamp,
    this.deepLink,
    this.imageUrl,
    this.senderName,
    this.isRead = false,
  });

  factory AppNotification.fromRemote(Map<String, dynamic> data) {
    return AppNotification(
      id: (data['id'] as String?) ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: (data['title'] as String?) ?? 'Notification',
      body: (data['body'] as String?) ?? '',
      category: (data['category'] as String?) ?? 'general',
      timestamp: (data['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      deepLink: data['deepLink'] as String?,
      imageUrl: data['imageUrl'] as String?,
      senderName: data['senderName'] as String?,
      isRead: (data['isRead'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'category': category,
        'timestamp': timestamp,
        'deepLink': deepLink,
        'imageUrl': imageUrl,
        'senderName': senderName,
        'isRead': isRead,
      };

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      category: category,
      timestamp: timestamp,
      deepLink: deepLink,
      imageUrl: imageUrl,
      senderName: senderName,
      isRead: isRead ?? this.isRead,
    );
  }

  PlayerColor get accentColor {
    return switch (category) {
      'game' => PlayerColor.blue,
      'reward' => PlayerColor.gold,
      'social' => PlayerColor.pink,
      'event' => PlayerColor.violet,
      'promo' => PlayerColor.orange,
      _ => PlayerColor.cyan,
    };
  }
}
