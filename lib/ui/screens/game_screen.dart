import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

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
import '../../services/notification_service.dart';
import '../../models/app_notification.dart';
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
  late final ConfettiController _emojiConfetti;
  StreamSubscription<RoomData>? _roomSubscription;
  StreamSubscription<List<ChatMessage>>? _chatSubscription;
  int _seenChatCount = 0;
  int _unreadChatCount = 0;
  String? _bannerText;
  Timer? _bannerTimer;
  Timer? _emojiTimer;
  List<String> _knownRoomPlayerIds = [];
  bool _leaveHandled = false;
  static const List<String> _turnEmojis = ['🎲', '⚡', '🔥', '👊', '🏆'];
  int? _lastEmojiSeenAt;

  /// Whether the local player is the one whose turn it is
  bool get _isLocalPlayerTurn {
    if (widget.localPlayerId == null) return true; // offline game
    return state.currentPlayer.id == widget.localPlayerId;
  }

  bool get _isOnline => widget.onlineService != null;

  double get _boardRotation {
    if (widget.localPlayerId == null) return 0;
    final index = state.players.indexWhere((p) => p.id == widget.localPlayerId);
    if (index < 0) return 0;
    // ponytail: rotation is index-based so player's base is always facing them at bottom-left
    return -index * pi / 2;
  }

  @override
  void initState() {
    super.initState();
    _emojiConfetti = ConfettiController(duration: const Duration(seconds: 2));
    _turnGlow = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    state.addListener(_onStateChange);
    widget.service.onMoveComplete = _syncToFirebase;
    widget.service.start();
    _knownRoomPlayerIds = state.players.map((p) => p.id).toList();

    // Online: listen for remote game state updates & room events
    if (_isOnline) {
      _roomSubscription = widget.onlineService!.roomStream.listen((room) {
        if (!mounted) return;
        _handleRoomRosterChange(room);
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
              _unreadChatCount++;
              _showChatToast(msg);
            }
          }
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _turnGlow.dispose();
    _emojiConfetti.dispose();
    state.removeListener(_onStateChange);
    _roomSubscription?.cancel();
    _chatSubscription?.cancel();
    _bannerTimer?.cancel();
    _emojiTimer?.cancel();
    widget.service.dispose();
    super.dispose();
  }

  bool _dialogShown = false;

  void _onStateChange() {
    if (mounted) {
      _syncEmojiLifecycle();
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

  void _handleRoomRosterChange(RoomData room) {
    if (_isOnline) {
      widget.service.runAI = (widget.onlineService!.localPlayerId == room.hostId);
    }

    final incomingIds = room.players.map((p) => p.id).toList();
    final removedIds = _knownRoomPlayerIds.where((id) => !incomingIds.contains(id)).toList();
    if (removedIds.isEmpty) {
      _knownRoomPlayerIds = incomingIds;
      return;
    }

    for (final removedId in removedIds) {
      final removedPlayer = state.players.where((p) => p.id == removedId).toList();
      if (removedPlayer.isNotEmpty) {
        final name = removedPlayer.first.name;
        state.removePlayerById(removedId);
        _showInlineBanner('$name left the game');
        NotificationService.instance.push(
          AppNotification(
            id: 'leave_${DateTime.now().millisecondsSinceEpoch}_$removedId',
            title: 'Player Left',
            body: '$name left the game',
            category: 'game',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
          showSystem: false,
        );
        _syncToFirebase();
      }
    }

    _knownRoomPlayerIds = incomingIds;

    if (_isOnline && state.players.length <= 1 && !_leaveHandled) {
      _leaveHandled = true;
      _showInlineBanner('Players left. Match closed.');
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  void _showInlineBanner(String text) {
    _bannerTimer?.cancel();
    setState(() => _bannerText = text);
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _bannerText = null);
    });
  }

  /// Sync local state to Firebase after an action
  void _showChatToast(ChatMessage msg) {
    NotificationService.instance.push(
      AppNotification(
        id: 'chat_${msg.timestamp}_${msg.senderId}',
        title: msg.senderName,
        body: msg.text,
        category: 'social',
        timestamp: msg.timestamp,
      ),
      showSystem: false,
    );
    _showInlineBanner('${msg.senderName}: ${msg.text}');
  }

  void _syncEmojiLifecycle() {
    if (state.activeEmoji == null) {
      _emojiTimer?.cancel();
      _lastEmojiSeenAt = null;
      return;
    }

    if (_lastEmojiSeenAt == state.activeEmojiAt && (_emojiTimer?.isActive ?? false)) {
      return;
    }

    _lastEmojiSeenAt = state.activeEmojiAt;
    _emojiTimer?.cancel();
    _emojiConfetti.play();

    _emojiTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || state.activeEmoji == null) return;
      if (widget.localPlayerId != null && state.currentPlayer.id != widget.localPlayerId) {
        return;
      }
      state.activeEmoji = null;
      state.activeEmojiPlayerIndex = null;
      state.activeEmojiAt = null;
      state.notifyChange();
      _syncToFirebase();
    });
  }

  void _syncToFirebase() {
    if (_isOnline) {
      widget.onlineService!.syncGameState(state);
    }
  }

  void _chooseEmoji(String emoji) {
    if (!mounted || state.isGameOver) return;
    if (widget.localPlayerId != null && state.currentPlayer.id != widget.localPlayerId) return;
    if (state.activeEmoji != null) return;
    if (state.setTurnEmoji(emoji)) {
      _emojiConfetti.play();
      _syncToFirebase();
      _showInlineBanner('${state.currentPlayer.name} sent $emoji');
    }
  }

  void _onDiceRoll() {
    if (!_isLocalPlayerTurn) return;
    widget.service.rollDice();
  }

  void _onTokenTap(int tokenIndex) {
    if (!_isLocalPlayerTurn) return;
    widget.service.selectToken(tokenIndex);
    // Sync will happen after animation completes via _finishMoveTurn
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
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
          if (state.activeEmoji != null) _buildEmojiOverlay(),
          IgnorePointer(
            child: SafeArea(
              child: AnimatedSlide(
                offset: _bannerText == null ? const Offset(0, -0.2) : Offset.zero,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _bannerText == null ? 0 : 1,
                  duration: const Duration(milliseconds: 240),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF111827), Color(0xFF1F2937)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.45)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF00E5FF), Color(0xFFEC4899)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _bannerText ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(BoxConstraints constraints) {
    // ponytail: height-aware layout for small phones
    final isCompact = constraints.maxHeight < 700;
    final controlPanelHeight = isCompact ? 160.0 : 220.0;
    final maxAvailableWidth = constraints.maxWidth - 24;
    final maxAvailableHeight = constraints.maxHeight - controlPanelHeight - 60;
    final boardSize = min(maxAvailableWidth, maxAvailableHeight).clamp(200.0, 600.0);

    return Column(
      children: [
        _buildTopBar(),
        if (!isCompact) const SizedBox(height: 8),
        Expanded(
          child: Center(child: _buildBoard(boardSize)),
        ),
        _buildControlPanel(isCompact: isCompact),
        SizedBox(height: isCompact ? 4 : 8),
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
            _chatIconBtn()
          else
            _iconBtn(Icons.refresh_rounded, _showRestartDialog),
        ],
      ),
    );
  }

  Widget _chatIconBtn() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _iconBtn(Icons.chat_bubble_outline_rounded, () {
          _unreadChatCount = 0;
          setState(() {});
          final myName = state.players
              .firstWhere((p) => p.id == widget.localPlayerId,
                  orElse: () => state.players.first)
              .name;
          OnlineChatWidget.showChatModal(context, widget.onlineService!, myName);
        }),
        if (_unreadChatCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                _unreadChatCount > 9 ? '9+' : '$_unreadChatCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
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
      // ponytail: use playerIndex directly — basePosition/homeStretchPosition are index-based
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

  Widget _buildControlPanel({bool isCompact = false}) {
    final isMyTurn = widget.localPlayerId == null ||
        state.currentPlayer.id == widget.localPlayerId;

    final canRoll = state.phase == GamePhase.rolling &&
        !state.isCurrentPlayerAI &&
        !state.isGameOver &&
        isMyTurn;

    final activePlayerColor = state.currentPlayer.color.color;
    // ponytail: compact sizing for small phones
    final diceSize = isCompact ? 48.0 : 64.0;
    final panelPadding = isCompact ? 8.0 : 14.0;
    final avatarSize = isCompact ? 24.0 : 32.0;
    final statusFontSize = isCompact ? 12.0 : 14.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: EdgeInsets.all(panelPadding),
        decoration: AppTheme.glassCard(
          glowColor: canRoll ? activePlayerColor : null,
        ),
        child: isCompact
            // ponytail: compact two-row layout for small phones
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      PlayerAvatarWidget(
                        avatarIndex: state.currentPlayer.avatarIndex,
                        size: avatarSize,
                        borderColor: activePlayerColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                _statusText(),
                                key: ValueKey(_statusText()),
                                style: TextStyle(
                                  color: state.isGameOver
                                      ? AppTheme.gold
                                      : AppTheme.textPrimary,
                                  fontSize: statusFontSize,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _buildCompactHint(canRoll, activePlayerColor),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      DiceWidget(
                        value: state.lastDiceRoll,
                        canRoll: canRoll,
                        color: activePlayerColor,
                        onRoll: _onDiceRoll,
                        size: diceSize,
                      ),
                      if (state.isGameOver) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: () {
                              state.reset();
                              widget.service.start();
                            },
                            child: const Text('REPLAY', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  _buildCompactEmojiStrip(canRoll),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Active player avatar & Status header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PlayerAvatarWidget(
                        avatarIndex: state.currentPlayer.avatarIndex,
                        size: avatarSize,
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
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: state.isGameOver
                                  ? AppTheme.gold
                                  : AppTheme.textPrimary,
                              fontSize: statusFontSize,
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
                    size: diceSize,
                  ),
                  const SizedBox(height: 10),
                  _buildEmojiStrip(canRoll),
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

  // ponytail: compact hint for small phone layout
  Widget _buildCompactHint(bool canRoll, Color activePlayerColor) {
    if (canRoll && state.lastDiceRoll == null) {
      return Text(
        'Tap dice to roll',
        style: TextStyle(color: activePlayerColor, fontSize: 10, fontWeight: FontWeight.w600),
      );
    } else if (state.phase == GamePhase.moving && !state.isCurrentPlayerAI) {
      return Text(
        'Select a token',
        style: TextStyle(color: activePlayerColor, fontSize: 10, fontWeight: FontWeight.w600),
      );
    }
    return const SizedBox.shrink();
  }

  // ponytail: compact emoji row for small phones — high visibility buttons with distinct touch targets
  Widget _buildCompactEmojiStrip(bool canRollNow) {
    final active = state.activeEmoji;
    final canPick = !state.isGameOver &&
        active == null &&
        (_isOnline
            ? (widget.localPlayerId == null || state.currentPlayer.id == widget.localPlayerId)
            : !state.isCurrentPlayerAI);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _turnEmojis.map((emoji) {
          final isSelected = active == emoji;
          return GestureDetector(
            onTap: canPick ? () => _chooseEmoji(emoji) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFEC4899)])
                    : LinearGradient(colors: [AppTheme.bg3, AppTheme.surface]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF00E5FF)
                      : (canPick ? AppTheme.accentLight.withValues(alpha: 0.5) : AppTheme.border),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: canPick
                    ? [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmojiStrip(bool canUseNow) {
    final active = state.activeEmoji;
    final canPickEmoji = !state.isGameOver &&
        active == null &&
        (_isOnline
            ? (widget.localPlayerId == null || state.currentPlayer.id == widget.localPlayerId)
            : !state.isCurrentPlayerAI);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_emotions_outlined, size: 16, color: AppTheme.accentLight),
            const SizedBox(width: 6),
            Text(
              'Turn emoji',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            if (active != null)
              Text(active, style: const TextStyle(fontSize: 18)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _turnEmojis.map((emoji) {
            final isSelected = active == emoji;
            return GestureDetector(
              onTap: canPickEmoji ? () => _chooseEmoji(emoji) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFEC4899)])
                      : null,
                  color: isSelected ? null : AppTheme.bg3,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00E5FF)
                        : AppTheme.border,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      canPickEmoji ? 'Tap' : 'Locked',
                      style: TextStyle(
                        color: canPickEmoji ? Colors.white : AppTheme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmojiOverlay() {
    final emoji = state.activeEmoji ?? '🎉';
    final name = state.activeEmojiPlayerIndex != null && state.activeEmojiPlayerIndex! < state.players.length
        ? state.players[state.activeEmojiPlayerIndex!].name
        : state.currentPlayer.name;

    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0B1020).withValues(alpha: 0.22),
                const Color(0xFF7C3AED).withValues(alpha: 0.16),
                const Color(0xFFEC4899).withValues(alpha: 0.20),
              ],
            ),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _emojiConfetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0.08,
                  numberOfParticles: 35,
                  gravity: 0.18,
                  maxBlastForce: 28,
                  minBlastForce: 12,
                  colors: const [
                    Color(0xFF00E5FF),
                    Color(0xFFEC4899),
                    Color(0xFFFFD700),
                    Color(0xFF7C3AED),
                    Color(0xFF10B981),
                    Colors.white,
                  ],
                ),
              ),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.78, end: 1.0),
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF111827), Color(0xFF1F2937)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 92)),
                        const SizedBox(height: 12),
                        Text(
                          '$name selected an emoji',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'emoji moment',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText() {
    if (state.isGameOver) {
      return '${state.players[state.winner!].name} wins the game!';
    }
    final name = state.currentPlayer.name;
    if (state.isCurrentPlayerAI) return '$name (AI) is thinking... ${state.activeEmoji ?? '🤖'}';

    switch (state.phase) {
      case GamePhase.rolling:
        if (state.consecutiveSixes > 0) {
          return '$name rolled ${state.consecutiveSixes}× sixes! Roll again! ${state.activeEmoji ?? '🎲'}';
        }
        return '$name\'s turn ${state.activeEmoji ?? '🎯'}';
      case GamePhase.moving:
        return '$name rolled ${state.lastDiceRoll} ${state.activeEmoji ?? '🎲'}';
      default:
        return '$name\'s turn ${state.activeEmoji ?? '🎯'}';
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
            onPressed: () async {
              Navigator.pop(ctx);
              if (_isOnline) {
                await widget.onlineService?.leaveRoom();
              }
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
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
