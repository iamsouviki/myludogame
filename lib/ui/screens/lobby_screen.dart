import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/online_service.dart';
import '../../utils/constants.dart';
import '../theme.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _onlineService = OnlineService();
  final _nameController = TextEditingController(text: 'Player');
  final _codeController = TextEditingController();
  BoardType _boardType = BoardType.classic4;
  RoomData? _room;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _onlineService.roomStream.listen((room) {
      if (mounted) setState(() => _room = room);
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
    final room = await _onlineService.joinRoom(
      code: code,
      playerName: _nameController.text.trim().isEmpty
          ? 'Player'
          : _nameController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (room == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room not found or full')),
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
        decoration: const BoxDecoration(gradient: AppTheme.boardBackground),
        child: SafeArea(
          child: _room == null ? _buildJoinCreate() : _buildLobby(),
        ),
      ),
    );
  }

  Widget _buildJoinCreate() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '🌐 Online Play',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 32),

              // Name input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCard(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Name',
                      style: TextStyle(color: Color(0xFFC9D1D9), fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF21262D),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF30363D)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF30363D)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Create room
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCard(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Room',
                      style: TextStyle(
                        color: Color(0xFFC9D1D9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Board type toggle
                    Row(
                      children: BoardType.values.map((type) {
                        final selected = _boardType == type;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _boardType = type),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF238636)
                                          .withValues(alpha: 0.3)
                                      : const Color(0xFF21262D),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFF56D364)
                                        : const Color(0xFF30363D),
                                  ),
                                ),
                                child: Text(
                                  type.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selected
                                        ? const Color(0xFF56D364)
                                        : const Color(0xFF8B949E),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createRoom,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('CREATE ROOM'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Join room
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.glassCard(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Join Room',
                      style: TextStyle(
                        color: Color(0xFFC9D1D9),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            style: const TextStyle(
                              color: Colors.white,
                              letterSpacing: 4,
                              fontWeight: FontWeight.w700,
                            ),
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 6,
                            decoration: InputDecoration(
                              hintText: 'ROOM CODE',
                              hintStyle: const TextStyle(
                                color: Color(0xFF484F58),
                                letterSpacing: 2,
                              ),
                              counterText: '',
                              filled: true,
                              fillColor: const Color(0xFF21262D),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFF30363D)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFF30363D)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _joinRoom,
                          child: const Text('JOIN'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('← Back to menu'),
              ),
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
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: player.color.color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  player.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
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

              // Start / Leave buttons
              if (isHost && room.players.length >= 2)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _startGame,
                    child: const Text('START GAME'),
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
