import 'package:flutter/material.dart';

import '../../services/game_service.dart';
import '../../utils/constants.dart';
import '../theme.dart';
import 'game_screen.dart';
import 'lobby_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BoardType _boardType = BoardType.classic4;
  int _humanPlayers = 1;
  int _aiPlayers = 1;
  AIDifficulty _aiDifficulty = AIDifficulty.medium;
  bool _enableJodi = true;

  final List<TextEditingController> _nameControllers = [
    TextEditingController(text: 'Player 1'),
    TextEditingController(text: 'Player 2'),
    TextEditingController(text: 'Player 3'),
    TextEditingController(text: 'Player 4'),
  ];

  final List<PlayerColor> _humanColors = [
    PlayerColor.red,
    PlayerColor.green,
    PlayerColor.yellow,
    PlayerColor.blue,
  ];

  int get _totalPlayers => _humanPlayers + _aiPlayers;
  int get _maxPlayers => _boardType.maxPlayers;

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _selectColorForPlayer(int playerIndex, PlayerColor newColor) {
    setState(() {
      final existingIndex = _humanColors.indexOf(newColor);
      if (existingIndex != -1 && existingIndex != playerIndex) {
        // Swap colors
        _humanColors[existingIndex] = _humanColors[playerIndex];
      }
      _humanColors[playerIndex] = newColor;
    });
  }

  void _startGame() {
    if (_totalPlayers < 2 || _totalPlayers > _maxPlayers) return;

    final names = _nameControllers.take(_humanPlayers).map((c) => c.text).toList();
    final colors = _humanColors.take(_humanPlayers).toList();

    final service = GameService.createLocalGame(
      boardType: _boardType,
      humanPlayers: _humanPlayers,
      aiPlayers: _aiPlayers,
      aiDifficulty: _aiDifficulty,
      humanNames: names,
      humanColors: colors,
      enableJodi: _enableJodi,
    );

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a1, a2) => GameScreen(service: service),
        transitionsBuilder: (_, animation, a2, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height - mediaQuery.padding.top - mediaQuery.padding.bottom;
    final isCompact = screenHeight < 740;

    return Scaffold(
      body: Container(
        decoration: AppTheme.artisticBackground(),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: isCompact ? 8 : 16,
                ),
                child: Column(
                  children: [
                    _buildHero(isCompact),
                    const SizedBox(height: 12),
                    _buildBoardTypeSelector(isCompact),
                    const SizedBox(height: 12),
                    _buildPlayerConfig(isCompact),
                    const SizedBox(height: 12),
                    _buildHumanPlayersCustomization(isCompact),
                    const SizedBox(height: 12),
                    _buildJodiOption(isCompact),
                    if (_aiPlayers > 0) ...[
                      const SizedBox(height: 12),
                      _buildDifficultySelector(isCompact),
                    ],
                    const SizedBox(height: 16),
                    _buildActionButtons(isCompact),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero title ──

  Widget _buildHero(bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 4 : 8),
      child: Image.asset(
        'assets/images/ludo_banner_logo.png',
        height: isCompact ? 80 : 110,
        fit: BoxFit.contain,
      ),
    );
  }

  // ── Board type selector (Disabled 6-Player Star Button) ──

  Widget _buildBoardTypeSelector(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 14),
      decoration: AppTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view_rounded, size: 16, color: AppTheme.accentLight),
              const SizedBox(width: 8),
              Text(
                'Board Type',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: isCompact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 8 : 12),
          Row(
            children: BoardType.values.map((type) {
              final isDisabled = type == BoardType.hex6;
              final selected = _boardType == type && !isDisabled;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: isDisabled
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('6-Player Star mode coming soon!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        : () {
                            setState(() {
                              if (_totalPlayers > type.maxPlayers) {
                                _aiPlayers = type.maxPlayers - _humanPlayers;
                                if (_aiPlayers < 0) {
                                  _humanPlayers = type.maxPlayers;
                                  _aiPlayers = 0;
                                }
                              }
                            });
                          },
                    child: Opacity(
                      opacity: isDisabled ? 0.45 : 1.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 12),
                        decoration: BoxDecoration(
                          gradient: selected
                              ? const LinearGradient(
                                  colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                                )
                              : null,
                          color: selected ? null : AppTheme.bg3,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppTheme.accentLight.withValues(alpha: 0.5)
                                : AppTheme.border,
                          ),
                          boxShadow: selected
                              ? [AppTheme.playerGlow(AppTheme.accent)]
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              type == BoardType.classic4 ? 'Classic' : 'Star',
                              style: TextStyle(
                                color: selected ? Colors.white : AppTheme.textSecondary,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              isDisabled ? 'Coming Soon' : '${type.maxPlayers} Players',
                              style: TextStyle(
                                color: selected ? Colors.white70 : (isDisabled ? AppTheme.warning : AppTheme.textMuted),
                                fontSize: 11,
                                fontWeight: isDisabled ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ],
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

  // ── Player count config ──

  Widget _buildPlayerConfig(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 14),
      decoration: AppTheme.glassCard(),
      child: Column(
        children: [
          _buildPlayerRow(
            icon: Icons.person_rounded,
            label: 'Humans',
            value: _humanPlayers,
            color: AppTheme.success,
            min: 1,
            max: _maxPlayers,
            isCompact: isCompact,
            onChanged: (v) {
              setState(() {
                _humanPlayers = v;
                if (_totalPlayers > _maxPlayers) {
                  _aiPlayers = _maxPlayers - _humanPlayers;
                }
              });
            },
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: isCompact ? 6 : 8),
            child: Divider(color: AppTheme.border, height: 1),
          ),
          _buildPlayerRow(
            icon: Icons.smart_toy_rounded,
            label: 'Bots',
            value: _aiPlayers,
            color: AppTheme.accentLight,
            min: 0,
            max: _maxPlayers - _humanPlayers,
            isCompact: isCompact,
            onChanged: (v) {
              setState(() {
                _aiPlayers = v;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required int min,
    required int max,
    required bool isCompact,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? 13 : 14,
            ),
          ),
        ),
        _stepperBtn(
          icon: Icons.remove_rounded,
          enabled: value > min,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        _stepperBtn(
          icon: Icons.add_rounded,
          enabled: value < max,
          onTap: () => onChanged(value + 1),
        ),
      ],
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
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.surfaceLight : AppTheme.bg2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? AppTheme.borderLight : AppTheme.border,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
        ),
      ),
    );
  }

  // ── Human Player Customization (Names & Color Choice) ──

  Widget _buildHumanPlayersCustomization(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 14),
      decoration: AppTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_rounded, size: 16, color: AppTheme.accentLight),
              const SizedBox(width: 8),
              Text(
                'Player Names & Colors',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: isCompact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: List.generate(_humanPlayers, (i) {
              final currentColor = _humanColors[i];

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 130,
                      height: 36,
                      child: TextField(
                        controller: _nameControllers[i],
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Player ${i + 1}',
                          hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          filled: true,
                          fillColor: AppTheme.bg3,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.bg3,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<PlayerColor>(
                            value: currentColor,
                            isExpanded: true,
                            dropdownColor: AppTheme.surface,
                            icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
                            items: PlayerColor.values.map((color) {
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
                              if (val != null) _selectColorForPlayer(i, val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Option to play as Jodi ──

  Widget _buildJodiOption(bool isCompact) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: isCompact ? 4 : 8),
      decoration: AppTheme.glassCard(),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, size: 18, color: Color(0xFFFFD700)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Play as Jodi (Blockades)',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: isCompact ? 13 : 14,
                  ),
                ),
                Text(
                  'Double tokens form path blockades',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enableJodi,
            activeThumbColor: const Color(0xFF00E5FF),
            onChanged: (val) => setState(() => _enableJodi = val),
          ),
        ],
      ),
    );
  }

  // ── AI Difficulty ──

  Widget _buildDifficultySelector(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 14),
      decoration: AppTheme.glassCard(),
      child: Row(
        children: [
          Icon(Icons.psychology_rounded, size: 16, color: AppTheme.warning),
          const SizedBox(width: 8),
          Text(
            'Bot Level',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: isCompact ? 12 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: AIDifficulty.values.map((d) {
                final selected = _aiDifficulty == d;
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
                      onTap: () => setState(() => _aiDifficulty = d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? color.withValues(alpha: 0.15) : AppTheme.bg3,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected ? color.withValues(alpha: 0.6) : AppTheme.border,
                          ),
                        ),
                        child: Text(
                          d.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? color : AppTheme.textSecondary,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

  // ── Action buttons ──

  Widget _buildActionButtons(bool isCompact) {
    final canStart = _totalPlayers >= 2 && _totalPlayers <= _maxPlayers;

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: isCompact ? 50 : 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: canStart ? AppTheme.primaryGradient : null,
            color: canStart ? null : AppTheme.bg3,
            boxShadow: canStart
                ? [
                    BoxShadow(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.4),
                      blurRadius: 18,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: ElevatedButton(
            onPressed: canStart ? _startGame : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'START GAME',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        SizedBox(height: isCompact ? 10 : 12),
        Container(
          width: double.infinity,
          height: isCompact ? 46 : 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                blurRadius: 14,
              ),
            ],
          ),
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LobbyScreen()),
              );
            },
            icon: const Icon(Icons.public_rounded, size: 18, color: Color(0xFF00E5FF)),
            label: const Text(
              'PLAY ONLINE',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00E5FF), width: 1.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
