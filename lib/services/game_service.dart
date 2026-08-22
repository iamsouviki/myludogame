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
  bool runAI;

  Timer? _turnTimer;
  bool _disposed = false;
  bool _isMovingStep = false;
  bool get isAnimating => _isMovingStep;

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
    // Do not reset a restored or remote move phase; only fresh games roll.
    if (state.phase == GamePhase.setup) state.phase = GamePhase.rolling;
    // Older snapshots could save a rolled die with a rolling phase.
    if (state.phase == GamePhase.rolling && state.lastDiceRoll != null) {
      state.phase = GamePhase.moving;
    }
    state.repaint();
    if (runAI &&
        state.phase == GamePhase.moving &&
        state.validTokenMoves.isEmpty) {
      _turnTimer = Timer(displayDelay, _finishNoMoveTurn);
    } else {
      _tryAITurn();
    }
  }

  void _onStateChanged() {
    if (!runAI || _disposed || _isMovingStep || state.isGameOver) return;
    if (!state.isCurrentPlayerAI) return;

    // Rebuild the AI timer from the latest state after every mutation or sync.
    if (_turnTimer?.isActive ?? false) return;
    _tryAITurn();
  }

  /// Recover a saved/remote no-move turn when this client becomes authoritative.
  void recoverNoMoveTurn() {
    if (!runAI ||
        _disposed ||
        state.isGameOver ||
        state.phase != GamePhase.moving ||
        state.validTokenMoves.isNotEmpty) {
      return;
    }
    _turnTimer?.cancel();
    _turnTimer = Timer(displayDelay, _finishNoMoveTurn);
  }

  /// Human player rolls dice
  void rollDice() {
    if (state.phase != GamePhase.rolling || _isMovingStep) return;
    if (state.isCurrentPlayerAI) return;

    SoundService.playDiceRollSound();
    final value = state.rollDice();
    onDiceRoll?.call(value);
    onMoveComplete?.call();

    // GameState already advanced after the third consecutive six.
    if (state.phase == GamePhase.rolling) {
      _tryAITurn();
      return;
    }

    if (state.validTokenMoves.isEmpty) {
      // No valid moves — display rolled dice clearly for 1.2s before passing turn or re-rolling
      _turnTimer?.cancel();
      _turnTimer = Timer(const Duration(milliseconds: 1200), () {
        if (_disposed || state.isGameOver) return;
        // Ludo King: If you roll a 6 but have no valid moves, you still get the extra roll.
        // However, to prevent infinite loops if the state gets stuck, we ensure
        // the turn advances if no tokens are even on the board or reachable.
        if (state.getsExtraRoll &&
            state.consecutiveSixes < maxConsecutiveSixes) {
          state.phase = GamePhase.rolling;
          state.lastDiceRoll = null;
          state.validTokenMoves = [];
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
        // ponytail: re-validate — a new roll (e.g. from 6 re-roll) may have changed valid moves
        if (state.phase != GamePhase.moving) return;
        if (state.validTokenMoves.length != 1) {
          return; // multiple choices now, let player decide
        }
        if (!state.validTokenMoves.contains(autoTokenIndex)) return;
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
    if (state.phase != GamePhase.moving ||
        state.lastDiceRoll == null ||
        !state.validTokenMoves.contains(tokenIndex)) {
      return;
    }

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
    final capturedOpponents = state.findCapturedOpponents(
      playerIndex,
      tokenIndex,
    );

    if (capturedOpponents.isNotEmpty) {
      // Capture confirmed — grant extra turn immediately before the capture pause.
      state.getsExtraRoll = true;
      SoundService.playCaptureSound();

      // Keep the visual capture pause bounded. Walking a captured token backward
      // along the track can take seconds and leaves the turn unavailable.
      Timer(const Duration(milliseconds: 280), () {
        if (_disposed) {
          _isMovingStep = false;
          return;
        }
        state.sendCapturedTokensHome(capturedOpponents);
        _isMovingStep = false;
        _finishMoveTurn(true);
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
    if (state.phase == GamePhase.moving) {
      if (state.validTokenMoves.isEmpty) {
        _turnTimer = Timer(displayDelay, _finishNoMoveTurn);
      } else {
        _turnTimer = Timer(const Duration(milliseconds: 1400), () {
          if (_disposed || state.isGameOver || !state.isCurrentPlayerAI) return;
          if (state.phase != GamePhase.moving ||
              state.validTokenMoves.isEmpty) {
            return;
          }
          _animateStepByStepMove(_ai.chooseToken(state));
        });
      }
      return;
    }

    if (state.phase != GamePhase.rolling) return;
    _turnTimer = Timer(const Duration(milliseconds: 1400), _executeAITurn);
  }

  void _finishNoMoveTurn() {
    if (_disposed ||
        state.isGameOver ||
        state.phase != GamePhase.moving ||
        state.validTokenMoves.isNotEmpty) {
      return;
    }
    if (state.getsExtraRoll && state.consecutiveSixes < maxConsecutiveSixes) {
      state.phase = GamePhase.rolling;
      state.lastDiceRoll = null;
      state.validTokenMoves = [];
      state.notifyChange();
      onMoveComplete?.call();
      _tryAITurn();
    } else {
      state.advanceTurn();
      onMoveComplete?.call();
      _tryAITurn();
    }
  }

  void _executeAITurn() {
    if (_disposed || state.isGameOver || _isMovingStep) return;
    if (!state.isCurrentPlayerAI) return;

    if (state.phase == GamePhase.rolling) {
      final value = state.rollDice();
      onDiceRoll?.call(value);
      onMoveComplete?.call();

      // GameState already advanced after the third consecutive six.
      if (state.phase == GamePhase.rolling) {
        _tryAITurn();
        return;
      }

      if (state.phase == GamePhase.moving && state.validTokenMoves.isNotEmpty) {
        // Show AI dice roll result for 1s before AI steps token
        _turnTimer?.cancel();
        _turnTimer = Timer(const Duration(milliseconds: 1400), () {
          if (_disposed || state.isGameOver) return;
          if (state.phase != GamePhase.moving ||
              state.validTokenMoves.isEmpty) {
            _finishNoMoveTurn();
            return;
          }
          final token = _ai.chooseToken(state);
          _animateStepByStepMove(token);
        });
      } else {
        // No valid moves — check extra roll or pass
        _turnTimer?.cancel();
        _turnTimer = Timer(displayDelay, () {
          if (_disposed || state.isGameOver) return;
          _finishNoMoveTurn();
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
    final totalPlayersCount = humanPlayers + aiPlayers;
    if (humanPlayers < 0 || aiPlayers < 0) {
      throw ArgumentError('Player counts cannot be negative.');
    }
    if (totalPlayersCount < 2 || totalPlayersCount > boardType.maxPlayers) {
      throw ArgumentError(
        'A ${boardType.label} game must have 2-${boardType.maxPlayers} players.',
      );
    }
    if (enableTeamUp &&
        (boardType != BoardType.classic4 || totalPlayersCount != 4)) {
      throw ArgumentError(
        'Team-up mode requires exactly four classic-board players.',
      );
    }

    final allColors = boardType == BoardType.classic4
        ? [
            PlayerColor.red,
            PlayerColor.green,
            PlayerColor.yellow,
            PlayerColor.blue,
          ]
        : PlayerColor.values;

    final players = <Player>[];
    final assignedColors = <PlayerColor>[];

    for (var i = 0; i < humanPlayers; i++) {
      final name =
          (humanNames != null &&
              i < humanNames.length &&
              humanNames[i].trim().isNotEmpty)
          ? humanNames[i].trim()
          : 'Player ${i + 1}';
      final color = (humanColors != null && i < humanColors.length)
          ? humanColors[i]
          : allColors[i % allColors.length];
      if (assignedColors.contains(color)) {
        throw ArgumentError('Each player must have a unique color.');
      }
      assignedColors.add(color);

      final teamId = enableTeamUp && totalPlayersCount == 4
          ? (i % 2 == 0 ? 0 : 1)
          : null;

      players.add(
        Player(
          id: 'human_$i',
          name: name,
          color: color,
          type: PlayerType.human,
          teamId: teamId,
        ),
      );
    }

    final remainingColors = allColors
        .where((c) => !assignedColors.contains(c))
        .toList();
    for (var i = 0; i < aiPlayers; i++) {
      final playerIndex = humanPlayers + i;
      final color = i < remainingColors.length
          ? remainingColors[i]
          : allColors[playerIndex % allColors.length];

      final teamId = enableTeamUp && totalPlayersCount == 4
          ? (playerIndex % 2 == 0 ? 0 : 1)
          : null;

      players.add(
        Player(
          id: 'ai_$i',
          name: 'Bot ${i + 1}',
          color: color,
          type: PlayerType.ai,
          difficulty: aiDifficulty,
          teamId: teamId,
        ),
      );
    }

    final state = GameState(
      boardType: boardType,
      players: players,
      enableJodi: enableJodi,
    );

    return GameService(state: state);
  }
}
