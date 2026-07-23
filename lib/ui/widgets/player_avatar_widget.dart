import 'package:flutter/material.dart';

class AvatarData {
  final int index;
  final IconData icon;
  final String name;
  final Color bg;

  const AvatarData({
    required this.index,
    required this.icon,
    required this.name,
    required this.bg,
  });
}

class Avatars {
  static const List<AvatarData> list = [
    AvatarData(index: 0, icon: Icons.workspace_premium, name: 'King', bg: Color(0xFFEAB308)),
    AvatarData(index: 1, icon: Icons.sports_kabaddi, name: 'Warrior', bg: Color(0xFFF97316)),
    AvatarData(index: 2, icon: Icons.local_fire_department, name: 'Dragon', bg: Color(0xFFEF4444)),
    AvatarData(index: 3, icon: Icons.shield, name: 'Knight', bg: Color(0xFF6B7280)),
    AvatarData(index: 4, icon: Icons.rocket_launch, name: 'Pilot', bg: Color(0xFF3B82F6)),
    AvatarData(index: 5, icon: Icons.auto_awesome, name: 'Wizard', bg: Color(0xFF8B5CF6)),
    AvatarData(index: 6, icon: Icons.pets, name: 'Hunter', bg: Color(0xFFD97706)),
    AvatarData(index: 7, icon: Icons.psychology, name: 'Master', bg: Color(0xFF10B981)),
    AvatarData(index: 8, icon: Icons.bolt, name: 'Flash', bg: Color(0xFFF59E0B)),
    AvatarData(index: 9, icon: Icons.star, name: 'Star', bg: Color(0xFFEC4899)),
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
    final c = borderColor ?? avatar.bg;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 0.95,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            avatar.bg.withValues(alpha: 0.22),
            avatar.bg.withValues(alpha: 0.42),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: c,
          width: size > 40 ? 2.6 : 1.9,
        ),
        boxShadow: [
          BoxShadow(color: c.withValues(alpha: 0.32), blurRadius: 10, spreadRadius: 1),
          BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Center(
        child: Icon(
          avatar.icon,
          size: size * 0.58,
          color: c,
        ),
      ),
    );
  }
}
