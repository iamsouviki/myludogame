import 'package:flutter/foundation.dart';

import '../utils/constants.dart';
import 'player.dart';
import 'dice.dart';

// ponytail: West Bengal regional rules (Viti capture requirement, Jodi blockades, extra roll queue)

class GameState extends ChangeNotifier {
  final BoardType boardType;
  final List<Player> players;
  final bool enableJodi;
  final Dice _dice;

  // Token positions: tokenPositions[playerIndex][tokenIndex]
  // Values: posInBase (-1), posHome (-2), or 0..trackLength-1 (board position)
  late List<List<int>> tokenPositions;
  late List<bool> hasCapturedOpponent;

  int currentPlayerIndex = 0;
  int? lastDiceRoll;
  int consecutiveSixes = 0;
  int pendingExtraRolls = 0;
  GamePhase phase = GamePhase.rolling;
  List<int> validTokenMoves = []; // indices of tokens that can move
  int? winner; // player index of winner, null if game ongoing
  List<int> finishOrder = []; // player indices in order of finishing

  GameState({
    required this.boardType,
    required this.players,
    this.enableJodi = true,
    Dice? dice,
  }) : _dice = dice ?? Dice() {
    assert(players.length >= 2 && players.length <= boardType.maxPlayers);
    tokenPositions = List.generate(
      players.length,
      (_) => List.filled(tokensPerPlayer, posInBase),
    );
    hasCapturedOpponent = List.filled(players.length, false);
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

  /// Roll the dice
  int rollDice() {
    final rolled = _dice.roll();
    lastDiceRoll = rolled;

    if (rolled == diceMax) {
      consecutiveSixes++;
      if (consecutiveSixes >= maxConsecutiveSixes) {
        // Triple-6: cancel roll, clear pending extra rolls, lose turn
        consecutiveSixes = 0;
        pendingExtraRolls = 0;
        phase = GamePhase.rolling;
        _nextTurn();
        notifyListeners();
        return rolled;
      }
      pendingExtraRolls++;
    } else {
      consecutiveSixes = 0;
    }

    // Find valid moves
    validTokenMoves = _findValidMoves(currentPlayerIndex, rolled);

    if (validTokenMoves.isEmpty) {
      // No valid moves — if extra rolls pending, consume one; else prepare to pass turn
      phase = GamePhase.rolling;
    } else {
      phase = GamePhase.moving;
    }

    notifyListeners();
    return rolled;
  }

  /// Advance to next turn explicitly
  void advanceTurn() {
    pendingExtraRolls = 0;
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
      } else if (currPos == homeEntryPosition(playerIndex) &&
          hasCapturedOpponent[playerIndex]) {
        // Mandatory capture rule satisfied: turn into home stretch
        nextPos = boardType.trackLength;
      } else {
        // Bypass home entry or continue along shared track
        nextPos = (currPos + 1) % boardType.trackLength;
      }

      // Jodi Blockade Check: cannot pass through or land on opponent Jodi on non-safe tiles (if enableJodi is true)
      if (enableJodi &&
          nextPos >= 0 &&
          nextPos < boardType.trackLength &&
          !safeSpots.contains(nextPos)) {
        final currentTeam = players[playerIndex].teamId;
        for (var p = 0; p < players.length; p++) {
          if (p == playerIndex) continue;
          if (currentTeam != null && players[p].teamId == currentTeam) continue; // teammates don't block each other
          var count = 0;
          for (var t = 0; t < tokensPerPlayer; t++) {
            if (tokenPositions[p][t] == nextPos) count++;
          }
          if (count >= 2) {
            return false; // Path or target blocked by opponent Jodi
          }
        }
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
        if (hasPlayerFinished(playerIndex)) {
          finishOrder.add(playerIndex);
          winner ??= playerIndex;
          pendingExtraRolls = 0; // Win rule: extra rolls discarded on final home entry
          if (finishOrder.length >= players.length - 1) {
            for (var i = 0; i < players.length; i++) {
              if (!finishOrder.contains(i)) finishOrder.add(i);
            }
            phase = GamePhase.finished;
          }
        } else {
          pendingExtraRolls++; // Reaching home yields an extra roll
        }
      } else {
        tokenPositions[playerIndex][tokenIndex] =
            boardType.trackLength + stepsIntoHome;
      }
    } else if (pos == homeEntryPosition(playerIndex) &&
        hasCapturedOpponent[playerIndex]) {
      tokenPositions[playerIndex][tokenIndex] = boardType.trackLength;
    } else {
      tokenPositions[playerIndex][tokenIndex] =
          (pos + 1) % boardType.trackLength;
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
    final diceValue = lastDiceRoll!;

    for (var i = 0; i < diceValue; i++) {
      moveTokenStep(playerIndex, tokenIndex);
    }

    final captured = _checkCapture(playerIndex, tokenIndex);

    if (phase != GamePhase.finished) {
      if (pendingExtraRolls > 0) {
        pendingExtraRolls--;
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
      hasCapturedOpponent[playerIndex] = true;
      pendingExtraRolls++; // Capturing an opponent grants an extra roll
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
    pendingExtraRolls = 0;
    lastDiceRoll = null;
    validTokenMoves = [];
  }

  /// Reset game
  void reset() {
    tokenPositions = List.generate(
      players.length,
      (_) => List.filled(tokensPerPlayer, posInBase),
    );
    hasCapturedOpponent = List.filled(players.length, false);
    currentPlayerIndex = 0;
    lastDiceRoll = null;
    consecutiveSixes = 0;
    pendingExtraRolls = 0;
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
        'hasCapturedOpponent': hasCapturedOpponent,
        'currentPlayerIndex': currentPlayerIndex,
        'lastDiceRoll': lastDiceRoll,
        'consecutiveSixes': consecutiveSixes,
        'pendingExtraRolls': pendingExtraRolls,
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
    if (json['hasCapturedOpponent'] != null) {
      hasCapturedOpponent = List<bool>.from(json['hasCapturedOpponent'] as List);
    }
    currentPlayerIndex = json['currentPlayerIndex'] as int;
    lastDiceRoll = json['lastDiceRoll'] as int?;
    consecutiveSixes = json['consecutiveSixes'] as int;
    pendingExtraRolls = (json['pendingExtraRolls'] as int?) ?? 0;
    phase = GamePhase.values[json['phase'] as int];
    validTokenMoves = List<int>.from(json['validTokenMoves'] as List);
    winner = json['winner'] as int?;
    finishOrder = List<int>.from(json['finishOrder'] as List);
    notifyListeners();
  }
  /// Allow external callers (GameService) to trigger a repaint
  void notifyChange() => notifyListeners();
}
