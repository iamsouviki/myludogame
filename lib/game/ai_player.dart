import 'dart:math';

import '../models/game_state.dart';
import '../utils/constants.dart';

// ponytail: heuristic AI, no ML needed for a board game

class AIPlayer {
  final Random _random = Random();

  /// Pick the best token to move for the current AI player
  int chooseToken(GameState state) {
    final playerIndex = state.currentPlayerIndex;
    final player = state.players[playerIndex];
    final difficulty = player.difficulty ?? AIDifficulty.medium;
    final diceValue = state.lastDiceRoll!;

    // Sometimes pick random (based on difficulty)
    if (_random.nextDouble() > difficulty.optimalRate) {
      return state.validTokenMoves[
          _random.nextInt(state.validTokenMoves.length)];
    }

    // Score each valid token move
    var bestToken = state.validTokenMoves.first;
    var bestScore = -1000.0;

    for (final tokenIndex in state.validTokenMoves) {
      final score = _scoreMove(state, playerIndex, tokenIndex, diceValue);
      if (score > bestScore) {
        bestScore = score;
        bestToken = tokenIndex;
      }
    }

    return bestToken;
  }

  double _scoreMove(
      GameState state, int playerIndex, int tokenIndex, int diceValue) {
    final pos = state.tokenPositions[playerIndex][tokenIndex];
    var score = 0.0;

    // 1. Enter a token from base (high priority)
    if (pos == posInBase && diceValue == diceToEnter) {
      score += 50;
      // Extra priority if we have few tokens on board
      final tokensOnBoard = state.tokenPositions[playerIndex]
          .where((p) => p != posInBase && p != posHome)
          .length;
      if (tokensOnBoard == 0) score += 30; // must enter
    }

    // 2. Reaching home (highest priority)
    if (pos != posInBase && pos != posHome) {
      final dist = state.distanceTraveled(playerIndex, tokenIndex);
      final newDist = dist + diceValue;
      final maxDist =
          state.boardType.trackLength + state.boardType.homeStretchLength - 1;
      if (newDist == maxDist) {
        score += 100; // reaching home!
      }
    }

    // 3. Capture an opponent (high priority)
    if (pos != posInBase) {
      final newPos = _simulateNewPosition(state, playerIndex, tokenIndex, diceValue);
      if (newPos >= 0 && newPos < state.boardType.trackLength) {
        if (!state.safeSpots.contains(newPos)) {
          for (var p = 0; p < state.players.length; p++) {
            if (p == playerIndex) continue;
            for (var t = 0; t < tokensPerPlayer; t++) {
              if (state.tokenPositions[p][t] == newPos) {
                score += 70; // capture!
                // Extra points for capturing a token that's far along
                score += state.distanceTraveled(p, t) * 0.3;
              }
            }
          }
        }
      }
    }

    // 4. Move to a safe spot
    if (pos != posInBase && pos != posHome) {
      final newPos = _simulateNewPosition(state, playerIndex, tokenIndex, diceValue);
      if (newPos >= 0 && state.safeSpots.contains(newPos)) {
        score += 20;
      }
    }

    // 5. Avoid danger: if opponent is within 6 behind us, move away
    if (pos != posInBase && pos != posHome && pos < state.boardType.trackLength) {
      if (_isInDanger(state, playerIndex, pos)) {
        score += 25; // move out of danger
      }
    }

    // 6. Prefer moving tokens closer to home (progress bonus)
    if (pos != posInBase && pos != posHome) {
      final dist = state.distanceTraveled(playerIndex, tokenIndex);
      score += dist * 0.2; // small bonus for further along tokens
    }

    // 7. Prefer moving into home stretch (safe zone)
    if (pos != posInBase && pos != posHome) {
      final dist = state.distanceTraveled(playerIndex, tokenIndex);
      final newDist = dist + diceValue;
      if (newDist > state.boardType.trackLength - 1 &&
          dist <= state.boardType.trackLength - 1) {
        score += 40; // entering home stretch
      }
    }

    return score;
  }

  int _simulateNewPosition(
      GameState state, int playerIndex, int tokenIndex, int diceValue) {
    final pos = state.tokenPositions[playerIndex][tokenIndex];
    if (pos == posInBase) return state.startPosition(playerIndex);

    final dist = state.distanceTraveled(playerIndex, tokenIndex);
    final newDist = dist + diceValue;
    if (newDist > state.boardType.trackLength - 1) {
      return state.boardType.trackLength + (newDist - state.boardType.trackLength);
    }
    return (state.startPosition(playerIndex) + newDist) %
        state.boardType.trackLength;
  }

  bool _isInDanger(GameState state, int playerIndex, int pos) {
    for (var p = 0; p < state.players.length; p++) {
      if (p == playerIndex) continue;
      for (var t = 0; t < tokensPerPlayer; t++) {
        final oppPos = state.tokenPositions[p][t];
        if (oppPos < 0 || oppPos >= state.boardType.trackLength) continue;
        // Check if opponent is within 6 cells behind us
        final diff = (pos - oppPos + state.boardType.trackLength) %
            state.boardType.trackLength;
        if (diff > 0 && diff <= diceMax) {
          return true;
        }
      }
    }
    return false;
  }
}
