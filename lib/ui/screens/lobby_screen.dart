import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/game_state.dart';
import '../../services/game_service.dart';
import '../../services/online_service.dart';
import '../../utils/constants.dart';
import '../theme.dart';
import '../widgets/player_avatar_widget.dart';
import 'game_screen.dart';

import '../widgets/online_chat_widget.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _onlineService = OnlineService();
  final _nameController = TextEditingController(text: 'Player');
  final _codeController = TextEditingController();
  final BoardType _boardType = BoardType.classic4;
  PlayerColor _selectedColor = PlayerColor.red;
  int _selectedAvatarIndex = 0;
  int _onlineMatchSize = 4;
  bool _onlineEnableTeamUp = false;
  int _activeTab = 0; // 0 for Create Room, 1 for Join Room
  RoomData? _room;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _onlineService.roomStream.listen((room) {
      if (mounted) {
        setState(() => _room = room);
        if (room.status == RoomStatus.playing) {
          final gameState = GameState(
            boardType: room.boardType,
            players: room.players,
          );
          final gameService = GameService(
            state: gameState,
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => GameScreen(
                service: gameService,
                localPlayerId: _onlineService.localPlayerId,
                onlineService: _onlineService,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _onlineService.dispose();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom() async {
    setState(() => _isLoading = true);
    await _onlineService.createRoom(
      playerName: _nameController.text.trim().isEmpty
          ? 'Player'
          : _nameController.text.trim(),
      boardType: _boardType,
      preferredColor: _selectedColor,
      avatarIndex: _selectedAvatarIndex,
      targetPlayerCount: _onlineMatchSize,
      isTeamUp: _onlineMatchSize == 4 && _onlineEnableTeamUp,
    );
    setState(() => _isLoading = false);
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a 6-character room code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await _onlineService.joinRoomResult(
      code: code,
      playerName: _nameController.text.trim().isEmpty
          ? 'Player'
          : _nameController.text.trim(),
      avatarIndex: _selectedAvatarIndex,
      preferredColor: _selectedColor,
    );
    setState(() => _isLoading = false);

    if (!result.isSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Unable to join room.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _startGame() async {
    await _onlineService.startGame();
    // TODO: Navigate to GameScreen with online service
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: AppTheme.artisticBackground(),
        child: SafeArea(
          child: _room == null ? _buildJoinCreate() : _buildLobby(),
        ),
      ),
    );
  }

  Set<PlayerColor> get _takenColors {
    if (_room == null) return {};
    final localId = _onlineService.localPlayerId;
    return _room!.players
        .where((p) => p.id != localId)
        .map((p) => p.color)
        .toSet();
  }

  Widget _buildAvatarPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Avatar',
          style: TextStyle(color: Color(0xFF8B949E), fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: Avatars.list.length,
            itemBuilder: (context, idx) {
              final isSel = idx == _selectedAvatarIndex;
              final avatar = Avatars.list[idx];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedAvatarIndex = idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel ? const Color(0xFF00E5FF) : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: PlayerAvatarWidget(
                      avatarIndex: idx,
                      size: 38,
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

  Widget _buildJoinCreate() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Top Bar Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.public_rounded, color: Color(0xFF00E5FF), size: 24),
                  const SizedBox(width: 8),
                  const Text(
                    'Online Multiplayer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),

              // Player Identity Card (Name, Avatar & 20 Colors)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.glassCard(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Player Profile',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    _buildAvatarPicker(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SizedBox(
                          width: 130,
                          height: 38,
                          child: TextField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'Player Name',
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
                        const SizedBox(width: 8),
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
                                value: _takenColors.contains(_selectedColor) ? null : _selectedColor,
                                hint: Text(
                                  _selectedColor.label,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                                isExpanded: true,
                                menuMaxHeight: 260,
                                dropdownColor: AppTheme.surface,
                                icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
                                items: PlayerColor.values.map((color) {
                                  final isTaken = _takenColors.contains(color);
                                  return DropdownMenuItem<PlayerColor>(
                                    value: isTaken ? null : color,
                                    enabled: !isTaken,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isTaken ? Colors.grey : color.color,
                                            border: Border.all(color: isTaken ? Colors.grey : Colors.white38),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isTaken ? '${color.label} (Taken)' : color.label,
                                          style: TextStyle(
                                            color: isTaken ? Colors.white38 : Colors.white,
                                            fontSize: 13,
                                            fontWeight: isTaken ? FontWeight.w400 : FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedColor = val);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Segment Switcher (Create Room vs Join Room)
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
                        onTap: () => setState(() => _activeTab = 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: _activeTab == 0 ? AppTheme.primaryGradient : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'CREATE ROOM',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _activeTab == 0 ? Colors.white : Colors.white70,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeTab = 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: _activeTab == 1 ? AppTheme.primaryGradient : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'JOIN ROOM',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _activeTab == 1 ? Colors.white : Colors.white70,
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

              // Active Tab Content Card
              if (_activeTab == 0) ...[
                // CREATE ROOM
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassCard(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Match Size',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [2, 4].map((size) {
                          final selected = _onlineMatchSize == size;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: GestureDetector(
                                onTap: () => setState(() => _onlineMatchSize = size),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: selected ? AppTheme.primaryGradient : null,
                                    color: selected ? null : AppTheme.bg3,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected ? AppTheme.accentLight : AppTheme.border,
                                    ),
                                  ),
                                  child: Text(
                                    '$size Players',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: selected ? Colors.white : AppTheme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_onlineMatchSize == 4) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.groups_rounded, size: 18, color: Color(0xFF00E5FF)),
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
                              value: _onlineEnableTeamUp,
                              activeThumbColor: const Color(0xFF00E5FF),
                              onChanged: (val) => setState(() => _onlineEnableTeamUp = val),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 68,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createRoom,
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
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'CREATE ROOM',
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
              ] else ...[
                // JOIN ROOM
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.glassCard(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter 6-Digit Room Code',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _codeController,
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
                            borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 68,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _joinRoom,
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
                              child: _isLoading
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
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLobby() {
    final room = _room!;
    final isHost = room.hostId == _onlineService.localPlayerId;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '🏠 Room Lobby',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 16),

              // Room code display
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.glassCard(),
                child: Column(
                  children: [
                    const Text(
                      'Room Code',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: room.code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied!')),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            room.code,
                            style: const TextStyle(
                              color: Color(0xFF58A6FF),
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.copy,
                              color: Color(0xFF58A6FF), size: 20),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Share this code with friends',
                      style: TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Players list
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCard(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Players (${room.players.length}/${room.maxPlayers})',
                      style: const TextStyle(
                        color: Color(0xFFC9D1D9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...room.players.map((player) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              PlayerAvatarWidget(
                                avatarIndex: player.avatarIndex,
                                size: 36,
                                borderColor: player.color.color,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  player.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (player.id == room.hostId)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'HOST',
                                    style: TextStyle(
                                      color: Color(0xFFFFD700),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )),
                    // Waiting slots
                    for (var i = room.players.length; i < room.maxPlayers; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF30363D),
                                  width: 2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Waiting...',
                              style: TextStyle(
                                color: Color(0xFF484F58),
                                fontSize: 15,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Start / Chat / Leave buttons
              if (isHost && room.players.length >= 2) ...[
                SizedBox(
                  width: double.infinity,
                  height: 68,
                  child: ElevatedButton(
                    onPressed: _startGame,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'START GAME',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2.0),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    OnlineChatWidget.showChatModal(
                      context,
                      _onlineService,
                      _nameController.text.trim().isEmpty ? 'Player' : _nameController.text.trim(),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Color(0xFF00E5FF)),
                  label: const Text(
                    'LIVE LOBBY CHAT',
                    style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await _onlineService.leaveRoom();
                  if (mounted) Navigator.pop(context);
                },
                child: const Text(
                  'Leave Room',
                  style: TextStyle(color: Color(0xFFF85149)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
