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

  // ─── 6-Player Hex/Star Board (Exact Reference Geometry) ───
  // Center is a regular flat-topped hexagon with side length = 3 * cellSize.
  // Radius from center to each hexagon vertex R = 3 * cellSize.
  // Inradius from center to each edge midpoint r = 3 * cellSize * cos(30 deg) = 3 * sqrt(3)/2 * cellSize.
  // Attached to each of the 6 edges of this hexagon is a straight 3x6 grid of SQUARE cells (3 columns x 6 rows).
  // Between the outer straight sides of adjacent arms are equilateral triangular base pods.
  // Because the center hexagon's 6 edges are of length 3 * cellSize and angle 120 deg, adjacent arms radiate at 60 deg with zero gap and zero overlap.

  double get _hex6Inradius => 3.0 * cellSize * (sqrt(3) / 2.0); // distance from center to edge of center hexagon

  Offset hex6ArmGridCellPosition(int routeSlot, int row, int column) {
    // Reference orientation:
    // Slot 0 (Blue) arm goes down-right (pi/3)
    // Slot 1 (Yellow) arm goes down-left (2*pi/3)
    // Slot 2 (Purple) arm goes left (pi)
    // Slot 3 (Red) arm goes up-left (4*pi/3)
    // Slot 4 (Green) arm goes up-right (5*pi/3)
    // Slot 5 (Orange) arm goes right (0)
    final armAngle = routeSlot * pi / 3 + pi / 3;
    final radial = Offset(cos(armAngle), sin(armAngle));
    final tangent = Offset(-sin(armAngle), cos(armAngle));

    // Distance from center along arm axis:
    // Inner edge of arm touches center hexagon at _hex6Inradius.
    // Row 5 is innermost (distance = _hex6Inradius + 0.5 * cellSize),
    // Row 0 is outermost (distance = _hex6Inradius + 5.5 * cellSize).
    final d = _hex6Inradius + (5.5 - row) * cellSize;
    // Tangent offset across the 3 columns (column 0 = left (-cellSize), 1 = center (0), 2 = right (+cellSize)):
    final t = (column - 1) * cellSize;

    return center + radial * d + tangent * t;
  }

  List<Offset> hex6ArmGridCellCorners(int routeSlot, int row, int column) {
    final centerPoint = hex6ArmGridCellPosition(routeSlot, row, column);
    final armAngle = routeSlot * pi / 3 + pi / 3;
    final radial = Offset(cos(armAngle), sin(armAngle));
    final tangent = Offset(-sin(armAngle), cos(armAngle));
    final half = cellSize / 2.0;

    return [
      centerPoint + radial * half - tangent * half,
      centerPoint + radial * half + tangent * half,
      centerPoint - radial * half + tangent * half,
      centerPoint - radial * half - tangent * half,
    ];
  }

  Offset _hex6TrackPosition(int cellIndex) {
    final arm = (cellIndex ~/ 13) % 6;
    final cellInArm = cellIndex % 13;
    final column = switch (cellInArm) {
      0 => 1,
      1 => 2,
      2 => 2,
      3 => 2,
      4 => 2,
      5 => 2,
      6 => 2,
      7 => 0,
      8 => 0,
      9 => 0,
      10 => 0,
      11 => 0,
      12 => 0,
      _ => 0,
    };
    final row = switch (cellInArm) {
      0 => 0,
      1 => 0,
      2 => 1,
      3 => 2,
      4 => 3,
      5 => 4,
      6 => 5,
      7 => 5,
      8 => 4,
      9 => 3,
      10 => 2,
      11 => 1,
      12 => 0,
      _ => 0,
    };
    return hex6ArmGridCellPosition(arm, row, column);
  }

  /// Corners for a Star 6 track cell (exact square cell).
  List<Offset> hex6TrackCellCorners(int cellIndex) {
    final arm = (cellIndex ~/ 13) % 6;
    final cellInArm = cellIndex % 13;
    final column = switch (cellInArm) {
      0 => 1,
      1 => 2,
      2 => 2,
      3 => 2,
      4 => 2,
      5 => 2,
      6 => 2,
      7 => 0,
      8 => 0,
      9 => 0,
      10 => 0,
      11 => 0,
      12 => 0,
      _ => 0,
    };
    final row = switch (cellInArm) {
      0 => 0,
      1 => 0,
      2 => 1,
      3 => 2,
      4 => 3,
      5 => 4,
      6 => 5,
      7 => 5,
      8 => 4,
      9 => 3,
      10 => 2,
      11 => 1,
      12 => 0,
      _ => 0,
    };
    return hex6ArmGridCellCorners(arm, row, column);
  }

  Offset _hex6HomeStretch(int playerIndex, int stepIntoHome) {
    final clampedStep = stepIntoHome
        .clamp(0, boardType.homeStretchLength)
        .toDouble();
    if (clampedStep >= boardType.homeStretchLength) return center;
    final row = clampedStep.toInt() + 1;
    return hex6ArmGridCellPosition(playerIndex, row, 1);
  }

  List<Offset> hex6HomeCellCorners(int playerIndex, int stepIntoHome) {
    final clampedStep = stepIntoHome
        .clamp(0, boardType.homeStretchLength)
        .toInt();
    final row = clampedStep + 1;
    return hex6ArmGridCellCorners(playerIndex, row, 1);
  }

  Offset hex6BaseCenter(int routeSlot) {
    // Base 0 (Blue) is between Arm 5 (Orange) and Arm 0 (Blue) -> angle = -pi/6 + pi/3 = pi/6 ?
    // In our armAngle = routeSlot * pi / 3 + pi / 3:
    // Arm 0 (Blue) is at pi/3 (down-right).
    // Arm 1 (Yellow) is at 2*pi/3 (down-left).
    // The base pod for Slot 0 (Blue) sits between Arm 0 (Blue, pi/3) and Arm 1 (Yellow, 2*pi/3), which is at bottom angle = pi/2!
    final angle = routeSlot * pi / 3 + pi / 2;
    return center + Offset(cos(angle), sin(angle)) * (_hex6Inradius + 3.6 * cellSize);
  }

  Offset _hex6BasePosition(int routeSlot, int tokenIndex) {
    final angle = routeSlot * pi / 3 + pi / 2;
    final radial = Offset(cos(angle), sin(angle));
    final tangent = Offset(-sin(angle), cos(angle));
    final row = tokenIndex ~/ 2;
    final col = tokenIndex % 2;

    return hex6BaseCenter(routeSlot) +
        radial * ((row - 0.5) * cellSize * 0.95) +
        tangent * ((col - 0.5) * cellSize * 1.35);
  }

  /// The six-player base polygon is an equilateral triangle fitting between adjacent straight arms.
  List<Offset> hex6BaseCorners(int routeSlot, {double scale = 1}) {
    // Base routeSlot is between Arm(routeSlot) and Arm((routeSlot + 1) % 6)
    final leftArm = routeSlot;
    final rightArm = (routeSlot + 1) % 6;

    // Left Arm outer right corner (Row 0 Column 2 outer-right vertex)
    final leftCorners = hex6ArmGridCellCorners(leftArm, 0, 2);
    final leftOuter = leftCorners[1]; // outer-right

    // Right Arm outer left corner (Row 0 Column 0 outer-left vertex)
    final rightCorners = hex6ArmGridCellCorners(rightArm, 0, 0);
    final rightOuter = rightCorners[0]; // outer-left

    // Hexagon vertex between Left Arm Row 5 Col 2 and Right Arm Row 5 Col 0
    final innerAngle = routeSlot * pi / 3 + pi / 2;
    final innerTip = center + Offset(cos(innerAngle), sin(innerAngle)) * (3.0 * cellSize);

    final base = hex6BaseCenter(routeSlot);
    if (scale != 1.0) {
      return [
        base + (innerTip - base) * scale,
        base + (leftOuter - base) * scale,
        base + (rightOuter - base) * scale,
      ];
    }
    return [innerTip, leftOuter, rightOuter];
  }

  /// White inset triangle that contains the four pawn sockets in each room.
  List<Offset> hex6BaseInnerCorners(int routeSlot) {
    final angle = routeSlot * pi / 3 + pi / 2;
    final radial = Offset(cos(angle), sin(angle));
    final tangent = Offset(-sin(angle), cos(angle));
    final base = hex6BaseCenter(routeSlot);
    final tip = base - radial * cellSize * 1.6;
    final farLeft = base + radial * cellSize * 0.8 - tangent * cellSize * 1.45;
    final farRight = base + radial * cellSize * 0.8 + tangent * cellSize * 1.45;
    return [tip, farRight, farLeft];
  }
}
