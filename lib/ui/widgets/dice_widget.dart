import 'package:flutter/material.dart';

class DiceWidget extends StatefulWidget {
  final int? value;
  final bool canRoll;
  final VoidCallback? onRoll;
  final Color color;

  const DiceWidget({
    super.key,
    this.value,
    this.canRoll = false,
    this.onRoll,
    this.color = const Color(0xFF10B981),
  });

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;
  late Animation<double> _scale;
  late Animation<double> _shake;
  int _displayValue = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _rotation = Tween<double>(begin: 0, end: 6 * 3.14159).animate(
      CurvedAnimation(parent: _controller, curve: Curves.decelerate),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 20),
    ]).animate(_controller);

    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.2), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.2, end: 0.2), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.2, end: -0.1), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -0.1, end: 0.0), weight: 15),
    ]).animate(_controller);

    _controller.addListener(() {
      if (_controller.isAnimating && _controller.value < 0.9) {
        setState(() {
          _displayValue = (_displayValue % 6) + 1;
        });
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _displayValue = widget.value ?? _displayValue;
        });
      }
    });

    if (widget.value != null) _displayValue = widget.value!;
  }

  @override
  void didUpdateWidget(DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != null) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!widget.canRoll) return;
    _controller.forward(from: 0);
    widget.onRoll?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Active color derived from player token color for both rolling phase and result display
    final playerColor = widget.color;
    final darkShade = Color.lerp(playerColor, Colors.black, 0.45)!;
    final lightBorder = Color.lerp(playerColor, Colors.white, 0.4)!;

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _controller.isAnimating ? _scale.value : 1.0,
            child: Transform.rotate(
              angle: _controller.isAnimating ? _rotation.value + _shake.value : 0,
              child: child,
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [playerColor, darkShade],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: lightBorder,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: playerColor.withValues(alpha: 0.55),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _DiceFacePainter(
              value: _displayValue,
              dotColor: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiceFacePainter extends CustomPainter {
  final int value;
  final Color dotColor;

  _DiceFacePainter({required this.value, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final dotPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          dotColor,
          Color.lerp(dotColor, Colors.black, 0.4)!,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final dotRadius = size.width * 0.085;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final offset = size.width * 0.25;

    final dots = <Offset>[];
    switch (value) {
      case 1:
        dots.add(Offset(cx, cy));
      case 2:
        dots.addAll([Offset(cx - offset, cy - offset), Offset(cx + offset, cy + offset)]);
      case 3:
        dots.addAll([
          Offset(cx - offset, cy + offset),
          Offset(cx, cy),
          Offset(cx + offset, cy - offset),
        ]);
      case 4:
        dots.addAll([
          Offset(cx - offset, cy - offset),
          Offset(cx + offset, cy - offset),
          Offset(cx - offset, cy + offset),
          Offset(cx + offset, cy + offset),
        ]);
      case 5:
        dots.addAll([
          Offset(cx - offset, cy - offset),
          Offset(cx + offset, cy - offset),
          Offset(cx, cy),
          Offset(cx - offset, cy + offset),
          Offset(cx + offset, cy + offset),
        ]);
      case 6:
        dots.addAll([
          Offset(cx - offset, cy - offset),
          Offset(cx + offset, cy - offset),
          Offset(cx - offset, cy),
          Offset(cx + offset, cy),
          Offset(cx - offset, cy + offset),
          Offset(cx + offset, cy + offset),
        ]);
    }

    for (final dot in dots) {
      canvas.drawCircle(dot + const Offset(0, 1.5), dotRadius, shadowPaint);
      canvas.drawCircle(dot, dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DiceFacePainter old) =>
      value != old.value || dotColor != old.dotColor;
}
