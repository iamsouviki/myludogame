import 'dart:math';

import 'package:flutter/foundation.dart';

import '../utils/constants.dart';
import 'player.dart';
import 'dice.dart';

// Ludo King standard rules

class GameState extends ChangeNotifier {
  final BoardType boardType;
  final List<Player> players;
  final Dice _dice;

  // Token positions: tokenPositions[playerIndex][tokenIndex]
  // Values: posInBase (-1), posHome (-2), or 0..trackLength-1 (board position)
  late List<List<int>> tokenPositions;

  int currentPlayerIndex = 0;
  int? lastDiceRoll;
  int consecutiveSixes = 0;
  bool getsExtraRoll = false; // Ludo King: rolling 6 or capturing = one extra turn
  GamePhase phase = GamePhase.rolling;
  List<int> validTokenMoves = []; // indices of tokens that can move
  int? winner; // player index of winner, null if game ongoing
  List<int> finishOrder = []; // player indices in order of finishing

  GameState({
    required this.boardType,
    required this.players,
    bool enableJodi = true, // kept for API compat, ignored
    Dice? dice,
  }) : _dice = dice ?? Dice() {
    assert(players.length >= 2 && players.length <= boardType.maxPlayers);
    tokenPositions = List.generate(
      players.length,
      (_) => List.filled(tokensPerPlayer, posInBase),
    );
  }

  Player get currentPlayer => players[currentPlayerIndex];
  bool get isCurrentPlayerAI => currentPlayer.isAI;
  bool get isGameOver => phase == GamePhase.finished;

  /// Absolute board position for a player's start cell
  int startPosition(int playerIndex) =>
      playerIndex * boardType.cellsPerArm;

  /// Absolute board position for a player's entry into home stretch (Tile 50 for Red)
  int homeEntryPosition(int playerIndex) {
    final start = startPosition(playerIndex);
    return (start + boardType.trackLength - 2) % boardType.trackLength;
  }

  /// Safe spots on the board (star cells)
  Set<int> get safeSpots {
    final spots = <int>{};
    // Standard 4 start positions and 4 star positions on the track
    for (var i = 0; i < boardType.maxPlayers; i++) {
      final start = i * boardType.cellsPerArm;
      spots.add(start); // all starting cells on board are safe
      spots.add((start + 8) % boardType.trackLength); // star cells 8 steps after start
    }
    return spots;
  }

  /// Convert a token's logical position to distance traveled from its start
  int distanceTraveled(int playerIndex, int tokenIndex) {
    final pos = tokenPositions[playerIndex][tokenIndex];
    if (pos == posInBase || pos == posHome) return pos;
    if (pos >= boardType.trackLength) {
      // Token is on home stretch (encoded as trackLength + stepsIntoHome)
      final stepsIntoHome = pos - boardType.trackLength;
      return (boardType.trackLength - 2) + stepsIntoHome + 1;
    }
    final start = startPosition(playerIndex);
    return (pos - start + boardType.trackLength) % boardType.trackLength;
  }

  /// Check if a token is on the home stretch
  bool isOnHomeStretch(int playerIndex, int tokenIndex) {
    final pos = tokenPositions[playerIndex][tokenIndex];
    return pos >= boardType.trackLength;
  }

  /// Check if all tokens of a player have reached home
  bool hasPlayerFinished(int playerIndex) =>
      tokenPositions[playerIndex].every((pos) => pos == posHome);

  /// Roll the dice (Ludo King rules)
  int rollDice() {
    final rolled = _dice.roll();
    lastDiceRoll = rolled;
    getsExtraRoll = false; // reset before evaluating

    if (rolled == diceMax) {
      consecutiveSixes++;
      if (consecutiveSixes >= maxConsecutiveSixes) {
        // Triple-6: lose turn entirely
        consecutiveSixes = 0;
        getsExtraRoll = false;
        phase = GamePhase.rolling;
        _nextTurn();
        notifyListeners();
        return rolled;
      }
      // Rolling a 6 grants an extra turn (set after move in moveToken)
      getsExtraRoll = true;
    } else {
      consecutiveSixes = 0;
    }

    // Find valid moves
    validTokenMoves = _findValidMoves(currentPlayerIndex, rolled);

    if (validTokenMoves.isEmpty) {
      // No valid moves
      phase = GamePhase.rolling;
    } else {
      phase = GamePhase.moving;
    }

    notifyListeners();
    return rolled;
  }

  /// Advance to next turn explicitly (no extra roll)
  void advanceTurn() {
    getsExtraRoll = false;
    _nextTurn();
    phase = GamePhase.rolling;
    notifyListeners();
  }

  /// Get valid token indices that can move with the given dice roll
  List<int> _findValidMoves(int playerIndex, int diceValue) {
    final moves = <int>[];
    for (var t = 0; t < tokensPerPlayer; t++) {
      if (_canMoveToken(playerIndex, t, diceValue)) {
        moves.add(t);
      }
    }
    return moves;
  }

  bool _canMoveToken(int playerIndex, int tokenIndex, int diceValue) {
    final pos = tokenPositions[playerIndex][tokenIndex];

    if (pos == posHome) return false; // already home

    if (pos == posInBase) {
      return diceValue == diceToEnter; // need 6 to enter
    }

    // Ludo King: simple path check — no Jodi/Star blockades
    var currPos = pos;
    for (var s = 1; s <= diceValue; s++) {
      if (currPos == posHome) return false;

      int nextPos;
      if (currPos >= boardType.trackLength) {
        final stepsIntoHome = (currPos - boardType.trackLength) + 1;
        if (stepsIntoHome == boardType.homeStretchLength) {
          nextPos = posHome;
        } else if (stepsIntoHome > boardType.homeStretchLength) {
          return false; // overshooting home
        } else {
          nextPos = boardType.trackLength + stepsIntoHome;
        }
      } else if (currPos == homeEntryPosition(playerIndex)) {
        // Turn into home stretch
        nextPos = boardType.trackLength;
      } else {
        // Continue along shared track
        nextPos = (currPos + 1) % boardType.trackLength;
      }

      currPos = nextPos;
    }

    return true;
  }

  bool moveTokenStep(int playerIndex, int tokenIndex) {
    final pos = tokenPositions[playerIndex][tokenIndex];
    if (pos == posInBase) {
      tokenPositions[playerIndex][tokenIndex] = startPosition(playerIndex);
      notifyListeners();
      return true;
    }

    if (pos >= boardType.trackLength) {
      final stepsIntoHome = (pos - boardType.trackLength) + 1;
      if (stepsIntoHome >= boardType.homeStretchLength) {
        tokenPositions[playerIndex][tokenIndex] = posHome;
        getsExtraRoll = true; // Reached home cell — extra turn
        if (hasPlayerFinished(playerIndex) && !finishOrder.contains(playerIndex)) {
          finishOrder.add(playerIndex);
          winner ??= playerIndex;
          // Game ends when all but 1 player have finished
          if (finishOrder.length >= players.length - 1) {
            getsExtraRoll = false;
            // Add the last remaining player to the end
            for (var i = 0; i < players.length; i++) {
              if (!finishOrder.contains(i)) finishOrder.add(i);
            }
            phase = GamePhase.finished;
          }
        }
      } else {
        tokenPositions[playerIndex][tokenIndex] =
            boardType.trackLength + stepsIntoHome;
      }
    } else if (pos == homeEntryPosition(playerIndex)) {
      tokenPositions[playerIndex][tokenIndex] = boardType.trackLength;
    } else {
      tokenPositions[playerIndex][tokenIndex] =
          (pos + 1) % boardType.trackLength;
    }

    notifyListeners();
    return false;
  }

  /// Move a token 1 step backwards along its track toward its base
  void reverseTokenStep(int playerIndex, int tokenIndex) {
    final pos = tokenPositions[playerIndex][tokenIndex];
    if (pos == posInBase) return;

    if (pos == startPosition(playerIndex)) {
      tokenPositions[playerIndex][tokenIndex] = posInBase;
    } else if (pos >= boardType.trackLength) {
      final stepsIntoHome = pos - boardType.trackLength;
      if (stepsIntoHome == 0) {
        tokenPositions[playerIndex][tokenIndex] = homeEntryPosition(playerIndex);
      } else {
        tokenPositions[playerIndex][tokenIndex] = pos - 1;
      }
    } else {
      tokenPositions[playerIndex][tokenIndex] = (pos - 1 + boardType.trackLength) % boardType.trackLength;
    }

    notifyListeners();
  }

  /// Returns list of (playerIndex, tokenIndex) opponents at current pos if captured
  List<Point<int>> findCapturedOpponents(int playerIndex, int tokenIndex) {
    final pos = tokenPositions[playerIndex][tokenIndex];
    if (pos < 0 || pos >= boardType.trackLength) return [];
    if (safeSpots.contains(pos)) return [];

    final currentTeam = players[playerIndex].teamId;
    final capturedList = <Point<int>>[];

    for (var p = 0; p < players.length; p++) {
      if (p == playerIndex) continue;
      if (currentTeam != null && players[p].teamId == currentTeam) continue;
      for (var t = 0; t < tokensPerPlayer; t++) {
        if (tokenPositions[p][t] == pos) {
          capturedList.add(Point(p, t));
        }
      }
    }
    return capturedList;
  }

  /// Perform final capture check when token lands on final cell
  bool checkFinalCapture(int playerIndex, int tokenIndex) {
    return _checkCapture(playerIndex, tokenIndex);
  }

  /// Move a token. Returns true if a capture occurred.
  bool moveToken(int tokenIndex) {
    if (phase != GamePhase.moving) return false;
    if (!validTokenMoves.contains(tokenIndex)) return false;

    final playerIndex = currentPlayerIndex;
    final diceValue = lastDiceRoll!;

    for (var i = 0; i < diceValue; i++) {
      moveTokenStep(playerIndex, tokenIndex);
    }

    final captured = _checkCapture(playerIndex, tokenIndex);

    if (phase != GamePhase.finished) {
      // Ludo King: extra turn if rolled 6 OR captured (getsExtraRoll already
      // set by rollDice for 6; _checkCapture sets it for capture)
      if (getsExtraRoll) {
        // Stay on same player, let them roll again
        phase = GamePhase.rolling;
        lastDiceRoll = null;
        validTokenMoves = [];
      } else {
        _nextTurn();
        phase = GamePhase.rolling;
      }
    }

    notifyListeners();
    return captured;
  }

  /// Check and execute capture at current token position
  bool _checkCapture(int playerIndex, int tokenIndex) {
    final pos = tokenPositions[playerIndex][tokenIndex];
    if (pos < 0 || pos >= boardType.trackLength) return false;
    if (safeSpots.contains(pos)) return false; // safe spot, no capture

    final currentTeam = players[playerIndex].teamId;

    var captured = false;
    for (var p = 0; p < players.length; p++) {
      if (p == playerIndex) continue;
      if (currentTeam != null && players[p].teamId == currentTeam) continue; // teammates don't capture each other
      for (var t = 0; t < tokensPerPlayer; t++) {
        if (tokenPositions[p][t] == pos) {
          tokenPositions[p][t] = posInBase; // send home
          captured = true;
        }
      }
    }
    if (captured) {
      getsExtraRoll = true; // Ludo King: capture grants an extra turn
    }
    return captured;
  }

  void _nextTurn() {
    var next = (currentPlayerIndex + 1) % players.length;
    var attempts = 0;
    while (hasPlayerFinished(next) && attempts < players.length) {
      next = (next + 1) % players.length;
      attempts++;
    }
    currentPlayerIndex = next;
    consecutiveSixes = 0;
    getsExtraRoll = false;
    lastDiceRoll = null;
    validTokenMoves = [];
  }

  /// Reset game
  void reset() {
    tokenPositions = List.generate(
      players.length,
      (_) => List.filled(tokensPerPlayer, posInBase),
    );
    currentPlayerIndex = 0;
    lastDiceRoll = null;
    consecutiveSixes = 0;
    getsExtraRoll = false;
    phase = GamePhase.rolling;
    validTokenMoves = [];
    winner = null;
    finishOrder = [];
    notifyListeners();
  }

  /// Serialize for online sync
  Map<String, dynamic> toJson() => {
        'boardType': boardType.index,
        'players': players.map((p) => p.toJson()).toList(),
        'tokenPositions':
            tokenPositions.map((t) => t.toList()).toList(),
        'currentPlayerIndex': currentPlayerIndex,
        'lastDiceRoll': lastDiceRoll,
        'consecutiveSixes': consecutiveSixes,
        'getsExtraRoll': getsExtraRoll,
        'phase': phase.index,
        'validTokenMoves': validTokenMoves,
        'winner': winner,
        'finishOrder': finishOrder,
      };

  /// Restore from online sync (mutates in place)
  void loadFromJson(Map<String, dynamic> json) {
    tokenPositions = (json['tokenPositions'] as List)
        .map((t) => List<int>.from(t as List))
        .toList();
    currentPlayerIndex = json['currentPlayerIndex'] as int;
    lastDiceRoll = json['lastDiceRoll'] as int?;
    consecutiveSixes = json['consecutiveSixes'] as int;
    getsExtraRoll = (json['getsExtraRoll'] as bool?) ?? false;
    phase = GamePhase.values[json['phase'] as int];
    validTokenMoves = List<int>.from(json['validTokenMoves'] as List);
    winner = json['winner'] as int?;
    finishOrder = List<int>.from(json['finishOrder'] as List);
    notifyListeners();
  }
  /// Allow external callers (GameService) to trigger a repaint
  void notifyChange() => notifyListeners();
}
