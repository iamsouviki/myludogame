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
  bool getsExtraRoll =
      false; // Ludo King: rolling 6 or capturing = one extra turn
  GamePhase phase = GamePhase.rolling;
  List<int> validTokenMoves = []; // indices of tokens that can move
  int? winner; // player index of winner, null if game ongoing
  List<int> finishOrder = []; // player indices in order of finishing
  String? activeEmoji;
  int? activeEmojiPlayerIndex;
  int? activeEmojiAt;

  // Monotonic client revision used to reject stale online state writes.
  int stateVersion = 0;

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

  void _markChanged() {
    stateVersion++;
    notifyListeners();
  }

  /// Repaint without claiming a gameplay mutation.
  void repaint() => notifyListeners();

  /// Physical route slot for a player. Turn order remains list/index-based.
  int playerPositionIndex(int playerIndex) {
    if (playerIndex < 0 || playerIndex >= players.length) return 0;
    final slot = boardType.availableColors.indexOf(players[playerIndex].color);
    return slot >= 0 ? slot : playerIndex % boardType.maxPlayers;
  }

  int _startPositionForSlot(int slot) {
    if (slot < 0 || slot >= boardType.maxPlayers) return 0;
    return slot * boardType.cellsPerArm;
  }

  /// Absolute board position for a player's color-defined start cell.
  int startPosition(int playerIndex) =>
      _startPositionForSlot(playerPositionIndex(playerIndex));

  /// Absolute board position for a player's color-defined home entry.
  int homeEntryPosition(int playerIndex) {
    final slot = playerPositionIndex(playerIndex);
    if (boardType == BoardType.classic4) {
      // The painted arrows are the home-entry cells. The adjacent approach
      // boxes remain on the outer track and are counted normally.
      const entries = [50, 11, 24, 37];
      return entries[slot];
    }
    final start = _startPositionForSlot(slot);
    return (start + boardType.trackLength - 2) % boardType.trackLength;
  }

  /// Safe spots on the board (start cells and star cells).
  Set<int> get safeSpots {
    final spots = <int>{};
    for (var slot = 0; slot < boardType.maxPlayers; slot++) {
      final start = _startPositionForSlot(slot);
      spots.add(start);
      spots.add((start + 8) % boardType.trackLength);
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
      return boardType.trackLength + stepsIntoHome;
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

  bool get isTeamMode =>
      players.map((player) => player.teamId).whereType<int>().toSet().length >
      1;

  bool _hasTeamFinished(int teamId) {
    final teamPlayers = <int>[];
    for (var i = 0; i < players.length; i++) {
      if (players[i].teamId == teamId) teamPlayers.add(i);
    }
    return teamPlayers.isNotEmpty && teamPlayers.every(hasPlayerFinished);
  }

  /// Roll the dice (Ludo King rules)
  int rollDice() {
    // Normalize older/restored snapshots that still point at a finished player.
    if (hasPlayerFinished(currentPlayerIndex)) {
      _nextTurn();
      if (hasPlayerFinished(currentPlayerIndex)) {
        phase = GamePhase.finished;
      } else {
        phase = GamePhase.rolling;
      }
      _markChanged();
      return 0;
    }

    final rolled = _dice.roll();
    lastDiceRoll = rolled;
    getsExtraRoll = false; // reset before evaluating

    if (rolled == diceMax) {
      consecutiveSixes++;
      if (consecutiveSixes >= maxConsecutiveSixes) {
        // Triple-6: lose turn entirely (Ludo King rule)
        consecutiveSixes = 0;
        getsExtraRoll = false;
        validTokenMoves = [];
        lastDiceRoll = null;
        _nextTurn();
        phase = GamePhase.rolling;
        _markChanged();
        return rolled;
      }
      // Rolling a 6 grants an extra turn (set after move in moveToken)
      getsExtraRoll = true;
    } else {
      consecutiveSixes = 0;
    }

    // Find valid moves
    validTokenMoves = _findValidMoves(currentPlayerIndex, rolled);

    // A six grants a bonus only when at least one token can legally move.
    // Keep this in the model so offline and online snapshots agree immediately.
    if (validTokenMoves.isEmpty) getsExtraRoll = false;

    // ponytail: phase is ALWAYS moving after rolling so dice cannot be tapped again
    // until turn finishes or advances
    phase = GamePhase.moving;

    _markChanged();
    return rolled;
  }

  /// Advance to next turn explicitly (no extra roll)
  void advanceTurn() {
    getsExtraRoll = false;
    _nextTurn();
    phase = GamePhase.rolling;
    _markChanged();
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
      return diceValue == diceToEnter &&
          !_isBlockedForMove(
            playerIndex,
            startPosition(playerIndex),
            isFinal: true,
          );
    }

    // Ludo King: a two-token stack is a blockade. A move may not pass through
    // one, land on an opponent blockade, or land on a friendly stack of two.
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
      if (currPos >= 0 &&
          currPos < boardType.trackLength &&
          _isBlockedForMove(playerIndex, currPos, isFinal: s == diceValue)) {
        return false;
      }
    }

    return true;
  }

  bool _isBlockedForMove(
    int playerIndex,
    int position, {
    required bool isFinal,
  }) {
    if (safeSpots.contains(position)) return false;

    final countsByPlayer = <int, int>{};
    for (var p = 0; p < players.length; p++) {
      for (var t = 0; t < tokensPerPlayer; t++) {
        if (tokenPositions[p][t] == position) {
          countsByPlayer[p] = (countsByPlayer[p] ?? 0) + 1;
        }
      }
    }

    // A blockade is two tokens of one color/player. Two different opponents,
    // including teammates in team mode, do not create a blockade together.
    return countsByPlayer.values.any((count) => count >= 2);
  }

  bool moveTokenStep(int playerIndex, int tokenIndex) {
    if (playerIndex < 0 ||
        playerIndex >= tokenPositions.length ||
        tokenIndex < 0 ||
        tokenIndex >= tokenPositions[playerIndex].length) {
      return false;
    }
    final pos = tokenPositions[playerIndex][tokenIndex];
    if (pos == posInBase) {
      tokenPositions[playerIndex][tokenIndex] = startPosition(playerIndex);
      _markChanged();
      return true;
    }

    if (pos >= boardType.trackLength) {
      final stepsIntoHome = (pos - boardType.trackLength) + 1;
      if (stepsIntoHome >= boardType.homeStretchLength) {
        tokenPositions[playerIndex][tokenIndex] = posHome;
        getsExtraRoll = true; // Reached home cell — extra turn
        if (hasPlayerFinished(playerIndex) &&
            !finishOrder.contains(playerIndex)) {
          finishOrder.add(playerIndex);

          if (isTeamMode) {
            final teamId = players[playerIndex].teamId;
            if (teamId != null && _hasTeamFinished(teamId)) {
              winner = playerIndex;
              getsExtraRoll = false;
              for (var i = 0; i < players.length; i++) {
                if (!finishOrder.contains(i)) finishOrder.add(i);
              }
              phase = GamePhase.finished;
            }
          } else {
            winner ??= playerIndex;
            // Keep the final active player in the rotation so every player
            // receives a rank instead of ending one position early.
            if (finishOrder.length >= players.length) {
              getsExtraRoll = false;
              for (var i = 0; i < players.length; i++) {
                if (!finishOrder.contains(i)) finishOrder.add(i);
              }
              phase = GamePhase.finished;
            }
          }
          // A completed player must not keep the six/capture extra-roll.
          if (hasPlayerFinished(playerIndex)) getsExtraRoll = false;
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

    _markChanged();
    return false;
  }

  /// Send captured tokens directly back to their base.
  void sendCapturedTokensHome(Iterable<Point<int>> capturedTokens) {
    var changed = false;
    for (final captured in capturedTokens) {
      final playerIndex = captured.x;
      final tokenIndex = captured.y;
      if (playerIndex < 0 ||
          playerIndex >= tokenPositions.length ||
          tokenIndex < 0 ||
          tokenIndex >= tokenPositions[playerIndex].length) {
        continue;
      }
      if (tokenPositions[playerIndex][tokenIndex] != posInBase) {
        tokenPositions[playerIndex][tokenIndex] = posInBase;
        changed = true;
      }
    }
    if (changed) _markChanged();
  }

  /// Move a token 1 step backwards along its track toward its base
  void reverseTokenStep(int playerIndex, int tokenIndex) {
    if (playerIndex < 0 ||
        playerIndex >= tokenPositions.length ||
        tokenIndex < 0 ||
        tokenIndex >= tokenPositions[playerIndex].length) {
      return;
    }
    final pos = tokenPositions[playerIndex][tokenIndex];
    if (pos == posInBase) return;

    if (pos == startPosition(playerIndex)) {
      tokenPositions[playerIndex][tokenIndex] = posInBase;
    } else if (pos >= boardType.trackLength) {
      final stepsIntoHome = pos - boardType.trackLength;
      if (stepsIntoHome == 0) {
        tokenPositions[playerIndex][tokenIndex] = homeEntryPosition(
          playerIndex,
        );
      } else {
        tokenPositions[playerIndex][tokenIndex] = pos - 1;
      }
    } else {
      tokenPositions[playerIndex][tokenIndex] =
          (pos - 1 + boardType.trackLength) % boardType.trackLength;
    }

    _markChanged();
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
    if (lastDiceRoll == null || !validTokenMoves.contains(tokenIndex)) {
      return false;
    }
    if (tokenIndex < 0 || tokenIndex >= tokensPerPlayer) return false;

    final playerIndex = currentPlayerIndex;
    final diceValue = lastDiceRoll!;
    final pos = tokenPositions[playerIndex][tokenIndex];

    // Leaving base consumes the six; it does not also advance five more cells.
    final steps = pos == posInBase ? 1 : diceValue;
    for (var i = 0; i < steps; i++) {
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

    _markChanged();
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
      if (currentTeam != null && players[p].teamId == currentTeam) {
        continue; // teammates don't capture each other
      }
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
    activeEmoji = null;
    activeEmojiPlayerIndex = null;
    activeEmojiAt = null;
    _markChanged();
  }

  /// Remove a player from the active match, keeping the game alive for the rest.
  /// Returns true if a player was removed.
  bool removePlayerById(String playerId) {
    final removedIndex = players.indexWhere((p) => p.id == playerId);
    if (removedIndex < 0) return false;

    players.removeAt(removedIndex);
    tokenPositions.removeAt(removedIndex);

    if (players.isEmpty) {
      phase = GamePhase.finished;
      currentPlayerIndex = 0;
      winner = null;
      finishOrder = [];
      validTokenMoves = [];
      notifyListeners();
      return true;
    }

    finishOrder = finishOrder
        .where((idx) => idx != removedIndex)
        .map((idx) => idx > removedIndex ? idx - 1 : idx)
        .toList();

    if (winner != null) {
      if (winner == removedIndex) {
        winner = finishOrder.isNotEmpty ? finishOrder.first : null;
      } else if (winner! > removedIndex) {
        winner = winner! - 1;
      }
    }

    if (currentPlayerIndex == removedIndex) {
      currentPlayerIndex = currentPlayerIndex % players.length;
    } else if (currentPlayerIndex > removedIndex) {
      currentPlayerIndex -= 1;
    }

    if (players.length == 1) {
      phase = GamePhase.finished;
      currentPlayerIndex = 0;
      winner = 0;
      validTokenMoves = [];
    } else if (currentPlayerIndex >= players.length) {
      currentPlayerIndex = 0;
    }

    validTokenMoves = [];
    activeEmoji = null;
    activeEmojiPlayerIndex = null;
    activeEmojiAt = null;
    lastDiceRoll = null;
    getsExtraRoll = false;
    _markChanged();
    return true;
  }

  bool setTurnEmoji(String emoji) {
    if (activeEmoji != null) return false;
    activeEmoji = emoji;
    activeEmojiPlayerIndex = currentPlayerIndex;
    activeEmojiAt = DateTime.now().millisecondsSinceEpoch;
    _markChanged();
    return true;
  }

  /// Serialize for online sync
  Map<String, dynamic> toJson() => {
    'boardType': boardType.index,
    'players': players.map((p) => p.toJson()).toList(),
    'tokenPositions': tokenPositions.map((t) => t.toList()).toList(),
    'currentPlayerIndex': currentPlayerIndex,
    'lastDiceRoll': lastDiceRoll,
    'consecutiveSixes': consecutiveSixes,
    'getsExtraRoll': getsExtraRoll,
    'phase': phase.index,
    'validTokenMoves': validTokenMoves,
    'winner': winner,
    'finishOrder': finishOrder,
    'activeEmoji': activeEmoji,
    'activeEmojiPlayerIndex': activeEmojiPlayerIndex,
    'activeEmojiAt': activeEmojiAt,
    'stateVersion': stateVersion,
  };

  /// Restore from online sync (mutates in place)
  void loadFromJson(Map<String, dynamic> json, {bool force = false}) {
    final incomingVersion = (json['stateVersion'] as num?)?.toInt() ?? 0;
    if (!force && incomingVersion <= stateVersion) return;

    if (json['players'] is List) {
      final rawPlayers = json['players'] as List;
      final parsedPlayers = rawPlayers
          .map(
            (p) =>
                p is Map ? Player.fromJson(Map<String, dynamic>.from(p)) : null,
          )
          .whereType<Player>()
          .toList();
      if (parsedPlayers.isNotEmpty) {
        players.clear();
        players.addAll(parsedPlayers);
      }
    }

    final rawTokens = json['tokenPositions'];
    if (rawTokens is List) {
      tokenPositions = rawTokens.map((t) {
        final maxTrackPosition =
            boardType.trackLength + boardType.homeStretchLength - 1;
        final values = t is List
            ? t
                  .whereType<num>()
                  .map((value) => value.toInt())
                  .where(
                    (value) =>
                        value == posInBase ||
                        value == posHome ||
                        (value >= 0 && value <= maxTrackPosition),
                  )
                  .take(tokensPerPlayer)
                  .toList()
            : <int>[];
        while (values.length < tokensPerPlayer) {
          values.add(posInBase);
        }
        return values;
      }).toList();
    }

    while (tokenPositions.length < players.length) {
      tokenPositions.add(List.filled(tokensPerPlayer, posInBase));
    }
    if (tokenPositions.length > players.length) {
      tokenPositions = tokenPositions.sublist(0, players.length);
    }

    currentPlayerIndex = (json['currentPlayerIndex'] as num?)?.toInt() ?? 0;
    if (players.isEmpty ||
        currentPlayerIndex < 0 ||
        currentPlayerIndex >= players.length) {
      currentPlayerIndex = 0;
    }

    final parsedDice = (json['lastDiceRoll'] as num?)?.toInt();
    lastDiceRoll =
        parsedDice != null && parsedDice >= diceMin && parsedDice <= diceMax
        ? parsedDice
        : null;
    consecutiveSixes = ((json['consecutiveSixes'] as num?)?.toInt() ?? 0).clamp(
      0,
      maxConsecutiveSixes - 1,
    );
    getsExtraRoll = (json['getsExtraRoll'] as bool?) ?? false;
    final phaseIndex =
        (json['phase'] as num?)?.toInt() ?? GamePhase.rolling.index;
    if (phaseIndex >= 0 && phaseIndex < GamePhase.values.length) {
      phase = GamePhase.values[phaseIndex];
    }
    validTokenMoves = (json['validTokenMoves'] is List)
        ? (json['validTokenMoves'] as List)
              .whereType<num>()
              .map((value) => value.toInt())
              .where((value) => value >= 0 && value < tokensPerPlayer)
              .toSet()
              .toList()
        : <int>[];
    if (phase == GamePhase.rolling &&
        lastDiceRoll != null &&
        validTokenMoves.isNotEmpty) {
      phase = GamePhase.moving;
    } else if (phase == GamePhase.moving && lastDiceRoll == null) {
      phase = GamePhase.rolling;
      validTokenMoves = [];
    } else if (phase == GamePhase.animating) {
      phase = lastDiceRoll != null ? GamePhase.moving : GamePhase.rolling;
    }
    final parsedWinner = (json['winner'] as num?)?.toInt();
    winner =
        parsedWinner != null &&
            parsedWinner >= 0 &&
            parsedWinner < players.length
        ? parsedWinner
        : null;
    finishOrder = (json['finishOrder'] is List)
        ? (json['finishOrder'] as List)
              .whereType<num>()
              .map((value) => value.toInt())
              .where((value) => value >= 0 && value < players.length)
              .toSet()
              .toList()
        : <int>[];
    activeEmoji = json['activeEmoji'] as String?;
    final parsedEmojiPlayer = (json['activeEmojiPlayerIndex'] as num?)?.toInt();
    activeEmojiPlayerIndex =
        parsedEmojiPlayer != null &&
            parsedEmojiPlayer >= 0 &&
            parsedEmojiPlayer < players.length
        ? parsedEmojiPlayer
        : null;
    activeEmojiAt = (json['activeEmojiAt'] as num?)?.toInt();
    stateVersion = incomingVersion;
    notifyListeners();
  }

  /// Allow external callers (GameService) to record a state mutation and repaint.
  void notifyChange() => _markChanged();
}
