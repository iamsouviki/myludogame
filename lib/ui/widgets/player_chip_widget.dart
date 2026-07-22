import 'package:flutter/material.dart';
import '../../models/player.dart';

class PlayerChipWidget extends StatelessWidget {
  final Player player;
  final bool isCurrent;
  final bool hasFinished;
  final Animation<double>? turnGlowAnimation;

  const PlayerChipWidget({
    super.key,
    required this.player,
    required this.isCurrent,
    required this.hasFinished,
    this.turnGlowAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final color = player.color.color;
    final glowValue = turnGlowAnimation?.value ?? 0.0;
    final glow = isCurrent ? glowValue * 0.4 : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: isCurrent
            ? LinearGradient(
                colors: [
                  color.withValues(alpha: 0.2 + glow),
                  color.withValues(alpha: 0.08),
                ],
              )
            : null,
        color: isCurrent ? null : const Color(0xFF1A1F35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? color.withValues(alpha: 0.6) : const Color(0xFF2A3350),
          width: isCurrent ? 1.5 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.2 + glow * 0.3),
                  blurRadius: 12,
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 6,
                      )
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            player.name,
            style: TextStyle(
              color: isCurrent ? const Color(0xFFF1F5F9) : const Color(0xFF94A3B8),
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
          if (hasFinished) ...[
            const SizedBox(width: 6),
            const Text('✅', style: TextStyle(fontSize: 11)),
          ],
          if (player.isAI) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.smart_toy_rounded,
              size: 12,
              color: Color(0xFF64748B),
            ),
          ],
        ],
      ),
    );
  }
}
