import 'package:flutter/material.dart';

class AvatarData {
  final int index;
  final String emoji;
  final String name;
  final Color bg;

  const AvatarData({
    required this.index,
    required this.emoji,
    required this.name,
    required this.bg,
  });
}

class Avatars {
  static const List<AvatarData> list = [
    AvatarData(index: 0, emoji: '👑', name: 'King', bg: Color(0xFFEAB308)),
    AvatarData(index: 1, emoji: '🦁', name: 'Lion', bg: Color(0xFFF97316)),
    AvatarData(index: 2, emoji: '🐉', name: 'Dragon', bg: Color(0xFFEF4444)),
    AvatarData(index: 3, emoji: '🥷', name: 'Ninja', bg: Color(0xFF6B7280)),
    AvatarData(index: 4, emoji: '🚀', name: 'Astronaut', bg: Color(0xFF3B82F6)),
    AvatarData(index: 5, emoji: '🧙‍♂️', name: 'Wizard', bg: Color(0xFF8B5CF6)),
    AvatarData(index: 6, emoji: '🦊', name: 'Fox', bg: Color(0xFFD97706)),
    AvatarData(index: 7, emoji: '🐼', name: 'Panda', bg: Color(0xFF10B981)),
    AvatarData(index: 8, emoji: '🐯', name: 'Tiger', bg: Color(0xFFF59E0B)),
    AvatarData(index: 9, emoji: '⚡', name: 'Lightning', bg: Color(0xFFEC4899)),
  ];

  static AvatarData get(int index) {
    if (index < 0 || index >= list.length) return list[0];
    return list[index];
  }
}

class PlayerAvatarWidget extends StatelessWidget {
  final int avatarIndex;
  final double size;
  final Color? borderColor;

  const PlayerAvatarWidget({
    super.key,
    required this.avatarIndex,
    this.size = 40,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = Avatars.get(avatarIndex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: avatar.bg.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? avatar.bg,
          width: size > 40 ? 2.5 : 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: (borderColor ?? avatar.bg).withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Text(
          avatar.emoji,
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }
}
