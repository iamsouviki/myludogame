import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/ai_player.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../utils/constants.dart';

// ponytail: orchestrates local game loop with step-by-step tile traversal

class GameService {
  final GameState state;
  final AIPlayer _ai = AIPlayer();
  final Duration displayDelay;

  Timer? _turnTimer;
  bool _disposed = false;
  bool _isMovingStep = false;

  /// Callback for capture events
  VoidCallback? onCapture;

  /// Callback for home events
  VoidCallback? onHome;

  /// Callback for dice roll
  ValueChanged<int>? onDiceRoll;

  GameService({
    required this.state,
    this.displayDelay = const Duration(milliseconds: 2000),
  });

  /// Start the game — if first player is AI, trigger their turn
  void start() {
    state.phase = GamePhase.rolling;
    state.notifyChange();
    _tryAITurn();
  }

  /// Human player rolls dice
  void rollDice() {
    if (state.phase != GamePhase.rolling || _isMovingStep) return;
    if (state.isCurrentPlayerAI) return;

    final value = state.rollDice();
    onDiceRoll?.call(value);

    if (state.validTokenMoves.isEmpty) {
      // No valid moves — display dice result in player's color for 2s before passing turn
      _turnTimer?.cancel();
      _turnTimer = Timer(displayDelay, () {
        if (_disposed || state.isGameOver) return;
        state.advanceTurn();
        _tryAITurn();
      });
    } else if (state.validTokenMoves.length == 1) {
      // Single valid token available — display dice result clearly for 1.2s before auto-moving
      final autoTokenIndex = state.validTokenMoves.first;
      _turnTimer?.cancel();
      _turnTimer = Timer(const Duration(milliseconds: 1200), () {
        if (_disposed || state.isGameOver) return;
        selectToken(autoTokenIndex);
      });
    }
  }

  /// Human player selects a token to move (animates step-by-step touching each box)
  void selectToken(int tokenIndex) {
    if (state.phase != GamePhase.moving || _isMovingStep) return;
    if (state.isCurrentPlayerAI) return;

    _animateStepByStepMove(tokenIndex);
  }

  /// Animate step-by-step movement touching each tile box along the track
  void _animateStepByStepMove(int tokenIndex) {
    _isMovingStep = true;
    final playerIndex = state.currentPlayerIndex;
    final diceValue = state.lastDiceRoll!;
    final pos = state.tokenPositions[playerIndex][tokenIndex];

    if (pos == posInBase) {
      // Entering board (1 step out of base)
      state.moveTokenStep(playerIndex, tokenIndex);
      final captured = state.checkFinalCapture(playerIndex, tokenIndex);
      _isMovingStep = false;
      _finishMoveTurn(captured);
    } else {
      // Step-by-step tile traversal (140ms per step for 60fps smooth stepping)
      var stepCount = 0;
      Timer.periodic(const Duration(milliseconds: 140), (timer) {
        if (_disposed || state.isGameOver) {
          timer.cancel();
          _isMovingStep = false;
          return;
        }

        stepCount++;
        state.moveTokenStep(playerIndex, tokenIndex);

        if (stepCount >= diceValue) {
          timer.cancel();
          final captured = state.checkFinalCapture(playerIndex, tokenIndex);
          _isMovingStep = false;
          _finishMoveTurn(captured);
        }
      });
    }
  }

  void _finishMoveTurn(bool captured) {
    if (captured) onCapture?.call();
    if (state.hasPlayerFinished(state.currentPlayerIndex)) {
      onHome?.call();
    }

    if (!state.isGameOver) {
      if (state.lastDiceRoll == diceMax && !captured) {
        // Extra turn for rolling a 6 — stay on same player
        state.phase = GamePhase.rolling;
        state.notifyChange();
        _tryAITurn();
      } else {
        // Move to next player immediately with zero gap
        state.advanceTurn();
        _tryAITurn();
      }
    }
  }

  /// Check if current player is AI and handle their turn
  void _tryAITurn() {
    if (_disposed || _isMovingStep) return;
    if (state.isGameOver) return;
    if (!state.isCurrentPlayerAI) return;

    _turnTimer?.cancel();
    _turnTimer = Timer(const Duration(milliseconds: 800), _executeAITurn);
  }

  void _executeAITurn() {
    if (_disposed || state.isGameOver || _isMovingStep) return;
    if (!state.isCurrentPlayerAI) return;

    if (state.phase == GamePhase.rolling) {
      final value = state.rollDice();
      onDiceRoll?.call(value);

      if (state.phase == GamePhase.moving) {
        // Show AI dice roll result for 1s before AI steps token
        _turnTimer?.cancel();
        _turnTimer = Timer(const Duration(milliseconds: 1000), () {
          if (_disposed || state.isGameOver) return;
          final token = _ai.chooseToken(state);
          _animateStepByStepMove(token);
        });
      } else {
        // No valid moves — display AI dice result for 2s before advancing to next color
        _turnTimer?.cancel();
        _turnTimer = Timer(displayDelay, () {
          if (_disposed || state.isGameOver) return;
          state.advanceTurn();
          _tryAITurn();
        });
      }
    }
  }

  void dispose() {
    _disposed = true;
    _turnTimer?.cancel();
  }

  /// Create a standard local game
  static GameService createLocalGame({
    required BoardType boardType,
    required int humanPlayers,
    required int aiPlayers,
    AIDifficulty aiDifficulty = AIDifficulty.medium,
  }) {
    final colors = boardType == BoardType.classic4
        ? [PlayerColor.red, PlayerColor.green, PlayerColor.yellow, PlayerColor.blue]
        : PlayerColor.values;

    final players = <Player>[];
    for (var i = 0; i < humanPlayers; i++) {
      players.add(Player(
        id: 'human_$i',
        name: 'Player ${i + 1}',
        color: colors[i],
        type: PlayerType.human,
      ));
    }
    for (var i = 0; i < aiPlayers; i++) {
      players.add(Player(
        id: 'ai_$i',
        name: 'Bot ${i + 1}',
        color: colors[humanPlayers + i],
        type: PlayerType.ai,
        difficulty: aiDifficulty,
      ));
    }

    final state = GameState(boardType: boardType, players: players);
    return GameService(state: state);
  }
}
