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
    // Star 6 needs a little more radial breathing room for six triangular bases.
    cellSize = minDim / (boardType == BoardType.classic4 ? 15 : 18);
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
  List<PlayerColor> get playerColors => boardType.availableColors;

  /// Map a player's color to its physical board route slot.
  int colorPositionIndex(PlayerColor color) {
    final slot = boardType.availableColors.indexOf(color);
    return slot >= 0 ? slot : 0;
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
    // Green home-entry arrow (cell 11)
    [0, 7],
    // Green approach box (not part of the green home transition)
    [0, 6],
    // Left arm bottom row going right (cells 13-17)
    [1, 6], [2, 6], [3, 6], [4, 6], [5, 6],
    // Top arm left col going up (cells 18-23)
    [6, 5], [6, 4], [6, 3], [6, 2], [6, 1], [6, 0],
    // Yellow home-entry arrow (cell 24)
    [7, 0],
    // Yellow approach box (not part of the yellow home transition)
    [8, 0],
    // Top arm right col going down (cells 26-30)
    [8, 1], [8, 2], [8, 3], [8, 4], [8, 5],
    // Right arm top row going right (cells 31-36)
    [9, 6], [10, 6], [11, 6], [12, 6], [13, 6], [14, 6],
    // Blue home-entry arrow (cell 37)
    [14, 7],
    // Blue approach box (not part of the blue home transition)
    [14, 8],
    // Right arm bottom row going left (cells 39-43)
    [13, 8], [12, 8], [11, 8], [10, 8], [9, 8],
    // Bottom arm right col going down (cells 44-49)
    [8, 9], [8, 10], [8, 11], [8, 12], [8, 13], [8, 14],
    // Red home-entry arrow (cell 50)
    [7, 14],
    // Red approach box (not part of the red home transition)
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

  // The six-player board is a rotational grid: each arm is a 13-cell U-shaped
  // lane, with one canonical arm repeated every 60 degrees.
  double get _hex6OuterRadius => cellSize * 6.55;
  double get _hex6InnerRadius => cellSize * 0.75;

  Offset _hex6RadialPoint(
    int routeSlot,
    double distance,
    double tangentOffset,
  ) {
    final angle = routeSlot * pi / 3 - pi / 2;
    final radial = Offset(cos(angle), sin(angle));
    final tangent = Offset(-sin(angle), cos(angle));
    return center + radial * distance + tangent * tangentOffset;
  }

  Offset _hex6TrackPosition(int cellIndex) {
    final arm = (cellIndex ~/ 13) % 6;
    final cellInArm = cellIndex % 13;
    final halfCell = cellSize / 2;

    if (cellInArm < 6) {
      final distance = _hex6OuterRadius - (cellInArm + 0.5) * cellSize;
      return _hex6RadialPoint(arm, distance, -halfCell);
    }
    if (cellInArm == 6) {
      return _hex6RadialPoint(arm, _hex6InnerRadius, 0);
    }

    final distance = _hex6InnerRadius + (cellInArm - 6.5) * cellSize;
    return _hex6RadialPoint(arm, distance, halfCell);
  }

  /// Corners for a Star 6 track cell, aligned to its radial arm.
  List<Offset> hex6TrackCellCorners(int cellIndex) {
    final arm = (cellIndex ~/ 13) % 6;
    final angle = arm * pi / 3 - pi / 2;
    final radial = Offset(cos(angle), sin(angle));
    final tangent = Offset(-sin(angle), cos(angle));
    final centerPoint = _hex6TrackPosition(cellIndex);
    final half = cellSize / 2;

    return [
      centerPoint + radial * half + tangent * half,
      centerPoint - radial * half + tangent * half,
      centerPoint - radial * half - tangent * half,
      centerPoint + radial * half - tangent * half,
    ];
  }

  Offset _hex6HomeStretch(int playerIndex, int stepIntoHome) {
    final clampedStep = stepIntoHome
        .clamp(0, boardType.homeStretchLength)
        .toDouble();
    final distance =
        (boardType.homeStretchLength - clampedStep) * cellSize * 0.9;
    return _hex6RadialPoint(playerIndex, distance, 0);
  }

  List<Offset> hex6HomeCellCorners(int playerIndex, int stepIntoHome) {
    final angle = playerIndex * pi / 3 - pi / 2;
    final radial = Offset(cos(angle), sin(angle));
    final tangent = Offset(-sin(angle), cos(angle));
    final centerPoint = _hex6HomeStretch(playerIndex, stepIntoHome);
    final half = cellSize / 2;

    return [
      centerPoint + radial * half + tangent * half,
      centerPoint - radial * half + tangent * half,
      centerPoint - radial * half - tangent * half,
      centerPoint + radial * half - tangent * half,
    ];
  }

  Offset hex6BaseCenter(int routeSlot) =>
      _hex6RadialPoint(routeSlot, cellSize * 7.35, 0);

  Offset _hex6BasePosition(int routeSlot, int tokenIndex) {
    final angle = routeSlot * pi / 3 - pi / 2;
    final radial = Offset(cos(angle), sin(angle));
    final tangent = Offset(-sin(angle), cos(angle));
    final row = tokenIndex ~/ 2;
    final col = tokenIndex % 2;

    return hex6BaseCenter(routeSlot) +
        radial * ((row - 0.5) * cellSize * 0.85) +
        tangent * ((col - 0.5) * cellSize * 1.35);
  }

  /// The six-player base polygon points outward from the center.
  List<Offset> hex6BaseCorners(int routeSlot, {double scale = 1}) {
    final angle = routeSlot * pi / 3 - pi / 2;
    final radial = Offset(cos(angle), sin(angle));
    final tangent = Offset(-sin(angle), cos(angle));
    final base = hex6BaseCenter(routeSlot);
    final tip = base + radial * cellSize * 1.35 * scale;
    final nearLeft =
        base -
        radial * cellSize * 0.6 * scale -
        tangent * cellSize * 2.15 * scale;
    final nearRight =
        base -
        radial * cellSize * 0.6 * scale +
        tangent * cellSize * 2.15 * scale;
    return [tip, nearRight, nearLeft];
  }
}
