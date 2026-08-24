import 'package:flutter/material.dart';

import '../../services/game_service.dart';
import '../../services/online_service.dart';
import '../../services/local_game_storage.dart';
import '../../models/game_state.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../utils/constants.dart';
import '../theme.dart';
import '../widgets/player_avatar_widget.dart';
import 'game_screen.dart';
import 'lobby_screen.dart';
import 'notification_center_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BoardType _boardType = BoardType.classic4;

  // VS Computer state
  int _vsCompMatchSize = 4; // 2, 4, or 6
  AIDifficulty _vsCompDifficulty = AIDifficulty.medium;
  final TextEditingController _vsCompNameController = TextEditingController(
    text: 'Player 1',
  );
  PlayerColor _vsCompColor = PlayerColor.red;

  // Pass & Play state
  int _passPlayMatchSize = 4; // 2 or 4
  int _passPlayHumans = 2; // 2..match size
  bool _passPlayEnableTeamUp = false; // 2v2 team mode
  AIDifficulty _passPlayDifficulty = AIDifficulty.medium;

  final List<TextEditingController> _passPlayNameControllers = [
    TextEditingController(text: 'Player 1'),
    TextEditingController(text: 'Player 2'),
    TextEditingController(text: 'Player 3'),
    TextEditingController(text: 'Player 4'),
    TextEditingController(text: 'Player 5'),
    TextEditingController(text: 'Player 6'),
  ];

  final List<PlayerColor> _passPlayColors = [
    PlayerColor.red,
    PlayerColor.green,
    PlayerColor.yellow,
    PlayerColor.blue,
    PlayerColor.orange,
    PlayerColor.purple,
  ];

  GameState? _savedGame;

  @override
  void initState() {
    super.initState();
    _savedGame = LocalGameStorage.loadGame();
  }

  @override
  void dispose() {
    _vsCompNameController.dispose();
    for (final c in _passPlayNameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<int> _matchSizesForBoard(BoardType boardType) =>
      boardType == BoardType.classic4 ? [2, 4] : [2, 4, 6];

  void _normalizePassPlayColors() {
    final used = <PlayerColor>{};
    final palette = _boardType.availableColors;
    for (var i = 0; i < _passPlayColors.length && i < palette.length; i++) {
      var color = _passPlayColors[i];
      if (!palette.contains(color) || used.contains(color)) {
        color = palette.firstWhere((candidate) => !used.contains(candidate));
        _passPlayColors[i] = color;
      }
      used.add(color);
    }
  }

  void _setBoardType(StateSetter setModalState, BoardType boardType) {
    setModalState(() {
      _boardType = boardType;
      final sizes = _matchSizesForBoard(boardType);
      if (!sizes.contains(_vsCompMatchSize)) {
        _vsCompMatchSize = sizes.last;
      }
      if (!sizes.contains(_passPlayMatchSize)) {
        _passPlayMatchSize = sizes.last;
      }
      _passPlayHumans = _passPlayHumans.clamp(2, _passPlayMatchSize);
      if (boardType != BoardType.classic4) {
        _passPlayEnableTeamUp = false;
      }
      _vsCompColor = boardType.availableColors.contains(_vsCompColor)
          ? _vsCompColor
          : boardType.availableColors.first;
      _normalizePassPlayColors();
    });
  }

  void _selectPassPlayColor(
    StateSetter setModalState,
    int index,
    PlayerColor newColor,
  ) {
    setModalState(() {
      final existingIndex = _passPlayColors.indexOf(newColor);
      if (existingIndex != -1 && existingIndex != index) {
        _passPlayColors[existingIndex] = _passPlayColors[index];
      }
      _passPlayColors[index] = newColor;
    });
  }

  void _startVsComputerGame() {
    final aiCount = _vsCompMatchSize - 1;

    final service = GameService.createLocalGame(
      boardType: _boardType,
      humanPlayers: 1,
      aiPlayers: aiCount,
      aiDifficulty: _vsCompDifficulty,
      humanNames: [_vsCompNameController.text],
      humanColors: [_vsCompColor],
      enableJodi: true,
    );

    _navigateToGame(service);
  }

  void _startPassAndPlayGame() {
    final totalInMatch = _passPlayMatchSize;
    final humanCount = _passPlayHumans.clamp(2, totalInMatch).toInt();
    final aiCount = totalInMatch - humanCount;

    final names = _passPlayNameControllers
        .take(humanCount)
        .map((c) => c.text)
        .toList();
    final colors = _passPlayColors.take(humanCount).toList();

    final service = GameService.createLocalGame(
      boardType: _boardType,
      humanPlayers: humanCount,
      aiPlayers: aiCount,
      aiDifficulty: _passPlayDifficulty,
      humanNames: names,
      humanColors: colors,
      enableJodi: true,
      enableTeamUp: totalInMatch == 4 && _passPlayEnableTeamUp,
    );

    _navigateToGame(service);
  }

  void _resumeSavedGame() {
    final savedGame = _savedGame;
    if (savedGame == null) return;
    _navigateToGame(GameService(state: savedGame));
  }

  void _navigateToGame(GameService service) {
    Navigator.of(context)
        .push(
          PageRouteBuilder(
            pageBuilder: (_, a1, a2) => GameScreen(service: service),
            transitionsBuilder: (_, animation, a2, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 350),
          ),
        )
        .then((_) {
          if (mounted) setState(() => _savedGame = LocalGameStorage.loadGame());
        });
  }

  // ── VS Computer Modal ──

  void _showVsComputerModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Icon(
                            Icons.smart_toy_rounded,
                            color: Color(0xFF00E5FF),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'VS Computer Setup',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white60,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBoardTypeSelector(
                        selected: _boardType,
                        onSelected: (boardType) =>
                            _setBoardType(setModalState, boardType),
                      ),
                      const SizedBox(height: 12),
                      _buildMatchSizeSelector(
                        selectedSize: _vsCompMatchSize,
                        sizes: _matchSizesForBoard(_boardType),
                        onSelected: (size) =>
                            setModalState(() => _vsCompMatchSize = size),
                      ),
                      const SizedBox(height: 12),
                      // Player 1 Name & Color
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: AppTheme.glassCard(),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 130,
                              height: 38,
                              child: TextField(
                                controller: _vsCompNameController,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Your Name',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.bg3,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: AppTheme.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: AppTheme.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF00E5FF),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildColorDropdown(
                                currentColor: _vsCompColor,
                                colors: _boardType.availableColors,
                                onChanged: (color) =>
                                    setModalState(() => _vsCompColor = color),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Bot Difficulty
                      _buildDifficultySelector(
                        selected: _vsCompDifficulty,
                        onSelected: (d) =>
                            setModalState(() => _vsCompDifficulty = d),
                      ),
                      const SizedBox(height: 20),
                      // Start Button
                      SizedBox(
                        width: double.infinity,
                        height: 68,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _startVsComputerGame();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text(
                                'START MATCH',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Pass & Play Modal ──

  void _showPassAndPlayModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isConfigurableMatch = _passPlayMatchSize > 2;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Icon(
                            Icons.people_alt_rounded,
                            color: Color(0xFFEC4899),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Pass & Play Setup',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white60,
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBoardTypeSelector(
                        selected: _boardType,
                        onSelected: (boardType) =>
                            _setBoardType(setModalState, boardType),
                      ),
                      const SizedBox(height: 12),
                      _buildMatchSizeSelector(
                        selectedSize: _passPlayMatchSize,
                        sizes: _matchSizesForBoard(_boardType),
                        onSelected: (size) => setModalState(() {
                          _passPlayMatchSize = size;
                          _passPlayHumans = _passPlayHumans.clamp(2, size);
                          if (size == 2) _passPlayHumans = 2;
                        }),
                      ),
                      const SizedBox(height: 12),
                      // Humans & Bots Stepper (for 4P mode)
                      if (isConfigurableMatch) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: AppTheme.glassCard(),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 18,
                                    color: AppTheme.success,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Real Humans',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  _stepperBtn(
                                    icon: Icons.remove_rounded,
                                    enabled: _passPlayHumans > 2,
                                    onTap: () =>
                                        setModalState(() => _passPlayHumans--),
                                  ),
                                  SizedBox(
                                    width: 28,
                                    child: Text(
                                      '$_passPlayHumans',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.success,
                                      ),
                                    ),
                                  ),
                                  _stepperBtn(
                                    icon: Icons.add_rounded,
                                    enabled:
                                        _passPlayHumans < _passPlayMatchSize,
                                    onTap: () =>
                                        setModalState(() => _passPlayHumans++),
                                  ),
                                ],
                              ),
                              if (_passPlayMatchSize - _passPlayHumans > 0) ...[
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Divider(
                                    color: AppTheme.border,
                                    height: 1,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.smart_toy_rounded,
                                      size: 18,
                                      color: AppTheme.accentLight,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Fill with Bots',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${_passPlayMatchSize - _passPlayHumans} Bots',
                                      style: TextStyle(
                                        color: AppTheme.accentLight,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Team Up (2v2) Switch
                      if (isConfigurableMatch &&
                          _boardType == BoardType.classic4) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: AppTheme.glassCard(),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.groups_rounded,
                                size: 18,
                                color: Color(0xFF00E5FF),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '2v2 Team Up Mode',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Team A (P1+P3) vs Team B (P2+P4)',
                                      style: TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _passPlayEnableTeamUp,
                                activeThumbColor: const Color(0xFF00E5FF),
                                onChanged: (val) => setModalState(
                                  () => _passPlayEnableTeamUp = val,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // Player Names & Colors
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: AppTheme.glassCard(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.palette_rounded,
                                  size: 16,
                                  color: AppTheme.accentLight,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Player Names & Colors',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Column(
                              children: List.generate(
                                isConfigurableMatch ? _passPlayHumans : 2,
                                (i) {
                                  final currentColor = _passPlayColors[i];

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 120,
                                          height: 36,
                                          child: TextField(
                                            controller:
                                                _passPlayNameControllers[i],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Player ${i + 1}',
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              filled: true,
                                              fillColor: AppTheme.bg3,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide(
                                                  color: AppTheme.border,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: BorderSide(
                                                  color: AppTheme.border,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFF00E5FF),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildColorDropdown(
                                            currentColor: currentColor,
                                            colors: _boardType.availableColors,
                                            onChanged: (color) =>
                                                _selectPassPlayColor(
                                                  setModalState,
                                                  i,
                                                  color,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isConfigurableMatch &&
                          (_passPlayMatchSize - _passPlayHumans > 0)) ...[
                        const SizedBox(height: 12),
                        _buildDifficultySelector(
                          selected: _passPlayDifficulty,
                          onSelected: (d) =>
                              setModalState(() => _passPlayDifficulty = d),
                        ),
                      ],
                      const SizedBox(height: 20),
                      // Start Button
                      SizedBox(
                        width: double.infinity,
                        height: 68,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _startPassAndPlayGame();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text(
                                'START MATCH',
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Main Non-Scrollable Build Method ──

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight =
        mediaQuery.size.height -
        mediaQuery.padding.top -
        mediaQuery.padding.bottom;
    final isCompact = screenHeight < 680;

    return Scaffold(
      body: Container(
        decoration: AppTheme.artisticBackground(),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: isCompact ? 12 : 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildHero(isCompact),
                    _buildThreeMainButtons(isCompact),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero Banner ──

  Widget _buildHero(bool isCompact) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            StreamBuilder<List<AppNotification>>(
              stream: NotificationService.instance.notificationsStream,
              builder: (context, snapshot) {
                final unread = NotificationService.instance.unreadCount;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationCenterScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.white70,
                      ),
                    ),
                    if (unread > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFEC4899), Color(0xFF7C3AED)],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
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
              },
            ),
          ],
        ),
        Image.asset(
          'assets/images/ludo_banner_logo.png',
          height: isCompact ? 110 : 150,
          fit: BoxFit.contain,
        ),
        const Text(
          'MY LUDO',
          style: TextStyle(fontSize: 1, color: Colors.transparent),
        ),
      ],
    );
  }

  // ── 3 Main Buttons ──

  Widget _buildThreeMainButtons(bool isCompact) {
    return Column(
      children: [
        if (_savedGame != null) ...[
          _buildMenuButtonCard(
            isCompact: isCompact,
            icon: Icons.play_circle_fill_rounded,
            title: 'RESUME GAME',
            subtitle:
                '${_savedGame!.currentPlayer.name}\'s turn • Saved in this browser',
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF0EA5E9)],
            ),
            glowColor: const Color(0xFF10B981),
            onTap: _resumeSavedGame,
          ),
          SizedBox(height: isCompact ? 12 : 16),
        ],
        // 1. VS COMPUTER
        _buildMenuButtonCard(
          isCompact: isCompact,
          icon: Icons.smart_toy_rounded,
          title: 'VS COMPUTER',
          subtitle: 'Single Player vs Bots (2, 4, or 6 Players)',
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
          ),
          glowColor: const Color(0xFF8B5CF6),
          onTap: _showVsComputerModal,
        ),
        SizedBox(height: isCompact ? 12 : 16),
        // 2. PASS & PLAY
        _buildMenuButtonCard(
          isCompact: isCompact,
          icon: Icons.people_alt_rounded,
          title: 'PASS & PLAY',
          subtitle: 'Local Friends, Bots, 2v2 Teams & Star 6',
          gradient: AppTheme.primaryGradient,
          glowColor: const Color(0xFFEC4899),
          onTap: _showPassAndPlayModal,
        ),
        SizedBox(height: isCompact ? 12 : 16),
        // 3. PLAY ONLINE
        _buildMenuButtonCard(
          isCompact: isCompact,
          icon: Icons.public_rounded,
          title: 'PLAY ONLINE',
          subtitle: 'Multiplayer Rooms & Live Chat',
          isOutline: true,
          borderColor: const Color(0xFF00E5FF),
          glowColor: const Color(0xFF00E5FF),
          onTap: _showPlayOnlineModal,
        ),
      ],
    );
  }

  void _showPlayOnlineModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final onlineService = OnlineService();
        int activeTab = 0;
        int avatarIndex = 0;
        BoardType selectedBoardType = _boardType;
        PlayerColor selectedColor = selectedBoardType.availableColors.first;
        int matchSize = 4;
        bool enableTeamUp = false;
        bool isSubmitting = false;
        final nameController = TextEditingController(text: 'Player 1');
        final codeController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          const Icon(
                            Icons.public_rounded,
                            color: Color(0xFF00E5FF),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Play Online Setup',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white60,
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.pop(ctx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildBoardTypeSelector(
                        selected: selectedBoardType,
                        onSelected: (boardType) => setModalState(() {
                          selectedBoardType = boardType;
                          final sizes = _matchSizesForBoard(boardType);
                          if (!sizes.contains(matchSize)) {
                            matchSize = sizes.last;
                          }
                          if (!boardType.availableColors.contains(
                            selectedColor,
                          )) {
                            selectedColor = boardType.availableColors.first;
                          }
                          if (boardType != BoardType.classic4) {
                            enableTeamUp = false;
                          }
                        }),
                      ),
                      const SizedBox(height: 12),

                      // Avatar Selector
                      _buildModalAvatarPicker(
                        selectedIndex: avatarIndex,
                        onSelected: isSubmitting
                            ? (_) {}
                            : (idx) => setModalState(() => avatarIndex = idx),
                      ),
                      const SizedBox(height: 12),

                      // Player Name & Color Dropdown
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: AppTheme.glassCard(),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 130,
                              height: 38,
                              child: TextField(
                                controller: nameController,
                                enabled: !isSubmitting,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Your Name',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.bg3,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: AppTheme.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: AppTheme.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF00E5FF),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildColorDropdown(
                                currentColor: selectedColor,
                                colors: selectedBoardType.availableColors,
                                onChanged: isSubmitting
                                    ? (_) {}
                                    : (color) => setModalState(
                                        () => selectedColor = color,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tab Segment Switcher (CREATE ROOM | JOIN ROOM)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.bg3,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: isSubmitting
                                    ? null
                                    : () => setModalState(() => activeTab = 0),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: activeTab == 0
                                        ? AppTheme.primaryGradient
                                        : null,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'CREATE ROOM',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: activeTab == 0
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: isSubmitting
                                    ? null
                                    : () => setModalState(() => activeTab = 1),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: activeTab == 1
                                        ? AppTheme.primaryGradient
                                        : null,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'JOIN ROOM',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: activeTab == 1
                                          ? Colors.white
                                          : Colors.white70,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (activeTab == 0) ...[
                        // CREATE ROOM TAB CONTENT
                        _buildMatchSizeSelector(
                          selectedSize: matchSize,
                          sizes: _matchSizesForBoard(selectedBoardType),
                          onSelected: isSubmitting
                              ? (_) {}
                              : (size) => setModalState(() => matchSize = size),
                        ),
                        if (matchSize == 4) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.groups_rounded,
                                size: 18,
                                color: Color(0xFF00E5FF),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '2v2 Team Up Mode',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Switch(
                                value: enableTeamUp,
                                activeThumbColor: const Color(0xFF00E5FF),
                                onChanged: isSubmitting
                                    ? null
                                    : (val) => setModalState(
                                        () => enableTeamUp = val,
                                      ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 68,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    setModalState(() => isSubmitting = true);
                                    final name =
                                        nameController.text.trim().isEmpty
                                        ? 'Player 1'
                                        : nameController.text.trim();
                                    try {
                                      final room = await onlineService
                                          .createRoom(
                                            playerName: name,
                                            boardType: selectedBoardType,
                                            preferredColor: selectedColor,
                                            avatarIndex: avatarIndex,
                                            targetPlayerCount: matchSize,
                                            isTeamUp:
                                                matchSize == 4 && enableTeamUp,
                                          );
                                      if (context.mounted) {
                                        Navigator.pop(ctx);
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => LobbyScreen(
                                              initialRoom: room,
                                              onlineService: onlineService,
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        setModalState(
                                          () => isSubmitting = false,
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Unable to create room: $e',
                                            ),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                      onlineService.dispose();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'CREATE & START',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2.0,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // JOIN ROOM TAB CONTENT
                        TextField(
                          controller: codeController,
                          enabled: !isSubmitting,
                          style: const TextStyle(
                            color: Colors.white,
                            letterSpacing: 6,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          textCapitalization: TextCapitalization.characters,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          decoration: InputDecoration(
                            hintText: 'ROOM CODE',
                            hintStyle: TextStyle(
                              color: AppTheme.textMuted,
                              letterSpacing: 2,
                              fontSize: 13,
                            ),
                            counterText: '',
                            filled: true,
                            fillColor: AppTheme.bg3,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF00E5FF),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 68,
                          child: ElevatedButton(
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final name =
                                        nameController.text.trim().isEmpty
                                        ? 'Player 1'
                                        : nameController.text.trim();
                                    final code = codeController.text
                                        .trim()
                                        .toUpperCase();
                                    if (code.length != 6) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Enter a 6-character room code',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setModalState(() => isSubmitting = true);
                                    try {
                                      final res = await onlineService
                                          .joinRoomResult(
                                            code: code,
                                            playerName: name,
                                            avatarIndex: avatarIndex,
                                            preferredColor: selectedColor,
                                          );
                                      if (res.isSuccess &&
                                          res.room != null &&
                                          context.mounted) {
                                        Navigator.pop(ctx);
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => LobbyScreen(
                                              initialRoom: res.room,
                                              onlineService: onlineService,
                                            ),
                                          ),
                                        );
                                      } else if (context.mounted) {
                                        setModalState(
                                          () => isSubmitting = false,
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              res.error ??
                                                  'Unable to join room.',
                                            ),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        setModalState(
                                          () => isSubmitting = false,
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Unable to join room: $e',
                                            ),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'JOIN ROOM',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2.0,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalAvatarPicker({
    required int selectedIndex,
    required ValueChanged<int> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Avatar',
          style: TextStyle(
            color: Color(0xFF8B949E),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: Avatars.list.length,
            itemBuilder: (context, idx) {
              final isSel = idx == selectedIndex;
              final avatar = Avatars.list[idx];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onSelected(idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel
                            ? const Color(0xFF00E5FF)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFF00E5FF,
                                ).withValues(alpha: 0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: PlayerAvatarWidget(
                      avatarIndex: idx,
                      size: 36,
                      borderColor: isSel ? const Color(0xFF00E5FF) : avatar.bg,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButtonCard({
    required bool isCompact,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Gradient? gradient,
    bool isOutline = false,
    Color? borderColor,
    required Color glowColor,
  }) {
    return Container(
      width: double.infinity,
      height: isCompact ? 60 : 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: isOutline ? null : gradient,
        border: isOutline ? Border.all(color: borderColor!, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: isOutline ? 0.2 : 0.4),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isOutline ? borderColor : Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isOutline ? borderColor : Colors.white,
                          fontSize: isCompact ? 15 : 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isOutline
                              ? Colors.white70
                              : Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isOutline ? borderColor : Colors.white70,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Shared Reusable Config Widgets ──

  Widget _buildBoardTypeSelector({
    required BoardType selected,
    required ValueChanged<BoardType> onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Board',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: BoardType.values.map((boardType) {
              final isSelected = selected == boardType;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => onSelected(boardType),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppTheme.primaryGradient : null,
                        color: isSelected ? null : AppTheme.bg3,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accentLight
                              : AppTheme.border,
                        ),
                      ),
                      child: Text(
                        boardType == BoardType.classic4
                            ? 'Classic 4'
                            : 'Star 6',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchSizeSelector({
    required int selectedSize,
    required List<int> sizes,
    required ValueChanged<int> onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Match Size',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: sizes.map((size) {
              final isSelected = selectedSize == size;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => onSelected(size),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppTheme.primaryGradient : null,
                        color: isSelected ? null : AppTheme.bg3,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accentLight
                              : AppTheme.border,
                        ),
                      ),
                      child: Text(
                        '$size Players',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildColorDropdown({
    required PlayerColor currentColor,
    List<PlayerColor>? colors,
    required ValueChanged<PlayerColor> onChanged,
  }) {
    final palette = colors ?? PlayerColor.values;
    final safeCurrentColor = palette.contains(currentColor)
        ? currentColor
        : palette.first;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PlayerColor>(
          value: safeCurrentColor,
          isExpanded: true,
          menuMaxHeight: 260,
          dropdownColor: AppTheme.surface,
          icon: const Icon(
            Icons.arrow_drop_down_rounded,
            color: Colors.white70,
          ),
          items: palette.map((color) {
            return DropdownMenuItem<PlayerColor>(
              value: color,
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.color,
                      border: Border.all(color: Colors.white38),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    color.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  Widget _buildDifficultySelector({
    required AIDifficulty selected,
    required ValueChanged<AIDifficulty> onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: AppTheme.glassCard(),
      child: Row(
        children: [
          Icon(Icons.psychology_rounded, size: 16, color: AppTheme.warning),
          const SizedBox(width: 8),
          Text(
            'Bot Level',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: AIDifficulty.values.map((d) {
                final isSel = selected == d;
                final diffColors = {
                  AIDifficulty.easy: AppTheme.success,
                  AIDifficulty.medium: AppTheme.warning,
                  AIDifficulty.hard: AppTheme.danger,
                };
                final color = diffColors[d]!;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () => onSelected(d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel
                              ? color.withValues(alpha: 0.15)
                              : AppTheme.bg3,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel
                                ? color.withValues(alpha: 0.6)
                                : AppTheme.border,
                          ),
                        ),
                        child: Text(
                          d.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSel ? color : AppTheme.textSecondary,
                            fontWeight: isSel
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.surfaceLight : AppTheme.bg2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? AppTheme.borderLight : AppTheme.border,
          ),
        ),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
        ),
      ),
    );
  }
}
