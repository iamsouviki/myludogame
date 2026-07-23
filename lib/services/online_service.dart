import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../utils/constants.dart';
import '../utils/room_code_generator.dart';

// ponytail: Online multiplayer service using Firebase Realtime DB.
// Falls back to in-memory local map if Firebase instance is not configured.

/// Room state for lobby
enum RoomStatus { waiting, playing, finished }

class JoinRoomResult {
  final RoomData? room;
  final String? error;

  JoinRoomResult({this.room, this.error});
  bool get isSuccess => room != null && error == null;
}

class RoomData {
  final String code;
  final String hostId;
  final BoardType boardType;
  final List<Player> players;
  final RoomStatus status;
  final Map<String, dynamic>? gameState;
  final bool isTeamUp;
  final int targetPlayerCount;

  const RoomData({
    required this.code,
    required this.hostId,
    required this.boardType,
    required this.players,
    this.status = RoomStatus.waiting,
    this.gameState,
    this.isTeamUp = false,
    this.targetPlayerCount = 4,
  });

  int get maxPlayers => targetPlayerCount;
  bool get isFull => players.length >= maxPlayers;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'code': code,
      'hostId': hostId,
      'boardType': boardType.index,
      'players': players.map((p) => p.toJson()).toList(),
      'status': status.index,
      'isTeamUp': isTeamUp,
      'targetPlayerCount': targetPlayerCount,
    };
    // ponytail: omit null gameState — Firebase update() treats null as DELETE
    if (gameState != null) json['gameState'] = gameState;
    return json;
  }

  factory RoomData.fromJson(Map<String, dynamic> json) => RoomData(
        code: json['code'] as String,
        hostId: json['hostId'] as String,
        boardType: BoardType.values[json['boardType'] as int],
        players: (json['players'] as List)
            .map((p) => Player.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList(),
        status: RoomStatus.values[json['status'] as int],
        gameState: json['gameState'] != null
            ? Map<String, dynamic>.from(json['gameState'] as Map)
            : null,
        isTeamUp: (json['isTeamUp'] as bool?) ?? false,
        targetPlayerCount: (json['targetPlayerCount'] as int?) ?? 4,
      );
}

class ChatMessage {
  final String senderId;
  final String senderName;
  final String text;
  final int timestamp;

  const ChatMessage({
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'senderName': senderName,
        'text': text,
        'timestamp': timestamp,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        senderId: json['senderId'] as String,
        senderName: json['senderName'] as String,
        text: json['text'] as String,
        timestamp: (json['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      );
}

/// Online service interface powered by Firebase Realtime DB.
class OnlineService {
  static final Map<String, RoomData> _localRooms = {};
  static final Map<String, List<ChatMessage>> _localChats = {};

  final StreamController<RoomData> _roomController =
      StreamController<RoomData>.broadcast();
  final StreamController<List<ChatMessage>> _chatController =
      StreamController<List<ChatMessage>>.broadcast();

  Stream<RoomData> get roomStream => _roomController.stream;
  Stream<List<ChatMessage>> get chatStream => _chatController.stream;

  StreamSubscription<DatabaseEvent>? _firebaseSubscription;
  StreamSubscription<DatabaseEvent>? _chatSubscription;
  StreamSubscription<DatabaseEvent>? _chatChildSubscription;

  String? currentRoomCode;
  String? localPlayerId;

  OnlineService() {
    final prefix = kIsWeb ? 'web' : 'app';
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(99999);
    localPlayerId = '${prefix}_${ts}_$rand';
  }

  DatabaseReference? _roomRef(String code) {
    try {
      return FirebaseDatabase.instance.ref('rooms/$code');
    } catch (_) {
      return null;
    }
  }

  // ponytail: Firebase returns Map<Object?, Object?> and nums as dynamic.
  // Shallow Map.from() leaves nested values unconverted, causing silent cast
  // failures that kill the onValue listener.
  static dynamic _deepConvert(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map((e) => MapEntry(e.key.toString(), _deepConvert(e.value))),
      );
    }
    if (value is List) {
      return value.map(_deepConvert).toList();
    }
    return value;
  }

  void _listenToRoom(String code) {
    _firebaseSubscription?.cancel();
    _chatSubscription?.cancel();
    _chatChildSubscription?.cancel();

    final ref = _roomRef(code);
    if (ref != null) {
      _firebaseSubscription = ref.onValue.listen((event) {
        if (event.snapshot.value != null) {
          try {
            final data = _deepConvert(event.snapshot.value) as Map<String, dynamic>;
            // ponytail: strip chat node — it's handled by its own listener
            data.remove('chat');
            final room = RoomData.fromJson(data);
            _localRooms[code] = room;
            _roomController.add(room);
          } catch (e) {
            debugPrint('[OnlineService] Error parsing room update: $e');
          }
        }
      });

      _chatSubscription = ref.child('chat').onValue.listen((event) {
        try {
          final raw = _deepConvert(event.snapshot.value);
          final messages = <ChatMessage>[];
          if (raw is Map) {
            for (final value in raw.values) {
              if (value is Map) {
                messages.add(ChatMessage.fromJson(Map<String, dynamic>.from(value)));
              }
            }
          }
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          _localChats[code] = messages;
          _chatController.add(messages);
        } catch (e) {
          debugPrint('[OnlineService] Error parsing chat update: $e');
        }
      });
    }
  }

  Future<void> sendChatMessage(String text, {String? senderName}) async {
    if (currentRoomCode == null || text.trim().isEmpty) return;
    final code = currentRoomCode!;
    final room = _localRooms[code];

    String name = senderName ?? 'Player';
    if (room != null) {
      for (final p in room.players) {
        if (p.id == localPlayerId) {
          name = p.name;
          break;
        }
      }
    }

    final msg = ChatMessage(
      senderId: localPlayerId!,
      senderName: name,
      text: text.trim(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    final list = _localChats[code] ?? [];
    // Firebase onValue echoes this to every client, including the sender.

    final ref = _roomRef(code);
    if (ref != null) {
      try {
        await ref.child('chat').push().set(msg.toJson());
      } catch (_) {
        list.add(msg);
        _localChats[code] = list;
        _chatController.add(list);
      }
    } else {
      list.add(msg);
      _localChats[code] = list;
      _chatController.add(list);
    }
  }

  /// Create a new room
  Future<RoomData> createRoom({
    required String playerName,
    required BoardType boardType,
    PlayerColor? preferredColor,
    int avatarIndex = 0,
    bool isTeamUp = false,
    int targetPlayerCount = 4,
  }) async {
    final code = RoomCodeGenerator.generate();
    final player = Player(
      id: localPlayerId!,
      name: playerName,
      color: preferredColor ??
          (boardType == BoardType.classic4
              ? PlayerColor.red
              : PlayerColor.values[0]),
      type: PlayerType.human,
      avatarIndex: avatarIndex,
      teamId: (isTeamUp && targetPlayerCount == 4) ? 0 : null,
    );

    final room = RoomData(
      code: code,
      hostId: localPlayerId!,
      boardType: boardType,
      players: [player],
      isTeamUp: isTeamUp,
      targetPlayerCount: targetPlayerCount,
    );

    _localRooms[code] = room;
    currentRoomCode = code;

    final ref = _roomRef(code);
    if (ref != null) {
      try {
        debugPrint('[OnlineService] Creating room $code on Firebase...');
        await ref.set(room.toJson());
        debugPrint('[OnlineService] Room $code created successfully on Firebase.');
        _listenToRoom(code);
      } catch (e, stack) {
        debugPrint('[OnlineService] ERROR creating room $code on Firebase: $e\n$stack');
        _roomController.add(room);
      }
    } else {
      debugPrint('[OnlineService] Firebase ref is null. Operating in local memory fallback.');
      _roomController.add(room);
    }

    return room;
  }

  /// Join an existing room
  Future<JoinRoomResult> joinRoomResult({
    required String code,
    required String playerName,
    int avatarIndex = 0,
    PlayerColor? preferredColor,
  }) async {
    final cleanCode = code.toUpperCase();
    debugPrint('[OnlineService] Attempting to join room: $cleanCode');
    RoomData? room = _localRooms[cleanCode];

    final ref = _roomRef(cleanCode);
    if (ref != null) {
      try {
        debugPrint('[OnlineService] Fetching room $cleanCode from Firebase Realtime DB...');
        final snapshot = await ref.get();
        if (snapshot.exists && snapshot.value != null) {
          final data = _deepConvert(snapshot.value) as Map<String, dynamic>;
          data.remove('chat');
          room = RoomData.fromJson(data);
        } else {
          debugPrint('[OnlineService] Snapshot for room $cleanCode does not exist on Firebase.');
        }
      } catch (e, stack) {
        debugPrint('[OnlineService] ERROR fetching room $cleanCode from Firebase: $e\n$stack');
      }
    } else {
      debugPrint('[OnlineService] Firebase ref is null. Checking local memory for $cleanCode.');
    }

    if (room == null) {
      return JoinRoomResult(error: 'Room "$cleanCode" not found! Check the room code and try again.');
    }
    if (room.isFull) {
      return JoinRoomResult(error: 'Room "$cleanCode" is already full!');
    }
    if (room.status != RoomStatus.waiting) {
      return JoinRoomResult(error: 'Match in room "$cleanCode" has already started!');
    }
    final targetRoom = room;

    final usedColors = targetRoom.players.map((p) => p.color).toSet();
    if (preferredColor != null && usedColors.contains(preferredColor)) {
      return JoinRoomResult(
        error: 'Color "${preferredColor.label}" is already selected by another player! Please choose a different color.',
      );
    }

    final allColors = targetRoom.boardType == BoardType.classic4
        ? [PlayerColor.red, PlayerColor.green, PlayerColor.yellow, PlayerColor.blue]
        : PlayerColor.values;

    final availableColor = preferredColor ??
        allColors.firstWhere(
          (c) => !usedColors.contains(c),
          orElse: () => allColors[targetRoom.players.length % allColors.length],
        );

    final playerIndex = targetRoom.players.length;
    final teamId = (targetRoom.isTeamUp && targetRoom.targetPlayerCount == 4)
        ? (playerIndex % 2 == 0 ? 0 : 1)
        : null;

    final player = Player(
      id: localPlayerId!,
      name: playerName,
      color: availableColor,
      type: PlayerType.human,
      avatarIndex: avatarIndex,
      teamId: teamId,
    );

    final updatedPlayers = [...room.players, player];
    final updatedRoom = RoomData(
      code: room.code,
      hostId: room.hostId,
      boardType: room.boardType,
      players: updatedPlayers,
      status: room.status,
      gameState: room.gameState,
      isTeamUp: room.isTeamUp,
      targetPlayerCount: room.targetPlayerCount,
    );

    _localRooms[cleanCode] = updatedRoom;
    currentRoomCode = cleanCode;

    if (ref != null) {
      try {
        // Atomic transaction prevents two simultaneous joins from losing a player.
        final transaction = await ref.child('players').runTransaction((data) {
          final current = data == null
              ? <dynamic>[]
              : _deepConvert(data) as List;
          if (current.any((item) => item is Map && item['id'] == localPlayerId)) {
            return Transaction.success(current);
          }
          if (current.any((item) => item is Map && item['color'] == player.color.index)) {
            return Transaction.abort();
          }
          if (current.length >= targetRoom.maxPlayers) {
            return Transaction.abort();
          }
          return Transaction.success([...current, player.toJson()]);
        });
        if (!transaction.committed) {
          return JoinRoomResult(error: 'That color was just selected by another player. Choose a different color.');
        }
        debugPrint('[OnlineService] Joined room $cleanCode — players updated on Firebase.');
      } catch (e, stack) {
        debugPrint('[OnlineService] ERROR updating room $cleanCode on Firebase: $e\n$stack');
      }
      // ponytail: always listen regardless of write success — we need remote updates
      _listenToRoom(cleanCode);
    } else {
      _roomController.add(updatedRoom);
    }

    return JoinRoomResult(room: updatedRoom);
  }

  /// Backwards-compatible join room helper
  Future<RoomData?> joinRoom({
    required String code,
    required String playerName,
    int avatarIndex = 0,
    PlayerColor? preferredColor,
  }) async {
    final res = await joinRoomResult(
      code: code,
      playerName: playerName,
      avatarIndex: avatarIndex,
      preferredColor: preferredColor,
    );
    return res.room;
  }

  /// Start the game (host only)
  Future<bool> fillWithBots() async {
    if (currentRoomCode == null) return false;
    final room = _localRooms[currentRoomCode!];
    if (room == null || room.hostId != localPlayerId || room.targetPlayerCount < 4) {
      return false;
    }
    final colors = room.boardType == BoardType.classic4
        ? [PlayerColor.red, PlayerColor.green, PlayerColor.yellow, PlayerColor.blue]
        : PlayerColor.values;
    final used = room.players.map((p) => p.color).toSet();
    final players = [...room.players];
    var botNumber = 1;
    while (players.length < room.maxPlayers) {
      final color = colors.firstWhere((c) => !used.contains(c));
      used.add(color);
      final index = players.length;
      players.add(Player(
        id: 'bot_${room.code}_$botNumber',
        name: 'Bot $botNumber',
        color: color,
        type: PlayerType.ai,
        difficulty: AIDifficulty.medium,
        teamId: room.isTeamUp ? index % 2 : null,
      ));
      botNumber++;
    }
    final updated = RoomData(
      code: room.code,
      hostId: room.hostId,
      boardType: room.boardType,
      players: players,
      status: room.status,
      gameState: room.gameState,
      isTeamUp: room.isTeamUp,
      targetPlayerCount: room.targetPlayerCount,
    );
    _localRooms[room.code] = updated;
    final ref = _roomRef(room.code);
    if (ref != null) {
      await ref.child('players').set(players.map((p) => p.toJson()).toList());
    } else {
      _roomController.add(updated);
    }
    return true;
  }

  Future<void> startGame() async {
    if (currentRoomCode == null) return;
    final room = _localRooms[currentRoomCode!];
    if (room == null || room.hostId != localPlayerId ||
        room.players.length < 2 ||
        (room.isTeamUp && room.players.length != 4)) {
      return;
    }

    final updatedRoom = RoomData(
      code: room.code,
      hostId: room.hostId,
      boardType: room.boardType,
      players: room.players,
      status: RoomStatus.playing,
      gameState: room.gameState,
      isTeamUp: room.isTeamUp,
      targetPlayerCount: room.targetPlayerCount,
    );

    _localRooms[currentRoomCode!] = updatedRoom;

    final ref = _roomRef(currentRoomCode!);
    if (ref != null) {
      try {
        // Publish the complete player roster before clients enter the game.
        await ref.child('players').set(
            room.players.map((p) => p.toJson()).toList());
        await ref.child('status').set(RoomStatus.playing.index);
      } catch (_) {
        _roomController.add(updatedRoom);
      }
    } else {
      _roomController.add(updatedRoom);
    }
  }

  /// Sync game state to room
  Future<void> syncGameState(GameState state) async {
    if (currentRoomCode == null) return;
    final room = _localRooms[currentRoomCode!];
    if (room == null) return;

    final updatedRoom = RoomData(
      code: room.code,
      hostId: room.hostId,
      boardType: room.boardType,
      players: room.players,
      status: room.status,
      gameState: state.toJson(),
    );

    _localRooms[currentRoomCode!] = updatedRoom;

    final ref = _roomRef(currentRoomCode!);
    if (ref != null) {
      try {
        await ref.child('gameState').set(state.toJson());
      } catch (_) {
        _roomController.add(updatedRoom);
      }
    } else {
      _roomController.add(updatedRoom);
    }
  }

  /// Store completed game leaderboard data and delete active room data
  Future<void> storeFinishedMatch(GameState state) async {
    if (currentRoomCode == null) return;
    final code = currentRoomCode!;
    try {
      // 1. Save minimal leaderboard record
      final leaderboardRef = FirebaseDatabase.instance.ref('leaderboards/$code');
      await leaderboardRef.set({
        'roomCode': code,
        'finishedAt': DateTime.now().millisecondsSinceEpoch,
        'winnerName': state.winner != null ? state.players[state.winner!].name : 'Unknown',
        'winnerColor': state.winner != null ? state.players[state.winner!].color.label : '',
        'players': state.players.map((p) => {
          'name': p.name,
          'color': p.color.label,
          'avatarIndex': p.avatarIndex,
        }).toList(),
        'rankings': state.finishOrder.map((idx) => {
          'rank': state.finishOrder.indexOf(idx) + 1,
          'name': state.players[idx].name,
          'color': state.players[idx].color.label,
        }).toList(),
      });

      // 2. Delete room data from DB to free up room memory
      final roomRef = _roomRef(code);
      if (roomRef != null) {
        await roomRef.remove();
      }
    } catch (_) {}
  }

  /// Leave room gracefully
  Future<void> leaveRoom() async {
    if (currentRoomCode == null) return;
    final code = currentRoomCode!;
    _firebaseSubscription?.cancel();
    _chatSubscription?.cancel();
    _chatChildSubscription?.cancel();

    final room = _localRooms[code];
    final ref = _roomRef(code);

    if (ref != null && room != null) {
      try {
        if (room.hostId == localPlayerId || room.players.length <= 1) {
          // Host leaves or last player -> remove room
          await ref.remove();
        } else {
          // Non-host leaves -> remove self from player list & update DB
          final remainingPlayers = room.players.where((p) => p.id != localPlayerId).toList();
          await ref.child('players').set(remainingPlayers.map((p) => p.toJson()).toList());
        }
      } catch (_) {}
    }

    _localRooms.remove(code);
    currentRoomCode = null;
  }

  void dispose() {
    _firebaseSubscription?.cancel();
    _chatSubscription?.cancel();
    _roomController.close();
    _chatController.close();
  }
}
