import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../utils/constants.dart';
import '../utils/room_code_generator.dart';
import 'browser_storage.dart';

T _safeEnum<T>(List<T> values, dynamic raw, T fallback) {
  final index = (raw as num?)?.toInt();
  return index != null && index >= 0 && index < values.length
      ? values[index]
      : fallback;
}

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

  int get maxPlayers =>
      targetPlayerCount.clamp(2, boardType.maxPlayers).toInt();
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

  factory RoomData.fromJson(Map<String, dynamic> json) {
    final boardType = _safeEnum(
      BoardType.values,
      json['boardType'],
      BoardType.classic4,
    );
    final rawPlayers = json['players'];
    final players = rawPlayers is List
        ? rawPlayers
              .map(
                (p) => p is Map
                    ? Player.fromJson(Map<String, dynamic>.from(p))
                    : null,
              )
              .whereType<Player>()
              .toList()
        : <Player>[];
    final rawGameState = json['gameState'];
    return RoomData(
      code: (json['code'] as String?) ?? '',
      hostId: (json['hostId'] as String?) ?? '',
      boardType: boardType,
      players: players,
      status: _safeEnum(RoomStatus.values, json['status'], RoomStatus.waiting),
      gameState: rawGameState is Map
          ? Map<String, dynamic>.from(rawGameState)
          : null,
      isTeamUp: (json['isTeamUp'] as bool?) ?? false,
      targetPlayerCount: ((json['targetPlayerCount'] as num?)?.toInt() ?? 4)
          .clamp(2, boardType.maxPlayers)
          .toInt(),
    );
  }
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
    timestamp:
        (json['timestamp'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch,
  );
}

class OnlineAction {
  final String id;
  final String type;
  final String actorId;
  final int? tokenIndex;
  final String? emoji;
  final int createdAt;

  const OnlineAction({
    required this.id,
    required this.type,
    required this.actorId,
    this.tokenIndex,
    this.emoji,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'actorId': actorId,
    if (tokenIndex != null) 'tokenIndex': tokenIndex,
    if (emoji != null) 'emoji': emoji,
    'createdAt': createdAt,
  };

  factory OnlineAction.fromSnapshot(DataSnapshot snapshot) {
    final raw = snapshot.value is Map
        ? Map<String, dynamic>.from(
            OnlineService._deepConvert(snapshot.value) as Map,
          )
        : <String, dynamic>{};
    return OnlineAction(
      id: snapshot.key ?? '',
      type: raw['type'] as String? ?? '',
      actorId: raw['actorId'] as String? ?? '',
      tokenIndex: (raw['tokenIndex'] as num?)?.toInt(),
      emoji: raw['emoji'] as String?,
      createdAt: (raw['createdAt'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Online service interface powered by Firebase Realtime DB.
class OnlineService {
  static final Map<String, RoomData> _localRooms = {};
  static final Map<String, List<ChatMessage>> _localChats = {};

  final StreamController<RoomData> _roomController =
      StreamController<RoomData>.broadcast();
  final StreamController<List<ChatMessage>> _chatController =
      StreamController<List<ChatMessage>>.broadcast();
  final StreamController<OnlineAction> _actionController =
      StreamController<OnlineAction>.broadcast();

  Stream<RoomData> get roomStream => _roomController.stream;
  Stream<List<ChatMessage>> get chatStream => _chatController.stream;
  Stream<OnlineAction> get actionStream => _actionController.stream;

  List<ChatMessage> currentChatMessages([String? roomCode]) {
    final code = roomCode ?? currentRoomCode;
    if (code == null) return const [];
    return List.unmodifiable(_localChats[code] ?? const <ChatMessage>[]);
  }

  Future<bool> submitAction({
    required String type,
    int? tokenIndex,
    String? emoji,
  }) async {
    final code = currentRoomCode;
    final actorId = localPlayerId;
    final ref = code == null ? null : _actionsRef(code);
    if (ref == null || actorId == null) return false;
    try {
      final actionRef = ref.push();
      final payload = <String, dynamic>{
        'type': type,
        'actorId': actorId,
        'createdAt': ServerValue.timestamp,
      };
      if (tokenIndex != null) payload['tokenIndex'] = tokenIndex;
      if (emoji != null) payload['emoji'] = emoji;
      await actionRef.set(payload);
      return true;
    } catch (e) {
      debugPrint('[OnlineService] Action submission failed: $e');
      return false;
    }
  }

  Future<void> _deleteAction(String code, String actionId) async {
    final ref = _actionsRef(code);
    if (ref == null || actionId.isEmpty) return;
    try {
      await ref.child(actionId).remove();
    } catch (e) {
      debugPrint('[OnlineService] Action cleanup failed: $e');
    }
  }

  Future<void> consumeAction(OnlineAction action) async {
    final code = currentRoomCode;
    if (code != null) await _deleteAction(code, action.id);
  }

  StreamSubscription<DatabaseEvent>? _firebaseSubscription;
  StreamSubscription<DatabaseEvent>? _chatSubscription;
  StreamSubscription<DatabaseEvent>? _chatChildSubscription;
  StreamSubscription<DatabaseEvent>? _presenceSubscription;
  StreamSubscription<DatabaseEvent>? _actionSubscription;
  StreamSubscription<DatabaseEvent>? _connectionSubscription;

  String? currentRoomCode;
  String? localPlayerId;
  bool _disposed = false;

  bool get isLocalHost {
    final code = currentRoomCode;
    final room = code == null ? null : _localRooms[code];
    return room != null && room.hostId == localPlayerId;
  }

  OnlineService() {
    User? firebaseUser;
    try {
      firebaseUser = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    if (firebaseUser != null) {
      localPlayerId = firebaseUser.uid;
      return;
    }
    const key = 'myludo_online_player_id';
    String? stored;
    if (kIsWeb) {
      try {
        stored = readBrowserStorage(key);
      } catch (_) {}
    }
    if (stored != null &&
        RegExp(r'^(web|app)_[A-Za-z0-9_]+$').hasMatch(stored)) {
      localPlayerId = stored;
      return;
    }
    final prefix = kIsWeb ? 'web' : 'app';
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = Random().nextInt(99999);
    localPlayerId = '${prefix}_${ts}_$rand';
    if (kIsWeb) {
      try {
        writeBrowserStorage(key, localPlayerId!);
      } catch (_) {}
    }
  }

  DatabaseReference? _roomRef(String code) {
    try {
      return FirebaseDatabase.instance.ref('rooms/$code');
    } catch (_) {
      return null;
    }
  }

  DatabaseReference? _presenceRef(String code) {
    try {
      return FirebaseDatabase.instance.ref('rooms/$code/presence');
    } catch (_) {
      return null;
    }
  }

  DatabaseReference? _actionsRef(String code) {
    try {
      return FirebaseDatabase.instance.ref('rooms/$code/actions');
    } catch (_) {
      return null;
    }
  }

  void _validateRoomConfig({
    required BoardType boardType,
    required int targetPlayerCount,
    required bool isTeamUp,
  }) {
    if (targetPlayerCount < 2 || targetPlayerCount > boardType.maxPlayers) {
      throw ArgumentError(
        'A ${boardType.label} room must have 2-${boardType.maxPlayers} players.',
      );
    }
    if (isTeamUp &&
        (boardType != BoardType.classic4 || targetPlayerCount != 4)) {
      throw ArgumentError(
        'Team-up mode requires exactly four classic-board players.',
      );
    }
  }

  // ponytail: Firebase returns Map<Object?, Object?> and nums as dynamic.
  // Shallow Map.from() leaves nested values unconverted, causing silent cast
  // failures that kill the onValue listener.
  static dynamic _deepConvert(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map(
          (e) => MapEntry(e.key.toString(), _deepConvert(e.value)),
        ),
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
    _presenceSubscription?.cancel();
    _actionSubscription?.cancel();
    _connectionSubscription?.cancel();
    _firebaseSubscription = null;
    _chatSubscription = null;
    _chatChildSubscription = null;
    _presenceSubscription = null;
    _actionSubscription = null;
    _connectionSubscription = null;

    final ref = _roomRef(code);
    if (ref != null) {
      _firebaseSubscription = ref.onValue.listen((event) {
        if (event.snapshot.value == null) {
          final previous = _localRooms.remove(code);
          if (currentRoomCode == code) currentRoomCode = null;
          if (previous != null) {
            _roomController.add(
              RoomData(
                code: previous.code,
                hostId: previous.hostId,
                boardType: previous.boardType,
                players: const [],
                status: RoomStatus.finished,
                isTeamUp: previous.isTeamUp,
                targetPlayerCount: previous.targetPlayerCount,
              ),
            );
          }
          return;
        }
        try {
          final data =
              _deepConvert(event.snapshot.value) as Map<String, dynamic>;
          data.remove('chat');
          final room = RoomData.fromJson(data);
          _localRooms[code] = room;
          _roomController.add(room);
        } catch (e) {
          debugPrint('[OnlineService] Error parsing room update: $e');
        }
      });

      _chatSubscription = ref.child('chat').onValue.listen((event) {
        try {
          final raw = _deepConvert(event.snapshot.value);
          final messages = <ChatMessage>[];
          if (raw is Map) {
            for (final value in raw.values) {
              if (value is Map) {
                messages.add(
                  ChatMessage.fromJson(Map<String, dynamic>.from(value)),
                );
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

      final cachedMessages = _localChats[code];
      if (cachedMessages != null) {
        _chatController.add(List<ChatMessage>.from(cachedMessages));
      }

      _presenceSubscription = ref.child('presence').onValue.listen((event) {
        try {
          final raw = _deepConvert(event.snapshot.value);
          if (raw is! Map) return;
          final room = _localRooms[code];
          if (room == null) return;
          final offlineIds = <String>[];
          for (final entry in raw.entries) {
            final value = entry.value;
            final isOnline = value is Map
                ? (value['online'] as bool?) ?? false
                : value == true;
            if (!isOnline) offlineIds.add(entry.key.toString());
          }
          offlineIds.remove(localPlayerId);
          if (offlineIds.isEmpty) return;
          final currentPlayers = room.players;
          final removedNames = <String>[];
          var updated = false;
          for (final id in offlineIds) {
            final removedPlayer = currentPlayers
                .where((p) => p.id == id)
                .toList();
            if (removedPlayer.isEmpty) continue;
            removedNames.add(removedPlayer.first.name);
            updated = true;
          }
          if (!updated) return;
          final remainingPlayers = currentPlayers
              .where((p) => !offlineIds.contains(p.id))
              .toList();
          final updatedRoom = RoomData(
            code: room.code,
            hostId: room.hostId,
            boardType: room.boardType,
            players: remainingPlayers,
            status: room.status,
            gameState: room.gameState,
            isTeamUp: room.isTeamUp,
            targetPlayerCount: room.targetPlayerCount,
          );
          _localRooms[code] = updatedRoom;
          _roomController.add(updatedRoom);
          unawaited(_persistOfflinePlayers(code, offlineIds));
          if (removedNames.isNotEmpty) {
            _chatController.add(_localChats[code] ?? const <ChatMessage>[]);
          }
        } catch (e) {
          debugPrint('[OnlineService] Error parsing presence update: $e');
        }
      });

      _actionSubscription = ref.child('actions').onChildAdded.listen((event) {
        try {
          final action = OnlineAction.fromSnapshot(event.snapshot);
          if (action.id.isNotEmpty && action.actorId.isNotEmpty) {
            _actionController.add(action);
          }
        } catch (e) {
          debugPrint('[OnlineService] Error parsing action: $e');
        }
      });

      final infoRef = FirebaseDatabase.instance.ref('.info/connected');
      _connectionSubscription = infoRef.onValue.listen((event) {
        if (event.snapshot.value == true && currentRoomCode == code) {
          unawaited(_registerPresenceSafely(code));
        }
      });
    }
  }

  Future<void> _registerPresence(String code) async {
    final ref = _presenceRef(code);
    if (ref == null || localPlayerId == null) return;
    final node = ref.child(localPlayerId!);
    await node.onDisconnect().set({
      'online': false,
      'updatedAt': ServerValue.timestamp,
    });
    await node.set({'online': true, 'updatedAt': ServerValue.timestamp});
  }

  Future<void> _registerPresenceSafely(String code) async {
    try {
      await _registerPresence(code);
    } catch (e) {
      debugPrint('[OnlineService] Presence registration failed: $e');
    }
  }

  Future<void> _persistOfflinePlayers(
    String code,
    List<String> offlineIds,
  ) async {
    if (offlineIds.isEmpty) return;
    final ref = _roomRef(code);
    if (ref == null) return;
    try {
      await ref.runTransaction((data) {
        if (data == null) return Transaction.abort();
        final roomMap = _deepConvert(data);
        if (roomMap is! Map) return Transaction.abort();
        final playersRaw = roomMap['players'];
        if (playersRaw is! List) return Transaction.abort();
        final players = playersRaw
            .where((item) => item is Map && !offlineIds.contains(item['id']))
            .toList();
        if (players.isEmpty) return Transaction.success(null);
        final hostId = roomMap['hostId'];
        final nextHost = offlineIds.contains(hostId)
            ? (players.first as Map)['id']
            : hostId;
        roomMap['players'] = players;
        roomMap['hostId'] = nextHost;

        final gameStateRaw = roomMap['gameState'];
        if (gameStateRaw is Map) {
          try {
            final boardType = _safeEnum(
              BoardType.values,
              gameStateRaw['boardType'],
              _safeEnum(
                BoardType.values,
                roomMap['boardType'],
                BoardType.classic4,
              ),
            );
            final statePlayers = players
                .whereType<Map>()
                .map(
                  (player) =>
                      Player.fromJson(Map<String, dynamic>.from(player)),
                )
                .toList();
            if (statePlayers.length >= 2) {
              final gameState = GameState(
                boardType: boardType,
                players: statePlayers,
              );
              gameState.loadFromJson(
                Map<String, dynamic>.from(gameStateRaw),
                force: true,
              );
              roomMap['gameState'] = gameState.toJson();
            } else {
              roomMap.remove('gameState');
            }
          } catch (e) {
            debugPrint(
              '[OnlineService] Could not prune offline game state: $e',
            );
          }
        }
        return Transaction.success(roomMap);
      });
    } catch (e) {
      debugPrint('[OnlineService] Offline roster persistence failed: $e');
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
    _validateRoomConfig(
      boardType: boardType,
      targetPlayerCount: targetPlayerCount,
      isTeamUp: isTeamUp,
    );
    final code = RoomCodeGenerator.generate();
    final player = Player(
      id: localPlayerId!,
      name: playerName,
      color:
          preferredColor ??
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
        await _registerPresence(code);
        debugPrint(
          '[OnlineService] Room $code created successfully on Firebase.',
        );
        _listenToRoom(code);
      } catch (e, stack) {
        debugPrint(
          '[OnlineService] ERROR creating room $code on Firebase: $e\n$stack',
        );
        _localRooms.remove(code);
        currentRoomCode = null;
        rethrow;
      }
    } else {
      _localRooms.remove(code);
      currentRoomCode = null;
      throw StateError('Online service is unavailable.');
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
    final ref = _roomRef(cleanCode);
    if (ref == null) {
      return JoinRoomResult(error: 'Online service is unavailable.');
    }

    RoomData room;
    try {
      final snapshot = await ref.get();
      if (!snapshot.exists || snapshot.value == null) {
        return JoinRoomResult(
          error:
              'Room "$cleanCode" not found! Check the room code and try again.',
        );
      }
      final data = _deepConvert(snapshot.value) as Map<String, dynamic>;
      data.remove('chat');
      room = RoomData.fromJson(data);
    } catch (e, stack) {
      debugPrint('[OnlineService] ERROR fetching room $cleanCode: $e\n$stack');
      return JoinRoomResult(
        error: 'Unable to reach room "$cleanCode". Try again.',
      );
    }

    final existing = room.players
        .where((p) => p.id == localPlayerId)
        .firstOrNull;
    if (room.status != RoomStatus.waiting && existing == null) {
      return JoinRoomResult(
        error: 'Match in room "$cleanCode" has already started!',
      );
    }
    final ids = room.players.map((p) => p.id).toSet();
    final colors = room.players.map((p) => p.color).toSet();
    if (ids.length != room.players.length ||
        colors.length != room.players.length ||
        room.players.length > room.maxPlayers) {
      return JoinRoomResult(
        error: 'Room "$cleanCode" has invalid player data.',
      );
    }

    if (existing != null) {
      _localRooms[cleanCode] = room;
      currentRoomCode = cleanCode;
      _listenToRoom(cleanCode);
      await _registerPresenceSafely(cleanCode);
      return JoinRoomResult(room: room);
    }
    if (room.isFull) {
      return JoinRoomResult(error: 'Room "$cleanCode" is already full!');
    }

    final allColors = room.boardType == BoardType.classic4
        ? [
            PlayerColor.red,
            PlayerColor.green,
            PlayerColor.yellow,
            PlayerColor.blue,
          ]
        : PlayerColor.values;
    final usedColors = room.players.map((p) => p.color).toSet();
    if (preferredColor != null && usedColors.contains(preferredColor)) {
      return JoinRoomResult(
        error:
            'Color "${preferredColor.label}" is already selected by another player! Please choose a different color.',
      );
    }
    final availableColor =
        preferredColor ?? allColors.firstWhere((c) => !usedColors.contains(c));
    final playerIndex = room.players.length;
    final player = Player(
      id: localPlayerId!,
      name: playerName,
      color: availableColor,
      type: PlayerType.human,
      avatarIndex: avatarIndex,
      teamId: room.isTeamUp ? playerIndex % 2 : null,
    );

    try {
      final transaction = await ref.child('players').runTransaction((data) {
        final converted = data == null ? <dynamic>[] : _deepConvert(data);
        if (converted is! List) return Transaction.abort();
        final current = converted;
        if (current.any((item) => item is Map && item['id'] == localPlayerId)) {
          return Transaction.success(current);
        }
        if (current.any(
          (item) => item is Map && item['color'] == player.color.index,
        )) {
          return Transaction.abort();
        }
        if (current.length >= room.maxPlayers) return Transaction.abort();
        return Transaction.success([...current, player.toJson()]);
      });
      if (!transaction.committed) {
        return JoinRoomResult(
          error: 'The room changed. Check capacity and choose another color.',
        );
      }

      final updatedRoom = RoomData(
        code: room.code,
        hostId: room.hostId,
        boardType: room.boardType,
        players: [...room.players, player],
        status: room.status,
        gameState: room.gameState,
        isTeamUp: room.isTeamUp,
        targetPlayerCount: room.targetPlayerCount,
      );
      _localRooms[cleanCode] = updatedRoom;
      currentRoomCode = cleanCode;
      _listenToRoom(cleanCode);
      await _registerPresenceSafely(cleanCode);
      return JoinRoomResult(room: updatedRoom);
    } catch (e, stack) {
      debugPrint('[OnlineService] ERROR joining room $cleanCode: $e\n$stack');
      _localRooms.remove(cleanCode);
      if (currentRoomCode == cleanCode) currentRoomCode = null;
      return JoinRoomResult(
        error: 'Unable to join room "$cleanCode". Try again.',
      );
    }
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
    if (room == null ||
        room.hostId != localPlayerId ||
        room.targetPlayerCount < 4) {
      return false;
    }
    final colors = room.boardType == BoardType.classic4
        ? [
            PlayerColor.red,
            PlayerColor.green,
            PlayerColor.yellow,
            PlayerColor.blue,
          ]
        : PlayerColor.values;
    final used = room.players.map((p) => p.color).toSet();
    final players = [...room.players];
    var botNumber = 1;
    while (players.length < room.maxPlayers) {
      final color = colors.firstWhere((c) => !used.contains(c));
      used.add(color);
      final index = players.length;
      players.add(
        Player(
          id: 'bot_${room.code}_$botNumber',
          name: 'Bot $botNumber',
          color: color,
          type: PlayerType.ai,
          difficulty: AIDifficulty.medium,
          teamId: room.isTeamUp ? index % 2 : null,
        ),
      );
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
    final ref = _roomRef(room.code);
    if (ref == null) return false;
    try {
      await ref.child('players').set(players.map((p) => p.toJson()).toList());
      _localRooms[room.code] = updated;
      return true;
    } catch (e) {
      debugPrint('[OnlineService] Bot fill failed: $e');
      return false;
    }
  }

  Future<bool> setTeamUpPair({required String teammateId}) async {
    if (currentRoomCode == null) return false;
    final room = _localRooms[currentRoomCode!];
    if (room == null ||
        room.hostId != localPlayerId ||
        !room.isTeamUp ||
        room.players.length != 4) {
      return false;
    }

    final hostIndex = room.players.indexWhere((p) => p.id == localPlayerId);
    final teammateIndex = room.players.indexWhere((p) => p.id == teammateId);
    if (hostIndex < 0 || teammateIndex < 0 || teammateId == localPlayerId) {
      return false;
    }

    final updatedPlayers = <Player>[];
    for (var i = 0; i < room.players.length; i++) {
      final player = room.players[i];
      final teamId = (player.id == localPlayerId || player.id == teammateId)
          ? 0
          : 1;
      updatedPlayers.add(player.copyWith(teamId: teamId));
    }

    final updated = RoomData(
      code: room.code,
      hostId: room.hostId,
      boardType: room.boardType,
      players: updatedPlayers,
      status: room.status,
      gameState: room.gameState,
      isTeamUp: room.isTeamUp,
      targetPlayerCount: room.targetPlayerCount,
    );
    final ref = _roomRef(room.code);
    if (ref == null) return false;
    try {
      await ref
          .child('players')
          .set(updatedPlayers.map((p) => p.toJson()).toList());
      _localRooms[room.code] = updated;
      await _registerPresenceSafely(room.code);
      return true;
    } catch (e) {
      debugPrint('[OnlineService] Team pairing failed: $e');
      return false;
    }
  }

  Future<void> startGame() async {
    if (currentRoomCode == null) return;
    final room = _localRooms[currentRoomCode!];
    if (room == null ||
        room.hostId != localPlayerId ||
        room.players.length < 2 ||
        (room.isTeamUp && room.players.length != 4)) {
      return;
    }

    final initialState = GameState(
      boardType: room.boardType,
      players: room.players,
    );

    final updatedRoom = RoomData(
      code: room.code,
      hostId: room.hostId,
      boardType: room.boardType,
      players: room.players,
      status: RoomStatus.playing,
      gameState: initialState.toJson(),
      isTeamUp: room.isTeamUp,
      targetPlayerCount: room.targetPlayerCount,
    );

    final code = currentRoomCode!;
    final ref = _roomRef(code);
    if (ref == null) throw StateError('Online service is unavailable.');
    try {
      await ref.update({
        'players': room.players.map((p) => p.toJson()).toList(),
        'gameState': initialState.toJson(),
        'status': RoomStatus.playing.index,
      });
      _localRooms[code] = updatedRoom;
      await _registerPresenceSafely(code);
    } catch (e) {
      debugPrint('[OnlineService] Start-game write failed: $e');
      rethrow;
    }
  }

  /// Sync game state to room
  Future<void> syncGameState(GameState state) async {
    if (currentRoomCode == null || !isLocalHost) return;
    final room = _localRooms[currentRoomCode!];
    if (room == null) return;

    final updatedRoom = RoomData(
      code: room.code,
      hostId: room.hostId,
      boardType: room.boardType,
      players: room.players,
      status: room.status,
      gameState: state.toJson(),
      isTeamUp: room.isTeamUp,
      targetPlayerCount: room.targetPlayerCount,
    );

    final code = currentRoomCode!;
    final ref = _roomRef(code);
    if (ref != null) {
      try {
        final payload = state.toJson();
        final transaction = await ref.child('gameState').runTransaction((data) {
          final current = data == null ? null : _deepConvert(data);
          if (current is Map) {
            final currentVersion =
                (current['stateVersion'] as num?)?.toInt() ?? 0;
            final incomingVersion =
                (payload['stateVersion'] as num?)?.toInt() ?? 0;
            if (currentVersion >= incomingVersion) return Transaction.abort();
          }
          return Transaction.success(payload);
        });

        if (transaction.committed) {
          _localRooms[code] = updatedRoom;
        } else {
          // First writer wins for a turn; reload the authoritative state.
          final latest = await ref.child('gameState').get();
          if (latest.exists && latest.value != null) {
            final latestJson =
                _deepConvert(latest.value) as Map<String, dynamic>;
            state.loadFromJson(latestJson, force: true);
            _localRooms[room.code] = RoomData(
              code: room.code,
              hostId: room.hostId,
              boardType: room.boardType,
              players: room.players,
              status: room.status,
              gameState: latestJson,
              isTeamUp: room.isTeamUp,
              targetPlayerCount: room.targetPlayerCount,
            );
          }
        }
      } catch (e) {
        debugPrint('[OnlineService] Game-state write failed: $e');
      }
    } else {
      throw StateError('Online service is unavailable.');
    }
  }

  /// Store completed game leaderboard data and delete active room data
  Future<void> storeFinishedMatch(GameState state) async {
    if (currentRoomCode == null || !isLocalHost) return;
    final code = currentRoomCode!;
    try {
      final leaderboardRef = FirebaseDatabase.instance.ref(
        'leaderboards/$code',
      );
      await leaderboardRef.set({
        'roomCode': code,
        'finishedAt': DateTime.now().millisecondsSinceEpoch,
        'winnerName': state.winner != null
            ? state.players[state.winner!].name
            : 'Unknown',
        'winnerColor': state.winner != null
            ? state.players[state.winner!].color.label
            : '',
        'players': state.players
            .map(
              (p) => {
                'name': p.name,
                'color': p.color.label,
                'avatarIndex': p.avatarIndex,
              },
            )
            .toList(),
        'rankings': state.finishOrder
            .map(
              (idx) => {
                'rank': state.finishOrder.indexOf(idx) + 1,
                'name': state.players[idx].name,
                'color': state.players[idx].color.label,
              },
            )
            .toList(),
      });
    } catch (e) {
      debugPrint('[OnlineService] Leaderboard write failed: $e');
    }

    try {
      final roomRef = _roomRef(code);
      if (roomRef != null) await roomRef.remove();
    } catch (e) {
      debugPrint('[OnlineService] Finished-room cleanup failed: $e');
    } finally {
      final room = _localRooms.remove(code);
      currentRoomCode = null;
      if (room != null) {
        _roomController.add(
          RoomData(
            code: room.code,
            hostId: room.hostId,
            boardType: room.boardType,
            players: const [],
            status: RoomStatus.finished,
            isTeamUp: room.isTeamUp,
            targetPlayerCount: room.targetPlayerCount,
          ),
        );
      }
    }
  }

  /// Leave room gracefully
  Future<void> leaveRoom() async {
    final code = currentRoomCode;
    _firebaseSubscription?.cancel();
    _chatSubscription?.cancel();
    _chatChildSubscription?.cancel();
    _presenceSubscription?.cancel();
    _actionSubscription?.cancel();
    _connectionSubscription?.cancel();
    _firebaseSubscription = null;
    _chatSubscription = null;
    _chatChildSubscription = null;
    _presenceSubscription = null;
    _actionSubscription = null;
    _connectionSubscription = null;
    if (code == null) return;

    final room = _localRooms[code];
    final ref = _roomRef(code);

    final presence = _presenceRef(code);
    if (presence != null && localPlayerId != null) {
      try {
        await presence.child(localPlayerId!).set({
          'online': false,
          'updatedAt': ServerValue.timestamp,
        });
      } catch (e) {
        debugPrint('[OnlineService] Presence leave update failed: $e');
      }
    }

    if (room != null && room.hostId != localPlayerId) {
      _localRooms.remove(code);
      currentRoomCode = null;
      return;
    }

    if (ref != null && room != null) {
      try {
        final remainingPlayers = room.players
            .where((p) => p.id != localPlayerId)
            .toList();
        if (remainingPlayers.isEmpty) {
          // All players left -> remove room node
          await ref.remove();
        } else {
          // Host or player leaves -> migrate host role to next player and remove leaving player from gameState
          final newHostId = (room.hostId == localPlayerId)
              ? remainingPlayers.first.id
              : room.hostId;

          Map<String, dynamic>? updatedStateJson;
          if (room.gameState != null) {
            try {
              final tempState = GameState(
                boardType: room.boardType,
                players: room.players,
              );
              tempState.loadFromJson(room.gameState!);
              tempState.removePlayerById(localPlayerId!);
              updatedStateJson = tempState.toJson();
            } catch (e) {
              debugPrint(
                '[OnlineService] Error updating gameState on leave: $e',
              );
            }
          }

          final updates = <String, dynamic>{
            'hostId': newHostId,
            'players': remainingPlayers.map((p) => p.toJson()).toList(),
          };
          if (updatedStateJson != null) {
            updates['gameState'] = updatedStateJson;
          }

          await ref.update(updates);

          if (presence != null) {
            await presence.child(localPlayerId!).remove();
          }
        }
      } catch (e) {
        debugPrint('[OnlineService] Error leaving room: $e');
      }
    }

    _localRooms.remove(code);
    currentRoomCode = null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _firebaseSubscription?.cancel();
    _chatSubscription?.cancel();
    _chatChildSubscription?.cancel();
    _presenceSubscription?.cancel();
    _actionSubscription?.cancel();
    _connectionSubscription?.cancel();
    _roomController.close();
    _chatController.close();
    _actionController.close();
  }
}
