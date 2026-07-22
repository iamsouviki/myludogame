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

class RoomData {
  final String code;
  final String hostId;
  final BoardType boardType;
  final List<Player> players;
  final RoomStatus status;
  final Map<String, dynamic>? gameState;

  const RoomData({
    required this.code,
    required this.hostId,
    required this.boardType,
    required this.players,
    this.status = RoomStatus.waiting,
    this.gameState,
  });

  int get maxPlayers => boardType.maxPlayers;
  bool get isFull => players.length >= maxPlayers;

  Map<String, dynamic> toJson() => {
        'code': code,
        'hostId': hostId,
        'boardType': boardType.index,
        'players': players.map((p) => p.toJson()).toList(),
        'status': status.index,
        'gameState': gameState,
      };

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
      );
}

/// Online service interface powered by Firebase Realtime DB.
class OnlineService {
  static final Map<String, RoomData> _localRooms = {};

  final StreamController<RoomData> _roomController =
      StreamController<RoomData>.broadcast();

  Stream<RoomData> get roomStream => _roomController.stream;

  StreamSubscription<DatabaseEvent>? _firebaseSubscription;

  String? currentRoomCode;
  String? localPlayerId;

  OnlineService() {
    localPlayerId = 'player_${Random().nextInt(99999)}';
  }

  DatabaseReference? _roomRef(String code) {
    try {
      return FirebaseDatabase.instance.ref('rooms/$code');
    } catch (_) {
      return null;
    }
  }

  void _listenToRoom(String code) {
    _firebaseSubscription?.cancel();
    final ref = _roomRef(code);
    if (ref != null) {
      _firebaseSubscription = ref.onValue.listen((event) {
        if (event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final room = RoomData.fromJson(data);
          _localRooms[code] = room;
          _roomController.add(room);
        }
      });
    }
  }

  /// Create a new room
  Future<RoomData> createRoom({
    required String playerName,
    required BoardType boardType,
  }) async {
    final code = RoomCodeGenerator.generate();
    final player = Player(
      id: localPlayerId!,
      name: playerName,
      color: boardType == BoardType.classic4
          ? PlayerColor.red
          : PlayerColor.values[0],
      type: PlayerType.human,
    );

    final room = RoomData(
      code: code,
      hostId: localPlayerId!,
      boardType: boardType,
      players: [player],
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
  Future<RoomData?> joinRoom({
    required String code,
    required String playerName,
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
          debugPrint('[OnlineService] Room $cleanCode found on Firebase: ${snapshot.value}');
          final data = Map<String, dynamic>.from(snapshot.value as Map);
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

    if (room == null || room.isFull || room.status != RoomStatus.waiting) {
      debugPrint('[OnlineService] Cannot join room $cleanCode (room null: ${room == null}, isFull: ${room?.isFull}, status: ${room?.status})');
      return null;
    }

    final colorIndex = room.players.length;
    final colors = room.boardType == BoardType.classic4
        ? [PlayerColor.red, PlayerColor.green, PlayerColor.yellow, PlayerColor.blue]
        : PlayerColor.values;

    final player = Player(
      id: localPlayerId!,
      name: playerName,
      color: colors[colorIndex],
      type: PlayerType.human,
    );

    final updatedRoom = RoomData(
      code: room.code,
      hostId: room.hostId,
      boardType: room.boardType,
      players: [...room.players, player],
      status: room.status,
      gameState: room.gameState,
    );

    _localRooms[cleanCode] = updatedRoom;
    currentRoomCode = cleanCode;

    if (ref != null) {
      try {
        debugPrint('[OnlineService] Updating joined room $cleanCode on Firebase...');
        await ref.update(updatedRoom.toJson());
        debugPrint('[OnlineService] Joined room $cleanCode updated on Firebase.');
        _listenToRoom(cleanCode);
      } catch (e, stack) {
        debugPrint('[OnlineService] ERROR updating room $cleanCode on Firebase: $e\n$stack');
        _roomController.add(updatedRoom);
      }
    } else {
      _roomController.add(updatedRoom);
    }

    return updatedRoom;
  }

  /// Start the game (host only)
  Future<void> startGame() async {
    if (currentRoomCode == null) return;
    final room = _localRooms[currentRoomCode!];
    if (room == null || room.hostId != localPlayerId || room.players.length < 2) return;

    final updatedRoom = RoomData(
      code: room.code,
      hostId: room.hostId,
      boardType: room.boardType,
      players: room.players,
      status: RoomStatus.playing,
      gameState: room.gameState,
    );

    _localRooms[currentRoomCode!] = updatedRoom;

    final ref = _roomRef(currentRoomCode!);
    if (ref != null) {
      try {
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

  /// Leave room
  Future<void> leaveRoom() async {
    if (currentRoomCode == null) return;
    _firebaseSubscription?.cancel();

    final ref = _roomRef(currentRoomCode!);
    if (ref != null) {
      try {
        await ref.remove();
      } catch (_) {}
    }

    _localRooms.remove(currentRoomCode);
    currentRoomCode = null;
  }

  void dispose() {
    _firebaseSubscription?.cancel();
    _roomController.close();
  }
}

