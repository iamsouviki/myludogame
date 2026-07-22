import 'package:flutter/material.dart';

// ponytail: all board geometry lives here, single source of truth

enum PlayerColor {
  red,
  green,
  yellow,
  blue,
  orange,
  purple;

  Color get color => switch (this) {
        red => const Color(0xFFE53935),
        green => const Color(0xFF43A047),
        yellow => const Color(0xFFFDD835),
        blue => const Color(0xFF1E88E5),
        orange => const Color(0xFFFB8C00),
        purple => const Color(0xFF8E24AA),
      };

  Color get lightColor => switch (this) {
        red => const Color(0xFFFFCDD2),
        green => const Color(0xFFC8E6C9),
        yellow => const Color(0xFFFFF9C4),
        blue => const Color(0xFFBBDEFB),
        orange => const Color(0xFFFFE0B2),
        purple => const Color(0xFFE1BEE7),
      };

  String get label => switch (this) {
        red => 'Red',
        green => 'Green',
        yellow => 'Yellow',
        blue => 'Blue',
        orange => 'Orange',
        purple => 'Purple',
      };
}

enum PlayerType { human, ai }

enum AIDifficulty {
  easy,
  medium,
  hard;

  String get label => switch (this) {
        easy => 'Easy',
        medium => 'Medium',
        hard => 'Hard',
      };

  /// How often AI picks the optimal move (0.0 - 1.0)
  double get optimalRate => switch (this) {
        easy => 0.4,
        medium => 0.7,
        hard => 0.95,
      };
}

enum GamePhase { setup, rolling, moving, animating, finished }

enum BoardType {
  classic4, // Standard 4-player cross board
  hex6; // 6-player star/hex board

  int get maxPlayers => switch (this) {
        classic4 => 4,
        hex6 => 6,
      };

  /// Total cells on the main track
  int get trackLength => switch (this) {
        classic4 => 52,
        hex6 => 78, // 6 arms × 13 cells
      };

  /// Cells per arm/segment
  int get cellsPerArm => switch (this) {
        classic4 => 13,
        hex6 => 13,
      };

  /// Home stretch length (cells before home)
  int get homeStretchLength => switch (this) {
        classic4 => 5,
        hex6 => 5,
      };

  String get label => switch (this) {
        classic4 => 'Classic (4 Players)',
        hex6 => 'Star (6 Players)',
      };
}

/// Tokens per player — always 4
const int tokensPerPlayer = 4;

/// Position value meaning token is in base (not on board)
const int posInBase = -1;

/// Position value meaning token has reached home
const int posHome = -2;

/// Dice values
const int diceMin = 1;
const int diceMax = 6;
const int diceToEnter = 6;

/// Triple-6 rule: 3 consecutive 6s = lose turn
const int maxConsecutiveSixes = 3;
