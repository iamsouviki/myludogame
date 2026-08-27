import 'package:flutter/material.dart';

import '../../utils/constants.dart';

class TokenWidget extends StatefulWidget {
  final PlayerColor playerColor;
  final double size;
  final bool isHighlighted;
  final bool isInBase;
  final String? pawnAsset;
  final VoidCallback? onTap;

  const TokenWidget({
    super.key,
    required this.playerColor,
    this.size = 32,
    this.isHighlighted = false,
    this.isInBase = false,
    this.pawnAsset,
    this.onTap,
  });

  @override
  State<TokenWidget> createState() => _TokenWidgetState();
}

class _TokenWidgetState extends State<TokenWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    if (widget.isHighlighted) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(TokenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted != oldWidget.isHighlighted) {
      if (widget.isHighlighted) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.playerColor.color;
    final size = widget.size;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = widget.isHighlighted
              ? 1.0 + (_pulseController.value * 0.22)
              : 1.0;
          return Transform.scale(scale: scale, child: child);
        },
        child: widget.pawnAsset == null
            ? _buildProceduralToken(color, size)
            : _buildPawnToken(color, size),
      ),
    );
  }

  Widget _buildPawnToken(Color color, double size) {
    return Image.asset(
      widget.pawnAsset!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) =>
          _buildProceduralToken(color, size),
    );
  }

  Widget _buildProceduralToken(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 0.9,
          colors: [
            Colors.white,
            Color.lerp(color, Colors.white, 0.35)!,
            color,
            Color.lerp(color, Colors.black, 0.45)!,
          ],
          stops: const [0.0, 0.22, 0.7, 1.0],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.35),
              radius: 0.85,
              colors: [
                Colors.white,
                Color.lerp(color, Colors.white, 0.25)!,
                color,
              ],
            ),
            border: Border.all(
              color: widget.isHighlighted ? Colors.white : Colors.black87,
              width: widget.isHighlighted ? 2.5 : 1.8,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.55,
                height: size * 0.55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                ),
              ),
              Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.black54, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.9),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
