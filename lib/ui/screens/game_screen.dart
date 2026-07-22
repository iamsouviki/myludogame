import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/board_config.dart';
import '../../models/game_state.dart';
import '../../services/game_service.dart';
import '../../utils/constants.dart';
import '../theme.dart';
import '../widgets/board_painter.dart';
import '../widgets/dice_widget.dart';
import '../widgets/player_avatar_widget.dart';
import '../widgets/token_widget.dart';

class GameScreen extends StatefulWidget {
  final GameService service;
  final String? localPlayerId;

  const GameScreen({super.key, required this.service, this.localPlayerId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  GameState get state => widget.service.state;
  late AnimationController _turnGlow;

  @override
  void initState() {
    super.initState();
    _turnGlow = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    state.addListener(_onStateChange);
    widget.service.start();
  }

  @override
  void dispose() {
    _turnGlow.dispose();
    state.removeListener(_onStateChange);
    widget.service.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  void _onDiceRoll() => widget.service.rollDice();
  void _onTokenTap(int tokenIndex) => widget.service.selectToken(tokenIndex);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.artisticBackground(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return isWide
                  ? _buildWideLayout(constraints)
                  : _buildNarrowLayout(constraints);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowLayout(BoxConstraints constraints) {
    final maxAvailableWidth = constraints.maxWidth - 24;
    final maxAvailableHeight = constraints.maxHeight - 220;
    final boardSize = min(maxAvailableWidth, maxAvailableHeight).clamp(240.0, 600.0);

    return Column(
      children: [
        _buildTopBar(),
        const SizedBox(height: 8),
        Expanded(
          child: Center(child: _buildBoard(boardSize)),
        ),
        _buildControlPanel(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildWideLayout(BoxConstraints constraints) {
    final maxAvailableWidth = constraints.maxWidth - 320;
    final maxAvailableHeight = constraints.maxHeight - 40;
    final boardSize = min(maxAvailableWidth, maxAvailableHeight).clamp(300.0, 750.0);

    return Row(
      children: [
        SizedBox(
          width: 280,
          child: Column(
            children: [
              _buildTopBar(),
              const Spacer(),
              _buildControlPanel(),
              const SizedBox(height: 16),
            ],
          ),
        ),
        Expanded(child: Center(child: _buildBoard(boardSize))),
      ],
    );
  }

  // ── Top bar ──

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _iconBtn(Icons.arrow_back_rounded, _showExitDialog),
          const Spacer(),
          if (state.isGameOver)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gold.withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Text(
                '🏆 GAME OVER',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            )
          else
            Text(
              'MY LUDO',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          const Spacer(),
          _iconBtn(Icons.refresh_rounded, _showRestartDialog),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, color: AppTheme.textSecondary, size: 20),
      ),
    );
  }

  // ── Board ──

  Widget _buildBoard(double maxSize) {
    final size = Size(maxSize, maxSize);
    final config = BoardConfig(boardType: state.boardType, canvasSize: size);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        children: [
          CustomPaint(
            size: size,
            painter: BoardPainter(state: state, config: config),
          ),
          ..._buildTokens(config),
        ],
      ),
    );
  }

  List<Widget> _buildTokens(BoardConfig config) {
    final tokens = <Widget>[];
    final defaultTokenSize = config.cellSize * 0.7;

    for (var p = 0; p < state.players.length; p++) {
      for (var t = 0; t < tokensPerPlayer; t++) {
        final pos = state.tokenPositions[p][t];
        if (pos == posHome) continue;

        Offset pixelPos;
        bool isInBase = false;
        double tokenSize = defaultTokenSize;

        if (pos == posInBase) {
          pixelPos = config.basePosition(p, t);
          isInBase = true;
        } else if (pos >= state.boardType.trackLength) {
          final stepsIntoHome = pos - state.boardType.trackLength;
          pixelPos = config.homeStretchPosition(p, stepsIntoHome);
        } else {
          pixelPos = config.trackCellPosition(pos);

          // Find all tokens on this cell
          final cellTokens = <_TokenRef>[];
          for (var pIdx = 0; pIdx < state.players.length; pIdx++) {
            for (var tIdx = 0; tIdx < tokensPerPlayer; tIdx++) {
              if (state.tokenPositions[pIdx][tIdx] == pos) {
                cellTokens.add(_TokenRef(pIdx, tIdx, pos));
              }
            }
          }

          // Build list of distinct player colors present on this cell
          final distinctPlayerTokens = <_TokenRef>[];
          final seenPlayers = <int>{};
          for (final ref in cellTokens) {
            if (!seenPlayers.contains(ref.playerIndex)) {
              seenPlayers.add(ref.playerIndex);
              distinctPlayerTokens.add(ref);
            }
          }

          // If this token is NOT the representative token for its player color on this cell, skip rendering
          final isRepresentative = distinctPlayerTokens.any((ref) => ref.playerIndex == p && ref.tokenIndex == t);
          if (!isRepresentative) continue;

          if (distinctPlayerTokens.length > 1) {
            tokenSize = config.cellSize * 0.48;
            final myColorIndex = distinctPlayerTokens.indexWhere((ref) => ref.playerIndex == p);

            final offsets = [
              Offset(-config.cellSize * 0.2, -config.cellSize * 0.2),
              Offset(config.cellSize * 0.2, -config.cellSize * 0.2),
              Offset(-config.cellSize * 0.2, config.cellSize * 0.2),
              Offset(config.cellSize * 0.2, config.cellSize * 0.2),
            ];

            pixelPos += offsets[myColorIndex % offsets.length];
          }
        }

        final isHighlighted = p == state.currentPlayerIndex &&
            state.phase == GamePhase.moving &&
            state.validTokenMoves.contains(t) &&
            !state.isCurrentPlayerAI;

        tokens.add(
          AnimatedPositioned(
            key: ValueKey('token_${p}_$t'),
            duration: const Duration(milliseconds: 120),
            curve: Curves.linear,
            left: pixelPos.dx - tokenSize / 2,
            top: pixelPos.dy - tokenSize / 2,
            child: TokenWidget(
              playerColor: state.players[p].color,
              size: tokenSize,
              isHighlighted: isHighlighted,
              isInBase: isInBase,
              onTap: isHighlighted ? () => _onTokenTap(t) : null,
            ),
          ),
        );
      }
    }
    return tokens;
  }

  // ── Control panel ──

  Widget _buildControlPanel() {
    final isMyTurn = widget.localPlayerId == null ||
        state.currentPlayer.id == widget.localPlayerId;

    final canRoll = state.phase == GamePhase.rolling &&
        !state.isCurrentPlayerAI &&
        !state.isGameOver &&
        isMyTurn;

    final activePlayerColor = state.currentPlayer.color.color;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassCard(
          glowColor: canRoll ? activePlayerColor : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Active player avatar & Status header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PlayerAvatarWidget(
                  avatarIndex: state.currentPlayer.avatarIndex,
                  size: 32,
                  borderColor: activePlayerColor,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _statusText(),
                      key: ValueKey(_statusText()),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: state.isGameOver
                            ? AppTheme.gold
                            : AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Dice Container
            DiceWidget(
              value: state.lastDiceRoll,
              canRoll: canRoll,
              color: activePlayerColor,
              onRoll: _onDiceRoll,
            ),
            // Hint text positioned strictly BELOW the dice container
            const SizedBox(height: 8),
            if (canRoll && state.lastDiceRoll == null)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: activePlayerColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: activePlayerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_rounded, size: 14, color: activePlayerColor),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to roll',
                      style: TextStyle(
                        color: activePlayerColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else if (state.phase == GamePhase.moving && !state.isCurrentPlayerAI)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: activePlayerColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: activePlayerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Select a token to move',
                  style: TextStyle(
                    color: activePlayerColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              )
            else
              const SizedBox(height: 24), // Reserve empty space while rolling or showing dice result

            if (state.isGameOver) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () {
                    state.reset();
                    widget.service.start();
                  },
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('PLAY AGAIN'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusText() {
    if (state.isGameOver) {
      return '🏆 ${state.players[state.winner!].name} wins the game!';
    }
    final name = state.currentPlayer.name;
    if (state.isCurrentPlayerAI) return '🤖 $name is thinking...';

    switch (state.phase) {
      case GamePhase.rolling:
        if (state.consecutiveSixes > 0) {
          return '🔥 $name rolled ${state.consecutiveSixes}× sixes! Roll again!';
        }
        return '$name\'s turn';
      case GamePhase.moving:
        return '$name rolled ${state.lastDiceRoll}';
      default:
        return '$name\'s turn';
    }
  }

  // ── Dialogs ──

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Game?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'Your progress will be lost.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Stay', style: TextStyle(color: AppTheme.accentLight)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Leave', style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restart Game?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              state.reset();
              widget.service.start();
            },
            child: Text('Restart', style: TextStyle(color: AppTheme.warning)),
          ),
        ],
      ),
    );
  }
}

class _TokenRef {
  final int playerIndex;
  final int tokenIndex;
  final int pos;

  _TokenRef(this.playerIndex, this.tokenIndex, this.pos);
}
