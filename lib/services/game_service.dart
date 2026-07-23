import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/ai_player.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../utils/constants.dart';

import 'sound_service.dart';

// ponytail: orchestrates local game loop with step-by-step tile traversal

class GameService {
  final GameState state;
  final AIPlayer _ai = AIPlayer();
  final Duration displayDelay;
  final bool runAI;

  Timer? _turnTimer;
  bool _disposed = false;
  bool _isMovingStep = false;

  /// Callback for capture events
  VoidCallback? onCapture;

  /// Callback for home events
  VoidCallback? onHome;

  /// Callback for dice roll
  ValueChanged<int>? onDiceRoll;

  /// Callback when a token move finishes animating
  VoidCallback? onMoveComplete;

  GameService({
    required this.state,
    this.displayDelay = const Duration(milliseconds: 2000),
    this.runAI = true,
  }) {
    state.addListener(_onStateChanged);
  }

  /// Start the game — if first player is AI, trigger their turn
  void start() {
    state.phase = GamePhase.rolling;
    state.notifyChange();
    _tryAITurn();
  }

  void _onStateChanged() {
    if (!runAI || _disposed || _isMovingStep || state.isGameOver) return;
    if (!state.isCurrentPlayerAI) return;

    // If an AI turn is in progress but the delayed action was skipped or
    // overwritten by a sync update, reschedule it from the latest state.
    final timerActive = _turnTimer?.isActive ?? false;
    if (timerActive) return;

    if (state.phase == GamePhase.rolling) {
      _tryAITurn();
      return;
    }

    if (state.phase == GamePhase.moving && state.validTokenMoves.isNotEmpty) {
      _turnTimer = Timer(const Duration(milliseconds: 500), () {
        if (_disposed || state.isGameOver || !state.isCurrentPlayerAI) return;
        if (state.phase != GamePhase.moving || state.validTokenMoves.isEmpty) return;
        final token = _ai.chooseToken(state);
        _animateStepByStepMove(token);
      });
    }
  }

  /// Human player rolls dice
  void rollDice() {
    if (state.phase != GamePhase.rolling || _isMovingStep) return;
    if (state.isCurrentPlayerAI) return;

    SoundService.playDiceRollSound();
    final value = state.rollDice();
    onDiceRoll?.call(value);
    onMoveComplete?.call();

    if (state.validTokenMoves.isEmpty) {
      // No valid moves — check if player gets another roll (rolled 6) or pass
      _turnTimer?.cancel();
      _turnTimer = Timer(displayDelay, () {
        if (_disposed || state.isGameOver) return;
        if (state.getsExtraRoll) {
          // Rolled a 6 but no moves — still get another roll
          state.getsExtraRoll = false;
          state.phase = GamePhase.rolling;
          state.lastDiceRoll = null;
          state.validTokenMoves = [];
          state.activeEmoji = null;
          state.activeEmojiPlayerIndex = null;
          state.notifyChange();
        } else {
          state.advanceTurn();
        }
        // ponytail: sync after turn state change so remote player gets the update
        onMoveComplete?.call();
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
      SoundService.playStepSound();
      state.moveTokenStep(playerIndex, tokenIndex);
      _checkAndFinishMove(playerIndex, tokenIndex);
    } else {
      // Step-by-step tile traversal with sound ("pig, pig, pig...")
      var stepCount = 0;
      Timer.periodic(const Duration(milliseconds: 240), (timer) {
        if (_disposed || state.isGameOver) {
          timer.cancel();
          _isMovingStep = false;
          return;
        }

        stepCount++;
        SoundService.playStepSound();
        state.moveTokenStep(playerIndex, tokenIndex);

        if (stepCount >= diceValue) {
          timer.cancel();
          _checkAndFinishMove(playerIndex, tokenIndex);
        }
      });
    }
  }

  void _checkAndFinishMove(int playerIndex, int tokenIndex) {
    final capturedOpponents = state.findCapturedOpponents(playerIndex, tokenIndex);

    if (capturedOpponents.isNotEmpty) {
      // Realistic reverse animation for captured tokens back to base with cut sound
      SoundService.playCaptureSound();

      Timer.periodic(const Duration(milliseconds: 70), (revTimer) {
        if (_disposed) {
          revTimer.cancel();
          _isMovingStep = false;
          return;
        }

        var allBackInBase = true;
        for (final opp in capturedOpponents) {
          final oppP = opp.x;
          final oppT = opp.y;
          if (state.tokenPositions[oppP][oppT] != posInBase) {
            state.reverseTokenStep(oppP, oppT);
            allBackInBase = false;
          }
        }

        if (allBackInBase) {
          revTimer.cancel();
          final captured = state.checkFinalCapture(playerIndex, tokenIndex);
          _isMovingStep = false;
          _finishMoveTurn(captured);
        }
      });
    } else {
      final captured = state.checkFinalCapture(playerIndex, tokenIndex);
      _isMovingStep = false;
      _finishMoveTurn(captured);
    }
  }

  void _finishMoveTurn(bool captured) {
    if (captured) onCapture?.call();
    if (state.hasPlayerFinished(state.currentPlayerIndex)) {
      SoundService.playVictorySound();
      onHome?.call();
    }
    if (state.isGameOver) {
      SoundService.playVictorySound();
    }

    if (!state.isGameOver) {
      // Ludo King: extra turn if rolled 6 OR captured (boolean, no stacking)
      if (state.getsExtraRoll) {
        state.getsExtraRoll = false;
        state.phase = GamePhase.rolling;
        state.lastDiceRoll = null;
        state.validTokenMoves = [];
        state.activeEmoji = null;
        state.activeEmojiPlayerIndex = null;
        state.notifyChange();
      } else {
        state.advanceTurn();
      }
    }

    // ponytail: sync AFTER turn state is fully updated so remote gets the new currentPlayerIndex
    onMoveComplete?.call();

    if (!state.isGameOver) {
      _tryAITurn();
    }
  }

  /// Check if current player is AI and handle their turn
  void _tryAITurn() {
    if (!runAI) return;
    if (_disposed || _isMovingStep) return;
    if (state.isGameOver) return;
    if (!state.isCurrentPlayerAI) return;

    _turnTimer?.cancel();
    _turnTimer = Timer(const Duration(milliseconds: 1400), _executeAITurn);
  }

  void _executeAITurn() {
    if (_disposed || state.isGameOver || _isMovingStep) return;
    if (!state.isCurrentPlayerAI) return;

    if (state.phase == GamePhase.rolling) {
      final value = state.rollDice();
      onDiceRoll?.call(value);
      onMoveComplete?.call();

      if (state.phase == GamePhase.moving) {
        // Show AI dice roll result for 1s before AI steps token
        _turnTimer?.cancel();
        _turnTimer = Timer(const Duration(milliseconds: 1400), () {
          if (_disposed || state.isGameOver) return;
          final token = _ai.chooseToken(state);
          _animateStepByStepMove(token);
        });
      } else {
        // No valid moves — check extra roll or pass
        _turnTimer?.cancel();
        _turnTimer = Timer(displayDelay, () {
          if (_disposed || state.isGameOver) return;
          if (state.getsExtraRoll) {
            state.getsExtraRoll = false;
            state.phase = GamePhase.rolling;
            state.lastDiceRoll = null;
            state.validTokenMoves = [];
            state.activeEmoji = null;
            state.activeEmojiPlayerIndex = null;
            state.notifyChange();
            _tryAITurn();
          } else {
            state.advanceTurn();
            _tryAITurn();
          }
        });
      }
    }
  }

  void dispose() {
    _disposed = true;
    _turnTimer?.cancel();
    state.removeListener(_onStateChanged);
  }

  /// Create a standard local game
  static GameService createLocalGame({
    required BoardType boardType,
    required int humanPlayers,
    required int aiPlayers,
    AIDifficulty aiDifficulty = AIDifficulty.medium,
    List<String>? humanNames,
    List<PlayerColor>? humanColors,
    bool enableJodi = true,
    bool enableTeamUp = false,
  }) {
    final allColors = boardType == BoardType.classic4
        ? [PlayerColor.red, PlayerColor.green, PlayerColor.yellow, PlayerColor.blue]
        : PlayerColor.values;

    final players = <Player>[];
    final assignedColors = <PlayerColor>[];

    final totalPlayersCount = humanPlayers + aiPlayers;

    for (var i = 0; i < humanPlayers; i++) {
      final name = (humanNames != null && i < humanNames.length && humanNames[i].trim().isNotEmpty)
          ? humanNames[i].trim()
          : 'Player ${i + 1}';
      final color = (humanColors != null && i < humanColors.length)
          ? humanColors[i]
          : allColors[i % allColors.length];
      assignedColors.add(color);

      final teamId = enableTeamUp && totalPlayersCount == 4
          ? (i % 2 == 0 ? 0 : 1)
          : null;

      players.add(Player(
        id: 'human_$i',
        name: name,
        color: color,
        type: PlayerType.human,
        teamId: teamId,
      ));
    }

    final remainingColors = allColors.where((c) => !assignedColors.contains(c)).toList();
    for (var i = 0; i < aiPlayers; i++) {
      final playerIndex = humanPlayers + i;
      final color = i < remainingColors.length
          ? remainingColors[i]
          : allColors[playerIndex % allColors.length];

      final teamId = enableTeamUp && totalPlayersCount == 4
          ? (playerIndex % 2 == 0 ? 0 : 1)
          : null;

      players.add(Player(
        id: 'ai_$i',
        name: 'Bot ${i + 1}',
        color: color,
        type: PlayerType.ai,
        difficulty: aiDifficulty,
        teamId: teamId,
      ));
    }

    final state = GameState(
      boardType: boardType,
      players: players,
      enableJodi: enableJodi,
    );

    return GameService(state: state);
  }
}
