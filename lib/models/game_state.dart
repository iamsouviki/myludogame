import 'package:flutter/foundation.dart';

import '../utils/constants.dart';
import 'player.dart';
import 'dice.dart';

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
  GamePhase phase = GamePhase.rolling;
  List<int> validTokenMoves = []; // indices of tokens that can move
  int? winner; // player index of winner, null if game ongoing
  List<int> finishOrder = []; // player indices in order of finishing

  GameState({
    required this.boardType,
    required this.players,
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

  /// Absolute board position for a player's entry into home stretch
  int homeEntryPosition(int playerIndex) {
    // The cell just before home stretch begins
    final start = startPosition(playerIndex);
    return (start + boardType.trackLength - 1) % boardType.trackLength;
  }

  /// Safe spots on the board (star cells)
  Set<int> get safeSpots {
    final spots = <int>{};
    for (var i = 0; i < players.length; i++) {
      spots.add(startPosition(i)); // start cells are safe
      // Cell 8 positions after start is also safe (traditional)
      spots.add((startPosition(i) + 8) % boardType.trackLength);
    }
    return spots;
  }

  /// Convert a token's logical position to distance traveled from its start
  int distanceTraveled(int playerIndex, int tokenIndex) {
    final pos = tokenPositions[playerIndex][tokenIndex];
    if (pos == posInBase || pos == posHome) return pos;
    final start = startPosition(playerIndex);
    return (pos - start + boardType.trackLength) % boardType.trackLength;
  }

  /// Check if a token is on the home stretch
  bool isOnHomeStretch(int playerIndex, int tokenIndex) {
    final dist = distanceTraveled(playerIndex, tokenIndex);
    if (dist < 0) return false;
    return dist > boardType.trackLength - boardType.homeStretchLength - 1;
  }

  /// Check if all tokens of a player have reached home
  bool hasPlayerFinished(int playerIndex) =>
      tokenPositions[playerIndex].every((pos) => pos == posHome);

  /// Roll the dice
  int rollDice() {
    final rolled = _dice.roll();
    lastDiceRoll = rolled;

    if (rolled == diceMax) {
      consecutiveSixes++;
      if (consecutiveSixes >= maxConsecutiveSixes) {
        // Triple-6: lose turn
        consecutiveSixes = 0;
        phase = GamePhase.rolling;
        _nextTurn();
        notifyListeners();
        return rolled;
      }
    } else {
      consecutiveSixes = 0;
    }

    // Find valid moves
    validTokenMoves = _findValidMoves(currentPlayerIndex, rolled);

    if (validTokenMoves.isEmpty) {
      // No valid moves — phase stays in rolling for state display, caller/service handles delayed nextTurn
      phase = GamePhase.rolling;
    } else {
      phase = GamePhase.moving;
    }

    notifyListeners();
    return rolled;
  }

  /// Advance to next turn explicitly
  void advanceTurn() {
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

    // Calculate new position
    final dist = distanceTraveled(playerIndex, tokenIndex);
    final newDist = dist + diceValue;
    final maxDist = boardType.trackLength + boardType.homeStretchLength - 1;

    // Can't overshoot home
    return newDist <= maxDist;
  }
  bool moveTokenStep(int playerIndex, int tokenIndex) {
    final pos = tokenPositions[playerIndex][tokenIndex];
    if (pos == posInBase) {
      tokenPositions[playerIndex][tokenIndex] = startPosition(playerIndex);
      notifyListeners();
      return true;
    }

    final dist = distanceTraveled(playerIndex, tokenIndex);
    final nextDist = dist + 1;
    final homeEntry = boardType.trackLength - 1;

    if (nextDist > homeEntry) {
      final stepsIntoHome = nextDist - homeEntry;
      if (stepsIntoHome >= boardType.homeStretchLength) {
        tokenPositions[playerIndex][tokenIndex] = posHome;
        if (hasPlayerFinished(playerIndex)) {
          finishOrder.add(playerIndex);
          winner ??= playerIndex;
          if (finishOrder.length >= players.length - 1) {
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
    } else {
      final newPos = (startPosition(playerIndex) + nextDist) % boardType.trackLength;
      tokenPositions[playerIndex][tokenIndex] = newPos;
    }

    notifyListeners();
    return false;
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
    final pos = tokenPositions[playerIndex][tokenIndex];
    final diceValue = lastDiceRoll!;
    var captured = false;

    if (pos == posInBase) {
      // Enter the board
      tokenPositions[playerIndex][tokenIndex] = startPosition(playerIndex);
      captured = _checkCapture(playerIndex, tokenIndex);
    } else {
      final dist = distanceTraveled(playerIndex, tokenIndex);
      final newDist = dist + diceValue;
      final homeEntry = boardType.trackLength - 1;

      if (newDist > homeEntry) {
        // Moving into home stretch or reaching home
        final stepsIntoHome = newDist - homeEntry;
        if (stepsIntoHome >= boardType.homeStretchLength) {
          // Reached home!
          tokenPositions[playerIndex][tokenIndex] = posHome;
          if (hasPlayerFinished(playerIndex)) {
            finishOrder.add(playerIndex);
            winner ??= playerIndex;
            if (finishOrder.length >= players.length - 1) {
              // Only one player left, game over
              for (var i = 0; i < players.length; i++) {
                if (!finishOrder.contains(i)) finishOrder.add(i);
              }
              phase = GamePhase.finished;
              notifyListeners();
              return captured;
            }
          }
        } else {
          // On home stretch — encode as trackLength + stepsIntoHome
          // Home stretch positions are unique per player, can't be captured
          tokenPositions[playerIndex][tokenIndex] =
              boardType.trackLength + stepsIntoHome;
        }
      } else {
        // Normal move on main track
        final newPos =
            (startPosition(playerIndex) + newDist) % boardType.trackLength;
        tokenPositions[playerIndex][tokenIndex] = newPos;
        captured = _checkCapture(playerIndex, tokenIndex);
      }
    }

    // Next turn logic
    if (phase != GamePhase.finished) {
      if (lastDiceRoll == diceMax || captured) {
        // Rolled 6 or captured: bonus turn
        phase = GamePhase.rolling;
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

    var captured = false;
    for (var p = 0; p < players.length; p++) {
      if (p == playerIndex) continue;
      for (var t = 0; t < tokensPerPlayer; t++) {
        if (tokenPositions[p][t] == pos) {
          tokenPositions[p][t] = posInBase; // send home
          captured = true;
        }
      }
    }
    return captured;
  }

  void _nextTurn() {
    // Skip finished players
    var next = (currentPlayerIndex + 1) % players.length;
    var attempts = 0;
    while (hasPlayerFinished(next) && attempts < players.length) {
      next = (next + 1) % players.length;
      attempts++;
    }
    currentPlayerIndex = next;
    consecutiveSixes = 0;
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
    phase = GamePhase.values[json['phase'] as int];
    validTokenMoves = List<int>.from(json['validTokenMoves'] as List);
    winner = json['winner'] as int?;
    finishOrder = List<int>.from(json['finishOrder'] as List);
    notifyListeners();
  }
  /// Allow external callers (GameService) to trigger a repaint
  void notifyChange() => notifyListeners();
}
