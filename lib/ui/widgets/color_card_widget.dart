import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class ColorCardWidget extends StatelessWidget {
  final PlayerColor playerColor;
  final bool isHuman;
  final int index;

  const ColorCardWidget({
    super.key,
    required this.playerColor,
    required this.isHuman,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 95,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            playerColor.color.withValues(alpha: 0.25),
            playerColor.color.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: playerColor.color.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: playerColor.color.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.3),
                colors: [
                  Color.lerp(playerColor.color, Colors.white, 0.3)!,
                  playerColor.color,
                  Color.lerp(playerColor.color, Colors.black, 0.2)!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: playerColor.color.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Icon(
              isHuman ? Icons.person_rounded : Icons.smart_toy_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isHuman ? 'P${index + 1}' : 'Bot',
            style: TextStyle(
              color: playerColor.color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          Text(
            playerColor.label,
            style: TextStyle(
              color: playerColor.color.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
