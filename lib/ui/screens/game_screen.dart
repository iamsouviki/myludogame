import 'dart:async';
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

import '../../services/online_service.dart';
import '../widgets/online_chat_widget.dart';

class GameScreen extends StatefulWidget {
  final GameService service;
  final String? localPlayerId;
  final OnlineService? onlineService;

  const GameScreen({
    super.key,
    required this.service,
    this.localPlayerId,
    this.onlineService,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  GameState get state => widget.service.state;
  late AnimationController _turnGlow;
  StreamSubscription<RoomData>? _roomSubscription;
  StreamSubscription<List<ChatMessage>>? _chatSubscription;
  int _seenChatCount = 0;

  /// Whether the local player is the one whose turn it is
  bool get _isLocalPlayerTurn {
    if (widget.localPlayerId == null) return true; // offline game
    return state.currentPlayer.id == widget.localPlayerId;
  }

  bool get _isOnline => widget.onlineService != null;

  double get _boardRotation {
    if (widget.localPlayerId == null) return 0;
    final index = state.players.indexWhere((p) => p.id == widget.localPlayerId);
    return index < 0 ? 0 : -index * pi / 2;
  }

  @override
  void initState() {
    super.initState();
    _turnGlow = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    state.addListener(_onStateChange);
    widget.service.onMoveComplete = _syncToFirebase;
    widget.service.start();

    // Online: listen for remote game state updates & room events
    if (_isOnline) {
      _roomSubscription = widget.onlineService!.roomStream.listen((room) {
        if (!mounted) return;
        if (room.gameState != null) {
          try {
            _onRemoteStateUpdate(room.gameState!);
          } catch (e) {
            debugPrint('[GameScreen] Ignoring invalid remote state: $e');
          }
        }
      });

      // ponytail: show toast for new chat messages from others
      _chatSubscription = widget.onlineService!.chatStream.listen((msgs) {
        if (!mounted) return;
        if (msgs.length > _seenChatCount) {
          final newMsgs = msgs.sublist(_seenChatCount);
          _seenChatCount = msgs.length;
          for (final msg in newMsgs) {
            if (msg.senderId != widget.localPlayerId) {
              _showChatToast(msg);
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _turnGlow.dispose();
    state.removeListener(_onStateChange);
    _roomSubscription?.cancel();
    _chatSubscription?.cancel();
    widget.service.dispose();
    super.dispose();
  }

  bool _dialogShown = false;

  void _onStateChange() {
    if (mounted) {
      setState(() {});
      if (state.isGameOver && !_dialogShown) {
        _dialogShown = true;
        if (_isOnline) {
          widget.onlineService!.storeFinishedMatch(state);
        }
        Future.microtask(() => _showVictoryModal());
      }
    }
  }

  /// Apply remote state from Firebase (for the non-active player's device)
  void _onRemoteStateUpdate(Map<String, dynamic> remoteState) {
    // Firebase is authoritative. Applying every update keeps both devices in sync.
    state.loadFromJson(remoteState);
  }

  /// Sync local state to Firebase after an action
  // ponytail: brief overlay toast for incoming chat
  void _showChatToast(ChatMessage msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.chat_bubble_rounded, color: Color(0xFF00E5FF), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '${msg.senderName}: ',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF00E5FF)),
                  ),
                  TextSpan(text: msg.text),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E2E),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OPEN',
          textColor: const Color(0xFFEC4899),
          onPressed: () {
            final myName = state.players
                .firstWhere((p) => p.id == widget.localPlayerId,
                    orElse: () => state.players.first)
                .name;
            OnlineChatWidget.showChatModal(context, widget.onlineService!, myName);
          },
        ),
      ),
    );
  }

  void _syncToFirebase() {
    if (_isOnline) {
      widget.onlineService!.syncGameState(state);
    }
  }

  void _onDiceRoll() {
    if (!_isLocalPlayerTurn) return;
    widget.service.rollDice();
    _syncToFirebase();
  }

  void _onTokenTap(int tokenIndex) {
    if (!_isLocalPlayerTurn) return;
    widget.service.selectToken(tokenIndex);
    // Sync will happen after animation completes via _finishMoveTurn
  }

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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.emoji_events_rounded, color: Colors.black87, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'GAME OVER',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'LUDOVERSE',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          const Spacer(),
          if (widget.onlineService != null)
            _iconBtn(Icons.chat_bubble_outline_rounded, () {
              final myName = state.players
                  .firstWhere((p) => p.id == widget.localPlayerId,
                      orElse: () => state.players.first)
                  .name;
              OnlineChatWidget.showChatModal(
                  context, widget.onlineService!, myName);
            })
          else
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
      child: Transform.rotate(
        angle: _boardRotation,
        alignment: Alignment.center,
        child: Stack(
          children: [
            CustomPaint(
              size: size,
              painter: BoardPainter(state: state, config: config),
            ),
            ..._buildTokens(config),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTokens(BoardConfig config) {
    final tokens = <Widget>[];
    final defaultTokenSize = config.cellSize * 0.7;

    for (var p = 0; p < state.players.length; p++) {
      for (var t = 0; t < tokensPerPlayer; t++) {
        final pos = state.tokenPositions[p][t];
        Offset pixelPos;
        bool isInBase = false;
        double tokenSize = defaultTokenSize;

        if (pos == posHome) {
          final homeCenter = config.homeStretchPosition(p, 5);
          final row = t ~/ 2;
          final col = t % 2;
          pixelPos = homeCenter + Offset(
            (col - 0.5) * (config.cellSize * 0.28),
            (row - 0.5) * (config.cellSize * 0.28),
          );
          tokenSize = config.cellSize * 0.48;
        } else if (pos == posInBase) {
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
      return '${state.players[state.winner!].name} wins the game!';
    }
    final name = state.currentPlayer.name;
    if (state.isCurrentPlayerAI) return '$name (AI) is thinking...';

    switch (state.phase) {
      case GamePhase.rolling:
        if (state.consecutiveSixes > 0) {
          return '$name rolled ${state.consecutiveSixes}× sixes! Roll again!';
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
              Navigator.of(context).popUntil((route) => route.isFirst);
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

  void _showVictoryModal() {
    final winnerIndex = state.winner ?? 0;
    final winnerPlayer = state.players[winnerIndex];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.accentLight.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/victory_crown.png',
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              Text(
                'CHAMPION!',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PlayerAvatarWidget(
                    avatarIndex: winnerPlayer.avatarIndex,
                    borderColor: winnerPlayer.color.color,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    winnerPlayer.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bg1,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: List.generate(state.finishOrder.length, (rank) {
                    final pIdx = state.finishOrder[rank];
                    final player = state.players[pIdx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            '#${rank + 1}',
                            style: TextStyle(
                              color: rank == 0 ? AppTheme.gold : AppTheme.textSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 10),
                          PlayerAvatarWidget(
                            avatarIndex: player.avatarIndex,
                            borderColor: player.color.color,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            player.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('HOME'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _dialogShown = false;
                        });
                        state.reset();
                        widget.service.start();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('PLAY AGAIN'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
