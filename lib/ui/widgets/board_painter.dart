import 'dart:math';
import 'package:flutter/material.dart';

import '../../game/board_config.dart';
import '../../models/game_state.dart';
import '../../utils/constants.dart';

class BoardPainter extends CustomPainter {
  final GameState state;
  final BoardConfig config;

  BoardPainter({required this.state, required this.config});

  @override
  void paint(Canvas canvas, Size size) {
    if (state.boardType == BoardType.classic4) {
      _paintClassic4(canvas, size);
    } else {
      _paintHex6(canvas, size);
    }
  }

  void _paintClassic4(Canvas canvas, Size size) {
    final cellSize = config.cellSize;
    final boardOrigin = Offset(
      config.center.dx - 7.5 * cellSize,
      config.center.dy - 7.5 * cellSize,
    );

    // Board Drop Shadow
    final boardRect = Rect.fromLTWH(
      boardOrigin.dx,
      boardOrigin.dy,
      15 * cellSize,
      15 * cellSize,
    );
    canvas.drawRect(
      boardRect.inflate(3),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // 1. Board Background (Clean Crisp White)
    canvas.drawRect(boardRect, Paint()..color = Colors.white);

    // 2. Draw 4 Corner Base Blocks (Matching image exactly: Green TL, Yellow TR, Red BL, Blue BR)
    _drawClassicBase(canvas, boardOrigin, cellSize, 0, 0, PlayerColor.green);  // Top Left: GREEN
    _drawClassicBase(canvas, boardOrigin, cellSize, 9, 0, PlayerColor.yellow); // Top Right: YELLOW
    _drawClassicBase(canvas, boardOrigin, cellSize, 0, 9, PlayerColor.red);    // Bottom Left: RED
    _drawClassicBase(canvas, boardOrigin, cellSize, 9, 9, PlayerColor.blue);   // Bottom Right: BLUE

    // 3. Colored Start Cells & Entry Arrows
    _drawEntryArrowsAndColoredStarts(canvas, boardOrigin, cellSize);

    // 4. Colored Home Stretches
    // Red: Bottom arm going up (Col 7, Rows 9..13)
    for (var r = 9; r <= 13; r++) {
      canvas.drawRect(
        Rect.fromLTWH(boardOrigin.dx + 7 * cellSize, boardOrigin.dy + r * cellSize, cellSize, cellSize),
        Paint()..color = PlayerColor.red.color,
      );
    }
    // Green: Left arm going right (Row 7, Cols 1..5)
    for (var c = 1; c <= 5; c++) {
      canvas.drawRect(
        Rect.fromLTWH(boardOrigin.dx + c * cellSize, boardOrigin.dy + 7 * cellSize, cellSize, cellSize),
        Paint()..color = PlayerColor.green.color,
      );
    }
    // Yellow: Top arm going down (Col 7, Rows 1..5)
    for (var r = 1; r <= 5; r++) {
      canvas.drawRect(
        Rect.fromLTWH(boardOrigin.dx + 7 * cellSize, boardOrigin.dy + r * cellSize, cellSize, cellSize),
        Paint()..color = PlayerColor.yellow.color,
      );
    }
    // Blue: Right arm going left (Row 7, Cols 9..13)
    for (var c = 9; c <= 13; c++) {
      canvas.drawRect(
        Rect.fromLTWH(boardOrigin.dx + c * cellSize, boardOrigin.dy + 7 * cellSize, cellSize, cellSize),
        Paint()..color = PlayerColor.blue.color,
      );
    }

    // 5. Clean Grid Lines strictly on 3x6 track arms
    final gridLinePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    _drawTrackGridLines(canvas, boardOrigin, cellSize, gridLinePaint);

    // 6. Center Triangle Home Box
    _drawCenterHome(canvas, boardOrigin, cellSize);

    // 7. Safe Spot Outline Stars
    _drawStarAtCell(canvas, boardOrigin, cellSize, 1, 6, PlayerColor.green.color);  // Green safe spot
    _drawStarAtCell(canvas, boardOrigin, cellSize, 2, 8, Colors.black87);
    _drawStarAtCell(canvas, boardOrigin, cellSize, 8, 1, PlayerColor.yellow.color); // Yellow safe spot
    _drawStarAtCell(canvas, boardOrigin, cellSize, 6, 2, Colors.black87);
    _drawStarAtCell(canvas, boardOrigin, cellSize, 13, 8, PlayerColor.blue.color);  // Blue safe spot
    _drawStarAtCell(canvas, boardOrigin, cellSize, 12, 6, Colors.black87);
    _drawStarAtCell(canvas, boardOrigin, cellSize, 6, 13, PlayerColor.red.color);   // Red safe spot
    _drawStarAtCell(canvas, boardOrigin, cellSize, 8, 12, Colors.black87);

    // Outer Board Frame
    canvas.drawRect(
      boardRect,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _drawTrackGridLines(
      Canvas canvas, Offset origin, double cellSize, Paint linePaint) {
    // Top arm (Cols 6..8, Rows 0..5)
    for (var col = 6; col <= 8; col++) {
      for (var row = 0; row <= 5; row++) {
        canvas.drawRect(
          Rect.fromLTWH(origin.dx + col * cellSize, origin.dy + row * cellSize, cellSize, cellSize),
          linePaint,
        );
      }
    }
    // Bottom arm (Cols 6..8, Rows 9..14)
    for (var col = 6; col <= 8; col++) {
      for (var row = 9; row <= 14; row++) {
        canvas.drawRect(
          Rect.fromLTWH(origin.dx + col * cellSize, origin.dy + row * cellSize, cellSize, cellSize),
          linePaint,
        );
      }
    }
    // Left arm (Cols 0..5, Rows 6..8)
    for (var col = 0; col <= 5; col++) {
      for (var row = 6; row <= 8; row++) {
        canvas.drawRect(
          Rect.fromLTWH(origin.dx + col * cellSize, origin.dy + row * cellSize, cellSize, cellSize),
          linePaint,
        );
      }
    }
    // Right arm (Cols 9..14, Rows 6..8)
    for (var col = 9; col <= 14; col++) {
      for (var row = 6; row <= 8; row++) {
        canvas.drawRect(
          Rect.fromLTWH(origin.dx + col * cellSize, origin.dy + row * cellSize, cellSize, cellSize),
          linePaint,
        );
      }
    }
  }

  void _drawClassicBase(Canvas canvas, Offset origin, double cellSize,
      int gridX, int gridY, PlayerColor playerColor) {
    final rect = Rect.fromLTWH(
      origin.dx + gridX * cellSize,
      origin.dy + gridY * cellSize,
      6 * cellSize,
      6 * cellSize,
    );

    // Active Player Base Box Glow (Glows the ENTIRE 6x6 base box without white border)
    final isCurrentTurn = state.currentPlayer.color == playerColor && !state.isGameOver;
    if (isCurrentTurn) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(6), Radius.circular(cellSize * 0.5)),
        Paint()
          ..color = playerColor.color.withValues(alpha: 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }

    // Solid Base Fill
    canvas.drawRect(rect, Paint()..color = playerColor.color);

    // Base Outer Border Line
    canvas.drawRect(
      rect,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // White Rounded Inner Base Plate (Left: gridX + 0.8, Top: gridY + 0.8, Size: 4.4 x 4.4 cellSize)
    final innerRect = Rect.fromLTWH(
      origin.dx + (gridX + 0.8) * cellSize,
      origin.dy + (gridY + 0.8) * cellSize,
      4.4 * cellSize,
      4.4 * cellSize,
    );
    final innerRRect = RRect.fromRectAndRadius(
      innerRect,
      Radius.circular(cellSize * 0.7),
    );

    canvas.drawRRect(
      innerRRect.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(innerRRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      innerRRect,
      Paint()
        ..color = Colors.black12
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 4 Colored Base Circles for Tokens (Exact match with BoardConfig base calculation)
    final dotRadius = cellSize * 0.45;

    final positions = [
      Offset(origin.dx + (gridX + 2.05) * cellSize, origin.dy + (gridY + 2.05) * cellSize),
      Offset(origin.dx + (gridX + 3.95) * cellSize, origin.dy + (gridY + 2.05) * cellSize),
      Offset(origin.dx + (gridX + 2.05) * cellSize, origin.dy + (gridY + 3.95) * cellSize),
      Offset(origin.dx + (gridX + 3.95) * cellSize, origin.dy + (gridY + 3.95) * cellSize),
    ];

    for (final pos in positions) {
      canvas.drawCircle(pos, dotRadius, Paint()..color = playerColor.color);
    }
  }

  void _drawEntryArrowsAndColoredStarts(
      Canvas canvas, Offset origin, double cellSize) {
    // 1. Red Start Cell (Col 6, Row 13)
    canvas.drawRect(
      Rect.fromLTWH(origin.dx + 6 * cellSize, origin.dy + 13 * cellSize, cellSize, cellSize),
      Paint()..color = PlayerColor.red.color,
    );
    // Red Arrow at (Col 7, Row 14) pointing UP
    _drawArrow(
      canvas,
      Offset(origin.dx + 7.5 * cellSize, origin.dy + 14.5 * cellSize),
      cellSize * 0.35,
      PlayerColor.red.color,
      -pi / 2,
    );

    // 2. Green Start Cell (Col 1, Row 6)
    canvas.drawRect(
      Rect.fromLTWH(origin.dx + 1 * cellSize, origin.dy + 6 * cellSize, cellSize, cellSize),
      Paint()..color = PlayerColor.green.color,
    );
    // Green Arrow at (Col 0, Row 7) pointing RIGHT
    _drawArrow(
      canvas,
      Offset(origin.dx + 0.5 * cellSize, origin.dy + 7.5 * cellSize),
      cellSize * 0.35,
      PlayerColor.green.color,
      0,
    );

    // 3. Yellow Start Cell (Col 8, Row 1)
    canvas.drawRect(
      Rect.fromLTWH(origin.dx + 8 * cellSize, origin.dy + 1 * cellSize, cellSize, cellSize),
      Paint()..color = PlayerColor.yellow.color,
    );
    // Yellow Arrow at (Col 7, Row 0) pointing DOWN
    _drawArrow(
      canvas,
      Offset(origin.dx + 7.5 * cellSize, origin.dy + 0.5 * cellSize),
      cellSize * 0.35,
      PlayerColor.yellow.color,
      pi / 2,
    );

    // 4. Blue Start Cell (Col 13, Row 8)
    canvas.drawRect(
      Rect.fromLTWH(origin.dx + 13 * cellSize, origin.dy + 8 * cellSize, cellSize, cellSize),
      Paint()..color = PlayerColor.blue.color,
    );
    // Blue Arrow at (Col 14, Row 7) pointing LEFT
    _drawArrow(
      canvas,
      Offset(origin.dx + 14.5 * cellSize, origin.dy + 7.5 * cellSize),
      cellSize * 0.35,
      PlayerColor.blue.color,
      pi,
    );
  }

  void _drawArrow(Canvas canvas, Offset center, double size, Color color, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final path = Path()
      ..moveTo(-size * 0.5, -size * 0.5)
      ..lineTo(size * 0.4, 0)
      ..lineTo(-size * 0.5, size * 0.5)
      ..lineTo(-size * 0.15, 0)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  void _drawCenterHome(Canvas canvas, Offset origin, double cellSize) {
    final center = Offset(origin.dx + 7.5 * cellSize, origin.dy + 7.5 * cellSize);
    final boxRect = Rect.fromLTWH(
      origin.dx + 6 * cellSize,
      origin.dy + 6 * cellSize,
      3 * cellSize,
      3 * cellSize,
    );

    // Exact match to image: Green Left, Yellow Top, Blue Right, Red Bottom
    final triangles = [
      // Left (Green)
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(boxRect.left, boxRect.top)
        ..lineTo(boxRect.left, boxRect.bottom)
        ..close(),
      // Top (Yellow)
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(boxRect.left, boxRect.top)
        ..lineTo(boxRect.right, boxRect.top)
        ..close(),
      // Right (Blue)
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(boxRect.right, boxRect.top)
        ..lineTo(boxRect.right, boxRect.bottom)
        ..close(),
      // Bottom (Red)
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(boxRect.left, boxRect.bottom)
        ..lineTo(boxRect.right, boxRect.bottom)
        ..close(),
    ];

    final colors = [
      PlayerColor.green.color,
      PlayerColor.yellow.color,
      PlayerColor.blue.color,
      PlayerColor.red.color,
    ];

    for (var i = 0; i < 4; i++) {
      canvas.drawPath(triangles[i], Paint()..color = colors[i]);
    }

    // Black Center Square Outline
    canvas.drawRect(
      boxRect,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawStarAtCell(Canvas canvas, Offset origin, double cellSize, int gridX, int gridY, Color color) {
    final center = Offset(origin.dx + (gridX + 0.5) * cellSize, origin.dy + (gridY + 0.5) * cellSize);
    _drawClassicStar(canvas, center, cellSize * 0.32, color);
  }

  void _drawClassicStar(Canvas canvas, Offset center, double size, Color color) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final outerAngle = (i * 72 - 90) * pi / 180;
      final innerAngle = ((i * 72) + 36 - 90) * pi / 180;
      final outerPoint = Offset(
        center.dx + cos(outerAngle) * size,
        center.dy + sin(outerAngle) * size,
      );
      final innerPoint = Offset(
        center.dx + cos(innerAngle) * size * 0.45,
        center.dy + sin(innerAngle) * size * 0.45,
      );
      if (i == 0) {
        path.moveTo(outerPoint.dx, outerPoint.dy);
      } else {
        path.lineTo(outerPoint.dx, outerPoint.dy);
      }
      path.lineTo(innerPoint.dx, innerPoint.dy);
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintHex6(Canvas canvas, Size size) {
    final radius = size.shortestSide * 0.46;

    final hexPath = Path();
    for (var i = 0; i < 6; i++) {
      final angle = i * pi / 3 - pi / 6;
      final point = Offset(
        config.center.dx + cos(angle) * radius,
        config.center.dy + sin(angle) * radius,
      );
      if (i == 0) {
        hexPath.moveTo(point.dx, point.dy);
      } else {
        hexPath.lineTo(point.dx, point.dy);
      }
    }
    hexPath.close();

    canvas.drawPath(hexPath, Paint()..color = Colors.white);
    canvas.drawPath(
      hexPath,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final trackCellBg = Paint()..color = Colors.white;
    final trackBorder = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (var i = 0; i < 78; i++) {
      final pos = config.trackCellPosition(i);
      final cellRadius = config.cellSize * 0.42;

      Paint? specialPaint;
      if (state.safeSpots.contains(i)) {
        for (var p = 0; p < state.players.length; p++) {
          if (state.startPosition(p) == i) {
            specialPaint = Paint()..color = state.players[p].color.color;
            break;
          }
        }
      }

      canvas.drawCircle(pos, cellRadius, specialPaint ?? trackCellBg);
      canvas.drawCircle(pos, cellRadius, trackBorder);

      if (state.safeSpots.contains(i)) {
        _drawClassicStar(canvas, pos, cellRadius * 0.55, Colors.black87);
      }
    }

    for (var p = 0; p < state.players.length; p++) {
      final color = state.players[p].color.color;

      for (var s = 0; s < state.boardType.homeStretchLength; s++) {
        final pos = config.homeStretchPosition(p, s);
        final r = config.cellSize * 0.38;
        canvas.drawCircle(pos, r, Paint()..color = color);
        canvas.drawCircle(pos, r, trackBorder);
      }

      final baseAngle = p * pi / 3 - pi / 2 + pi / 6;
      final baseCenter = Offset(
        config.center.dx + cos(baseAngle) * radius * 0.75,
        config.center.dy + sin(baseAngle) * radius * 0.75,
      );
      canvas.drawCircle(baseCenter, config.cellSize * 2.5, Paint()..color = color);
      canvas.drawCircle(
        baseCenter,
        config.cellSize * 2.5,
        Paint()
          ..color = const Color(0xFF0F172A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        baseCenter,
        config.cellSize * 1.8,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}
