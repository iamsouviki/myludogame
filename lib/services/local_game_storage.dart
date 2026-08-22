import 'dart:convert';

import '../models/game_state.dart';
import '../models/player.dart';
import '../utils/constants.dart';
import 'browser_storage.dart';

class LocalGameStorage {
  static const _key = 'myludo.savedLocalGame.v1';

  static GameState? loadGame() {
    final raw = readBrowserStorage(_key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final data = Map<String, dynamic>.from(json);
      final rawPlayers = data['players'];
      if (rawPlayers is! List) return null;
      final players = rawPlayers
          .whereType<Map>()
          .map((player) => Player.fromJson(Map<String, dynamic>.from(player)))
          .toList();
      if (players.length < 2) return null;

      final boardIndex = (data['boardType'] as num?)?.toInt() ?? BoardType.classic4.index;
      if (boardIndex < 0 || boardIndex >= BoardType.values.length) return null;

      final state = GameState(
        boardType: BoardType.values[boardIndex],
        players: players,
      );
      state.stateVersion = -1;
      state.loadFromJson(data);
      return state.isGameOver ? null : state;
    } catch (_) {
      // Corrupt or old local storage should never prevent the app from opening.
      removeGame();
      return null;
    }
  }

  static void saveGame(GameState state) {
    if (state.isGameOver) {
      removeGame();
      return;
    }
    try {
      writeBrowserStorage(_key, jsonEncode(state.toJson()));
    } catch (_) {}
  }

  static void removeGame() => removeBrowserStorage(_key);
}
