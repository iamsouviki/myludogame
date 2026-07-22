import 'dart:math';
import 'dart:ui';

import '../utils/constants.dart';

// ponytail: board geometry math, single source of truth

/// Provides pixel coordinates for board cells given a canvas size.
class BoardConfig {
  final BoardType boardType;
  final Size canvasSize;

  late final double cellSize;
  late final Offset center;

  BoardConfig({required this.boardType, required this.canvasSize}) {
    center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final minDim = canvasSize.shortestSide;
    cellSize = minDim / (boardType == BoardType.classic4 ? 15 : 17);
  }

  /// Get the pixel position of a main-track cell
  Offset trackCellPosition(int cellIndex) {
    if (boardType == BoardType.classic4) {
      return _classic4TrackPosition(cellIndex);
    } else {
      return _hex6TrackPosition(cellIndex);
    }
  }

  /// Get pixel position for a home-stretch cell
  Offset homeStretchPosition(int playerIndex, int stepIntoHome) {
    if (boardType == BoardType.classic4) {
      return _classic4HomeStretch(playerIndex, stepIntoHome);
    } else {
      return _hex6HomeStretch(playerIndex, stepIntoHome);
    }
  }

  /// Get pixel position for a token in base
  Offset basePosition(int playerIndex, int tokenIndex) {
    if (boardType == BoardType.classic4) {
      return _classic4BasePosition(playerIndex, tokenIndex);
    } else {
      return _hex6BasePosition(playerIndex, tokenIndex);
    }
  }

  /// Get the home (center) position
  Offset get homePosition => center;

  /// Colors for each player position
  List<PlayerColor> get playerColors {
    if (boardType == BoardType.classic4) {
      return [
        PlayerColor.red,
        PlayerColor.green,
        PlayerColor.yellow,
        PlayerColor.blue
      ];
    } else {
      return PlayerColor.values;
    }
  }

  Offset _gridToPixel(double gridX, double gridY) {
    final boardOrigin = Offset(
      center.dx - 7.5 * cellSize,
      center.dy - 7.5 * cellSize,
    );
    return Offset(
      boardOrigin.dx + gridX * cellSize,
      boardOrigin.dy + gridY * cellSize,
    );
  }

  // ─── Classic 4-Player Board Layout ───
  // Player 0: Red (Bottom-Left: base gridX 0..5, gridY 9..14, Home arm goes Up col 7)
  // Player 1: Green (Top-Left: base gridX 0..5, gridY 0..5, Home arm goes Right row 7)
  // Player 2: Yellow (Top-Right: base gridX 9..14, gridY 0..5, Home arm goes Down col 7)
  // Player 3: Blue (Bottom-Right: base gridX 9..14, gridY 9..14, Home arm goes Left row 7)

  static const List<List<int>> _classic4Track = [
    // Red Start & Track (cells 0-4): col 6 going up
    [6, 13], [6, 12], [6, 11], [6, 10], [6, 9],
    // Left arm top row going left (cells 5-10)
    [5, 8], [4, 8], [3, 8], [2, 8], [1, 8], [0, 8],
    // Turn (cell 11)
    [0, 7],
    // Green Start (cell 12): [0, 6]
    [0, 6],
    // Left arm bottom row going right (cells 13-17)
    [1, 6], [2, 6], [3, 6], [4, 6], [5, 6],
    // Top arm left col going up (cells 18-23)
    [6, 5], [6, 4], [6, 3], [6, 2], [6, 1], [6, 0],
    // Turn (cell 24)
    [7, 0],
    // Yellow Start (cell 25): [8, 0]
    [8, 0],
    // Top arm right col going down (cells 26-30)
    [8, 1], [8, 2], [8, 3], [8, 4], [8, 5],
    // Right arm top row going right (cells 31-36)
    [9, 6], [10, 6], [11, 6], [12, 6], [13, 6], [14, 6],
    // Turn (cell 37)
    [14, 7],
    // Blue Start (cell 38): [14, 8]
    [14, 8],
    // Right arm bottom row going left (cells 39-43)
    [13, 8], [12, 8], [11, 8], [10, 8], [9, 8],
    // Bottom arm right col going down (cells 44-49)
    [8, 9], [8, 10], [8, 11], [8, 12], [8, 13], [8, 14],
    // Turn (cell 50)
    [7, 14],
    // Red pre-entry cell (cell 51)
    [6, 14],
  ];

  Offset _classic4TrackPosition(int cellIndex) {
    final cell = _classic4Track[cellIndex % 52];
    return _gridToPixel(cell[0] + 0.5, cell[1] + 0.5);
  }

  Offset _classic4HomeStretch(int playerIndex, int stepIntoHome) {
    final s = stepIntoHome + 1; // 1-based (1..5)
    switch (playerIndex) {
      case 0: // Red: Col 7 going Up from row 13
        return _gridToPixel(7.5, 14.5 - s.toDouble());
      case 1: // Green: Row 7 going Right from col 1
        return _gridToPixel(s.toDouble() + 0.5, 7.5);
      case 2: // Yellow: Col 7 going Down from row 1
        return _gridToPixel(7.5, s.toDouble() + 0.5);
      case 3: // Blue: Row 7 going Left from col 13
        return _gridToPixel(14.5 - s.toDouble(), 7.5);
      default:
        return center;
    }
  }

  Offset _classic4BasePosition(int playerIndex, int tokenIndex) {
    // Each 6x6 base has an inner white rounded box from offset 0.8 to 5.2 (width 4.4 cellSize)
    // Centers of the 4 colored circles inside the base:
    // Left circles: baseGridX + 2.05, Right circles: baseGridX + 3.95
    // Top circles: baseGridY + 2.05, Bottom circles: baseGridY + 3.95
    final row = tokenIndex ~/ 2;
    final col = tokenIndex % 2;

    double baseGridX;
    double baseGridY;

    switch (playerIndex) {
      case 0: // Red: Bottom-Left (gridX 0, gridY 9)
        baseGridX = 0;
        baseGridY = 9;
      case 1: // Green: Top-Left (gridX 0, gridY 0)
        baseGridX = 0;
        baseGridY = 0;
      case 2: // Yellow: Top-Right (gridX 9, gridY 0)
        baseGridX = 9;
        baseGridY = 0;
      case 3: // Blue: Bottom-Right (gridX 9, gridY 9)
        baseGridX = 9;
        baseGridY = 9;
      default:
        baseGridX = 0;
        baseGridY = 0;
    }

    final offsetX = (col == 0 ? 2.05 : 3.95);
    final offsetY = (row == 0 ? 2.05 : 3.95);

    return _gridToPixel(baseGridX + offsetX, baseGridY + offsetY);
  }

  // ─── 6-Player Hex/Star Board ───

  Offset _hex6TrackPosition(int cellIndex) {
    final arm = cellIndex ~/ 13;
    final cellInArm = cellIndex % 13;
    final angle = arm * pi / 3 - pi / 2;

    final radius = canvasSize.shortestSide * 0.42;

    if (cellInArm <= 5) {
      final t = (cellInArm + 1) / 7.0;
      final perpAngle = angle + pi / 2;
      final offset = cellSize * 0.7;
      return Offset(
        center.dx + cos(angle) * radius * t - cos(perpAngle) * offset,
        center.dy + sin(angle) * radius * t - sin(perpAngle) * offset,
      );
    } else if (cellInArm == 6) {
      final t = 1.0;
      return Offset(
        center.dx + cos(angle) * radius * t,
        center.dy + sin(angle) * radius * t,
      );
    } else {
      final nextAngle = ((arm + 1) % 6) * pi / 3 - pi / 2;
      final backCell = cellInArm - 7;
      final t = 1.0 - (backCell + 1) / 7.0;
      final perpAngle = nextAngle - pi / 2;
      final offset = cellSize * 0.7;
      return Offset(
        center.dx + cos(nextAngle) * radius * t - cos(perpAngle) * offset,
        center.dy + sin(nextAngle) * radius * t - sin(perpAngle) * offset,
      );
    }
  }

  Offset _hex6HomeStretch(int playerIndex, int stepIntoHome) {
    final angle = playerIndex * pi / 3 - pi / 2;
    final radius = canvasSize.shortestSide * 0.42;
    final t = (stepIntoHome + 1) / (boardType.homeStretchLength + 1);
    return Offset(
      center.dx + cos(angle) * radius * t * 0.6,
      center.dy + sin(angle) * radius * t * 0.6,
    );
  }

  Offset _hex6BasePosition(int playerIndex, int tokenIndex) {
    final angle = playerIndex * pi / 3 - pi / 2 + pi / 6;
    final radius = canvasSize.shortestSide * 0.35;
    final row = tokenIndex ~/ 2;
    final col = tokenIndex % 2;
    final perpAngle = angle + pi / 2;

    return Offset(
      center.dx +
          cos(angle) * radius +
          cos(perpAngle) * (col - 0.5) * cellSize * 1.5 +
          cos(angle) * (row - 0.5) * cellSize * 1.5,
      center.dy +
          sin(angle) * radius +
          sin(perpAngle) * (col - 0.5) * cellSize * 1.5 +
          sin(angle) * (row - 0.5) * cellSize * 1.5,
    );
  }
}
