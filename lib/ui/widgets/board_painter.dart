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

    // Resolve physical board areas by color, while turn order stays player-list based.
    final p0 = _playerAtRouteSlot(0);
    final p1 = _playerAtRouteSlot(1);
    final p2 = _playerAtRouteSlot(2);
    final p3 = _playerAtRouteSlot(3);
    final p0Color = p0 == null ? PlayerColor.red : state.players[p0].color;
    final p1Color = p1 == null ? PlayerColor.green : state.players[p1].color;
    final p2Color = p2 == null ? PlayerColor.yellow : state.players[p2].color;
    final p3Color = p3 == null ? PlayerColor.blue : state.players[p3].color;

    // 2. Draw 4 Corner Base Blocks with their route-slot occupants.
    _drawClassicBase(
      canvas,
      boardOrigin,
      cellSize,
      0,
      0,
      p1Color,
      p1,
    ); // Top Left
    _drawClassicBase(
      canvas,
      boardOrigin,
      cellSize,
      9,
      0,
      p2Color,
      p2,
    ); // Top Right
    _drawClassicBase(
      canvas,
      boardOrigin,
      cellSize,
      0,
      9,
      p0Color,
      p0,
    ); // Bottom Left
    _drawClassicBase(
      canvas,
      boardOrigin,
      cellSize,
      9,
      9,
      p3Color,
      p3,
    ); // Bottom Right

    // 3. Colored Start Cells & Entry Arrows
    _drawEntryArrowsAndColoredStarts(
      canvas,
      boardOrigin,
      cellSize,
      p0Color,
      p1Color,
      p2Color,
      p3Color,
    );

    // 4. Colored Home Stretches
    // P0: Bottom arm going up (Col 7, Rows 9..13)
    for (var r = 9; r <= 13; r++) {
      canvas.drawRect(
        Rect.fromLTWH(
          boardOrigin.dx + 7 * cellSize,
          boardOrigin.dy + r * cellSize,
          cellSize,
          cellSize,
        ),
        Paint()..color = p0Color.color,
      );
    }
    // P1: Left arm going right (Row 7, Cols 1..5)
    for (var c = 1; c <= 5; c++) {
      canvas.drawRect(
        Rect.fromLTWH(
          boardOrigin.dx + c * cellSize,
          boardOrigin.dy + 7 * cellSize,
          cellSize,
          cellSize,
        ),
        Paint()..color = p1Color.color,
      );
    }
    // P2: Top arm going down (Col 7, Rows 1..5)
    for (var r = 1; r <= 5; r++) {
      canvas.drawRect(
        Rect.fromLTWH(
          boardOrigin.dx + 7 * cellSize,
          boardOrigin.dy + r * cellSize,
          cellSize,
          cellSize,
        ),
        Paint()..color = p2Color.color,
      );
    }
    // P3: Right arm going left (Row 7, Cols 9..13)
    for (var c = 9; c <= 13; c++) {
      canvas.drawRect(
        Rect.fromLTWH(
          boardOrigin.dx + c * cellSize,
          boardOrigin.dy + 7 * cellSize,
          cellSize,
          cellSize,
        ),
        Paint()..color = p3Color.color,
      );
    }

    // 5. Clean Grid Lines strictly on 3x6 track arms
    final gridLinePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    _drawTrackGridLines(canvas, boardOrigin, cellSize, gridLinePaint);

    // 6. Center Triangle Home Box
    _drawCenterHome(
      canvas,
      boardOrigin,
      cellSize,
      p0Color,
      p1Color,
      p2Color,
      p3Color,
    );

    // 7. Safe Spot Outline Stars (use actual player colors)
    _drawStarAtCell(
      canvas,
      boardOrigin,
      cellSize,
      1,
      6,
      p1Color.color,
    ); // P1 safe spot
    _drawStarAtCell(canvas, boardOrigin, cellSize, 2, 8, Colors.black87);
    _drawStarAtCell(
      canvas,
      boardOrigin,
      cellSize,
      8,
      1,
      p2Color.color,
    ); // P2 safe spot
    _drawStarAtCell(canvas, boardOrigin, cellSize, 6, 2, Colors.black87);
    _drawStarAtCell(
      canvas,
      boardOrigin,
      cellSize,
      13,
      8,
      p3Color.color,
    ); // P3 safe spot
    _drawStarAtCell(canvas, boardOrigin, cellSize, 12, 6, Colors.black87);
    _drawStarAtCell(
      canvas,
      boardOrigin,
      cellSize,
      6,
      13,
      p0Color.color,
    ); // P0 safe spot
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
    Canvas canvas,
    Offset origin,
    double cellSize,
    Paint linePaint,
  ) {
    // Top arm (Cols 6..8, Rows 0..5)
    for (var col = 6; col <= 8; col++) {
      for (var row = 0; row <= 5; row++) {
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + col * cellSize,
            origin.dy + row * cellSize,
            cellSize,
            cellSize,
          ),
          linePaint,
        );
      }
    }
    // Bottom arm (Cols 6..8, Rows 9..14)
    for (var col = 6; col <= 8; col++) {
      for (var row = 9; row <= 14; row++) {
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + col * cellSize,
            origin.dy + row * cellSize,
            cellSize,
            cellSize,
          ),
          linePaint,
        );
      }
    }
    // Left arm (Cols 0..5, Rows 6..8)
    for (var col = 0; col <= 5; col++) {
      for (var row = 6; row <= 8; row++) {
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + col * cellSize,
            origin.dy + row * cellSize,
            cellSize,
            cellSize,
          ),
          linePaint,
        );
      }
    }
    // Right arm (Cols 9..14, Rows 6..8)
    for (var col = 9; col <= 14; col++) {
      for (var row = 6; row <= 8; row++) {
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + col * cellSize,
            origin.dy + row * cellSize,
            cellSize,
            cellSize,
          ),
          linePaint,
        );
      }
    }
  }

  int? _playerAtRouteSlot(int routeSlot) {
    for (var i = 0; i < state.players.length; i++) {
      if (state.playerPositionIndex(i) == routeSlot) return i;
    }
    return null;
  }

  void _drawClassicBase(
    Canvas canvas,
    Offset origin,
    double cellSize,
    int gridX,
    int gridY,
    PlayerColor playerColor,
    int? playerIndex,
  ) {
    final rect = Rect.fromLTWH(
      origin.dx + gridX * cellSize,
      origin.dy + gridY * cellSize,
      6 * cellSize,
      6 * cellSize,
    );

    // Active Player Base Box Glow — match by playerIndex, not color
    final isCurrentTurn =
        playerIndex != null &&
        state.currentPlayerIndex == playerIndex &&
        !state.isGameOver;
    if (isCurrentTurn) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.inflate(6),
          Radius.circular(cellSize * 0.5),
        ),
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

    // Draw Player Name Banner — match by playerIndex
    final matchingPlayer =
        playerIndex != null &&
            playerIndex >= 0 &&
            playerIndex < state.players.length
        ? state.players[playerIndex]
        : null;
    if (matchingPlayer != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: matchingPlayer.name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: cellSize * 0.38,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '...',
      )..layout(maxWidth: 5.2 * cellSize);

      final bgWidth = textPainter.width + 12;
      final bgHeight = textPainter.height + 4;
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + (rect.width - bgWidth) / 2,
          rect.top + cellSize * 0.15,
          bgWidth,
          bgHeight,
        ),
        Radius.circular(cellSize * 0.25),
      );

      canvas.drawRRect(
        bgRect,
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      );
      textPainter.paint(
        canvas,
        Offset(
          rect.left + (rect.width - textPainter.width) / 2,
          rect.top + cellSize * 0.15 + 2,
        ),
      );
    }

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

    // 4 colored pawn sockets match the 0.70-cell 3D pawn footprint.
    final dotRadius = cellSize * 0.35;

    final positions = [
      Offset(
        origin.dx + (gridX + 2.05) * cellSize,
        origin.dy + (gridY + 2.05) * cellSize,
      ),
      Offset(
        origin.dx + (gridX + 3.95) * cellSize,
        origin.dy + (gridY + 2.05) * cellSize,
      ),
      Offset(
        origin.dx + (gridX + 2.05) * cellSize,
        origin.dy + (gridY + 3.95) * cellSize,
      ),
      Offset(
        origin.dx + (gridX + 3.95) * cellSize,
        origin.dy + (gridY + 3.95) * cellSize,
      ),
    ];

    final finishIndex = playerIndex == null
        ? -1
        : state.finishOrder.indexOf(playerIndex);
    final isFinished =
        finishIndex >= 0 && state.hasPlayerFinished(playerIndex!);
    if (!isFinished) {
      for (final pos in positions) {
        canvas.drawCircle(pos, dotRadius, Paint()..color = playerColor.color);
      }
    }

    if (isFinished) {
      final rankText = _ordinal(finishIndex + 1);
      final rankPainter = TextPainter(
        text: TextSpan(
          text: rankText,
          style: TextStyle(
            color: Colors.white,
            fontSize: cellSize * 0.72,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 5)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final rankCenter = Offset(
        origin.dx + (gridX + 3) * cellSize,
        origin.dy + (gridY + 3) * cellSize,
      );
      final badgeRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: rankCenter,
          width: rankPainter.width + cellSize * 0.36,
          height: rankPainter.height + cellSize * 0.16,
        ),
        Radius.circular(cellSize * 0.24),
      );
      canvas.drawRRect(
        badgeRect,
        Paint()..color = Colors.black.withValues(alpha: 0.68),
      );
      rankPainter.paint(
        canvas,
        rankCenter - Offset(rankPainter.width / 2, rankPainter.height / 2),
      );
    }
  }

  String _ordinal(int number) {
    if (number % 100 >= 11 && number % 100 <= 13) return '${number}th';
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  void _drawEntryArrowsAndColoredStarts(
    Canvas canvas,
    Offset origin,
    double cellSize,
    PlayerColor p0,
    PlayerColor p1,
    PlayerColor p2,
    PlayerColor p3,
  ) {
    // 1. P0 Start Cell (Col 6, Row 13)
    canvas.drawRect(
      Rect.fromLTWH(
        origin.dx + 6 * cellSize,
        origin.dy + 13 * cellSize,
        cellSize,
        cellSize,
      ),
      Paint()..color = p0.color,
    );
    // P0 Arrow at (Col 7, Row 14) pointing UP
    _drawArrow(
      canvas,
      Offset(origin.dx + 7.5 * cellSize, origin.dy + 14.5 * cellSize),
      cellSize * 0.35,
      p0.color,
      -pi / 2,
    );

    // 2. P1 Start Cell (Col 1, Row 6)
    canvas.drawRect(
      Rect.fromLTWH(
        origin.dx + 1 * cellSize,
        origin.dy + 6 * cellSize,
        cellSize,
        cellSize,
      ),
      Paint()..color = p1.color,
    );
    // P1 Arrow at (Col 0, Row 7) pointing RIGHT
    _drawArrow(
      canvas,
      Offset(origin.dx + 0.5 * cellSize, origin.dy + 7.5 * cellSize),
      cellSize * 0.35,
      p1.color,
      0,
    );

    // 3. P2 Start Cell (Col 8, Row 1)
    canvas.drawRect(
      Rect.fromLTWH(
        origin.dx + 8 * cellSize,
        origin.dy + 1 * cellSize,
        cellSize,
        cellSize,
      ),
      Paint()..color = p2.color,
    );
    // P2 Arrow at (Col 7, Row 0) pointing DOWN
    _drawArrow(
      canvas,
      Offset(origin.dx + 7.5 * cellSize, origin.dy + 0.5 * cellSize),
      cellSize * 0.35,
      p2.color,
      pi / 2,
    );

    // 4. P3 Start Cell (Col 13, Row 8)
    canvas.drawRect(
      Rect.fromLTWH(
        origin.dx + 13 * cellSize,
        origin.dy + 8 * cellSize,
        cellSize,
        cellSize,
      ),
      Paint()..color = p3.color,
    );
    // P3 Arrow at (Col 14, Row 7) pointing LEFT
    _drawArrow(
      canvas,
      Offset(origin.dx + 14.5 * cellSize, origin.dy + 7.5 * cellSize),
      cellSize * 0.35,
      p3.color,
      pi,
    );
  }

  void _drawArrow(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
    double angle,
  ) {
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

  void _drawCenterHome(
    Canvas canvas,
    Offset origin,
    double cellSize,
    PlayerColor p0Color,
    PlayerColor p1Color,
    PlayerColor p2Color,
    PlayerColor p3Color,
  ) {
    final center = Offset(
      origin.dx + 7.5 * cellSize,
      origin.dy + 7.5 * cellSize,
    );
    final boxRect = Rect.fromLTWH(
      origin.dx + 6 * cellSize,
      origin.dy + 6 * cellSize,
      3 * cellSize,
      3 * cellSize,
    );

    // Triangles use actual player colors: Left=P1, Top=P2, Right=P3, Bottom=P0
    final triangles = [
      // Left (P1)
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(boxRect.left, boxRect.top)
        ..lineTo(boxRect.left, boxRect.bottom)
        ..close(),
      // Top (P2)
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(boxRect.left, boxRect.top)
        ..lineTo(boxRect.right, boxRect.top)
        ..close(),
      // Right (P3)
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(boxRect.right, boxRect.top)
        ..lineTo(boxRect.right, boxRect.bottom)
        ..close(),
      // Bottom (P0)
      Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(boxRect.left, boxRect.bottom)
        ..lineTo(boxRect.right, boxRect.bottom)
        ..close(),
    ];

    final colors = [p1Color.color, p2Color.color, p3Color.color, p0Color.color];

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

  void _drawStarAtCell(
    Canvas canvas,
    Offset origin,
    double cellSize,
    int gridX,
    int gridY,
    Color color,
  ) {
    final center = Offset(
      origin.dx + (gridX + 0.5) * cellSize,
      origin.dy + (gridY + 0.5) * cellSize,
    );
    _drawClassicStar(canvas, center, cellSize * 0.32, color);
  }

  void _drawClassicStar(
    Canvas canvas,
    Offset center,
    double size,
    Color color,
  ) {
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
    _drawHex6BoardShell(canvas);

    final gridPaint = Paint()
      ..color = const Color(0xFF1F2937)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;

    for (var slot = 0; slot < 6; slot++) {
      final ownerIndex = _playerAtRouteSlot(slot);
      final color = ownerIndex == null
          ? BoardType.hex6.availableColors[slot].color
          : state.players[ownerIndex].color.color;
      _drawHex6Arm(canvas, slot, color, gridPaint);
    }

    _drawHex6Center(canvas);

    // Each base is the HTML base-pod: a colored center-facing triangle with a
    // white circular four-token hub and a small label tab at its outer edge.
    for (var slot = 0; slot < 6; slot++) {
      final ownerIndex = _playerAtRouteSlot(slot);
      final playerColor = ownerIndex == null
          ? BoardType.hex6.availableColors[slot]
          : state.players[ownerIndex].color;
      final basePath = _polygonPath(config.hex6BaseCorners(slot));
      canvas.drawPath(
        basePath,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.24)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(basePath, Paint()..color = playerColor.color);
      canvas.drawPath(
        basePath,
        Paint()
          ..color = const Color(0xFF222222)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );

      final baseCenter = config.hex6BaseCenter(slot);
      final plateRadius = config.cellSize * 1.55;
      canvas.drawCircle(
        baseCenter + const Offset(0, 3),
        plateRadius,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(baseCenter, plateRadius, Paint()..color = Colors.white);
      canvas.drawCircle(
        baseCenter,
        plateRadius,
        Paint()
          ..color = const Color(0xFF222222)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );

      final socketPaint = Paint()..color = playerColor.color;
      for (var token = 0; token < tokensPerPlayer; token++) {
        final socket = config.basePosition(slot, token);
        canvas.drawCircle(socket, config.cellSize * 0.43, socketPaint);
        canvas.drawCircle(socket, config.cellSize * 0.43, gridPaint);
      }

      final radialAngle = slot * pi / 3 - pi / 3;
      final labelPainter = TextPainter(
        text: TextSpan(
          text: ownerIndex == null
              ? playerColor.label
              : state.players[ownerIndex].name,
          style: TextStyle(
            color: Colors.white,
            fontSize: config.cellSize * 0.31,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: config.cellSize * 4.0);
      final labelCenter =
          baseCenter +
          Offset(cos(radialAngle), sin(radialAngle)) * config.cellSize * 1.55;
      labelPainter.paint(
        canvas,
        labelCenter - Offset(labelPainter.width / 2, labelPainter.height / 2),
      );
    }
  }

  void _drawHex6Arm(Canvas canvas, int slot, Color color, Paint gridPaint) {
    for (
      var cellInArm = 0;
      cellInArm < state.boardType.cellsPerArm;
      cellInArm++
    ) {
      final cell = slot * state.boardType.cellsPerArm + cellInArm;
      final path = _polygonPath(config.hex6TrackCellCorners(cell));
      final fill = cellInArm == 0 ? color : Colors.white;
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(path, gridPaint);

      if (state.safeSpots.contains(cell)) {
        _drawClassicStar(
          canvas,
          config.trackCellPosition(cell),
          config.cellSize * 0.27,
          color.withValues(alpha: 0.95),
        );
      }
    }

    // The middle column is the player’s five-cell colored home lane.
    for (var step = 0; step < state.boardType.homeStretchLength; step++) {
      final path = _polygonPath(config.hex6HomeCellCorners(slot, step));
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, gridPaint);
    }

    final arrow = config.hex6ArmGridCellPosition(slot, 0, 1);
    _drawHex6Arrow(canvas, arrow, slot, color);
  }

  Path _polygonPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  void _drawHex6BoardShell(Canvas canvas) {
    // A compact regular hexagon keeps the board body continuous, like the
    // supplied six-player references, while colored rooms form the six tips.
    final outerRadius = config.cellSize * 8.85;
    final points = [
      for (var index = 0; index < 6; index++)
        config.center +
            Offset(cos(index * pi / 3 - pi / 2), sin(index * pi / 3 - pi / 2)) *
                outerRadius,
    ];
    final shell = _polygonPath(points);
    canvas.drawPath(
      shell.shift(const Offset(0, 5)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(shell, Paint()..color = const Color(0xFFF8FAFC));
    canvas.drawPath(
      shell,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _drawHex6Center(Canvas canvas) {
    final centerRadius = config.cellSize * 2.0;
    for (var slot = 0; slot < 6; slot++) {
      final start = slot * pi / 3 - pi / 2 - pi / 6;
      final path = Path()
        ..moveTo(config.center.dx, config.center.dy)
        ..lineTo(
          config.center.dx + cos(start) * centerRadius,
          config.center.dy + sin(start) * centerRadius,
        )
        ..lineTo(
          config.center.dx + cos(start + pi / 3) * centerRadius,
          config.center.dy + sin(start + pi / 3) * centerRadius,
        )
        ..close();
      final ownerIndex = _playerAtRouteSlot(slot);
      final color = ownerIndex == null
          ? BoardType.hex6.availableColors[slot].color
          : state.players[ownerIndex].color.color;
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF0F172A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    final dieOuter = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: config.center,
        width: config.cellSize * 1.65,
        height: config.cellSize * 1.65,
      ),
      Radius.circular(config.cellSize * 0.22),
    );
    canvas.drawRRect(dieOuter, Paint()..color = const Color(0xFF111827));
    final dieFace = RRect.fromRectAndRadius(
      dieOuter.outerRect.deflate(config.cellSize * 0.14),
      Radius.circular(config.cellSize * 0.16),
    );
    canvas.drawRRect(dieFace, Paint()..color = Colors.white);

    final pipRadius = config.cellSize * 0.105;
    final pipOffset = config.cellSize * 0.34;
    for (final offset in <Offset>[
      Offset(-pipOffset, -pipOffset),
      Offset(0, -pipOffset),
      Offset(pipOffset, -pipOffset),
      Offset(-pipOffset, pipOffset),
      Offset(0, pipOffset),
      Offset(pipOffset, pipOffset),
    ]) {
      canvas.drawCircle(
        config.center + offset,
        pipRadius,
        Paint()..color = Colors.black87,
      );
    }
  }

  void _drawHex6Arrow(Canvas canvas, Offset center, int slot, Color color) {
    final angle = slot * pi / 3 - pi / 2;
    final direction = Offset(cos(angle), sin(angle));
    final tangent = Offset(-sin(angle), cos(angle));
    final tip = center - direction * config.cellSize * 0.3;
    final left =
        center +
        direction * config.cellSize * 0.25 +
        tangent * config.cellSize * 0.28;
    final right =
        center +
        direction * config.cellSize * 0.25 -
        tangent * config.cellSize * 0.28;
    canvas.drawPath(
      _polygonPath([tip, left, right]),
      Paint()..color = color.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}
