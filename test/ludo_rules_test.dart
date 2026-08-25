import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ludo/game/board_config.dart';
import 'package:my_ludo/models/dice.dart';
import 'package:my_ludo/models/game_state.dart';
import 'package:my_ludo/models/six_player_rules.dart';
import 'package:my_ludo/services/game_service.dart';
import 'package:my_ludo/services/online_service.dart';
import 'package:my_ludo/models/player.dart';
import 'package:my_ludo/utils/constants.dart';

class MockDice implements Dice {
  final List<int> rolls;
  int _index = 0;

  MockDice(this.rolls);

  @override
  int roll() {
    final val = rolls[_index % rolls.length];
    _index++;
    return val;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Ludo King Rules Validation', () {
    late GameState state;

    setUp(() {
      final players = [
        const Player(
          id: 'p1',
          name: 'Red',
          color: PlayerColor.red,
          type: PlayerType.human,
        ),
        const Player(
          id: 'p2',
          name: 'Green',
          color: PlayerColor.green,
          type: PlayerType.human,
        ),
        const Player(
          id: 'p3',
          name: 'Yellow',
          color: PlayerColor.yellow,
          type: PlayerType.human,
        ),
        const Player(
          id: 'p4',
          name: 'Blue',
          color: PlayerColor.blue,
          type: PlayerType.human,
        ),
      ];
      state = GameState(boardType: BoardType.classic4, players: players);
    });

    test('Advancing a turn clears the active emoji', () {
      expect(state.setTurnEmoji('🔥'), isTrue);
      expect(state.activeEmoji, '🔥');
      expect(state.activeEmojiPlayerIndex, 0);

      state.advanceTurn();

      expect(state.activeEmoji, isNull);
      expect(state.activeEmojiPlayerIndex, isNull);
      expect(state.activeEmojiAt, isNull);
      expect(state.currentPlayerIndex, 1);
    });

    test('Single 6 grants extra turn', () {
      final mockDice = MockDice([6]);
      final testState = GameState(
        boardType: BoardType.classic4,
        players: state.players,
        dice: mockDice,
      );

      testState.rollDice();
      expect(testState.consecutiveSixes, 1);
      expect(testState.getsExtraRoll, true);
      expect(testState.currentPlayerIndex, 0);
    });

    test('Double 6 grants extra turn for both 6s', () {
      final mockDice = MockDice([6, 6]);
      final testState = GameState(
        boardType: BoardType.classic4,
        players: state.players,
        dice: mockDice,
      );

      testState.rollDice();
      expect(testState.consecutiveSixes, 1);
      expect(testState.getsExtraRoll, true);

      testState.moveToken(0);
      expect(testState.currentPlayerIndex, 0);

      testState.rollDice();
      expect(testState.consecutiveSixes, 2);
      expect(testState.getsExtraRoll, true);
      expect(testState.currentPlayerIndex, 0);
    });

    test('Triple 6 forfeits turn and passes to next player', () {
      final mockDice = MockDice([6, 6, 6]);
      final testState = GameState(
        boardType: BoardType.classic4,
        players: state.players,
        dice: mockDice,
      );

      testState.rollDice();
      testState.moveToken(0);
      expect(testState.tokenPositions[0][0], 0);
      testState.rollDice();
      testState.moveToken(0);
      expect(testState.tokenPositions[0][0], 6);
      testState.rollDice();

      // The third six is cancelled before movement; the second-six position remains.
      expect(testState.tokenPositions[0][0], 6);
      expect(testState.consecutiveSixes, 0);
      expect(testState.getsExtraRoll, false);
      expect(testState.currentPlayerIndex, 1);
      expect(testState.validTokenMoves.isEmpty, true);
    });

    test('A six exits base onto the start cell only', () {
      final mockDice = MockDice([6]);
      final testState = GameState(
        boardType: BoardType.classic4,
        players: state.players,
        dice: mockDice,
      );

      testState.rollDice();
      expect(testState.validTokenMoves, [0, 1, 2, 3]);
      testState.moveToken(0);

      expect(testState.tokenPositions[0][0], testState.startPosition(0));
    });

    test('Classic board starts and home entries match the painted track', () {
      expect(List.generate(4, state.startPosition), [0, 13, 26, 39]);
      expect(List.generate(4, state.homeEntryPosition), [50, 11, 24, 37]);
      expect(state.safeSpots, containsAll([0, 13, 26, 39]));
    });

    test('Each classic player enters home from the painted arrow cell', () {
      for (var playerIndex = 0; playerIndex < 4; playerIndex++) {
        final testState = GameState(
          boardType: BoardType.classic4,
          players: state.players,
          dice: MockDice([1]),
        );
        testState.currentPlayerIndex = playerIndex;
        testState.tokenPositions[playerIndex][0] = testState.homeEntryPosition(
          playerIndex,
        );

        testState.rollDice();

        expect(testState.validTokenMoves, contains(0));
        expect(testState.moveToken(0), isFalse);
        expect(
          testState.tokenPositions[playerIndex][0],
          BoardType.classic4.trackLength,
          reason: 'player $playerIndex must enter home from its arrow cell',
        );
      }
    });

    test('A classic player does not count the box before its home arrow', () {
      for (var playerIndex = 0; playerIndex < 4; playerIndex++) {
        final testState = GameState(
          boardType: BoardType.classic4,
          players: state.players,
          dice: MockDice([2]),
        );
        testState.currentPlayerIndex = playerIndex;
        testState.tokenPositions[playerIndex][0] =
            testState.homeEntryPosition(playerIndex) - 1;

        testState.rollDice();

        expect(testState.validTokenMoves, contains(0));
        expect(testState.moveToken(0), isFalse);
        expect(
          testState.tokenPositions[playerIndex][0],
          BoardType.classic4.trackLength,
          reason: 'player $playerIndex must not count the approach box',
        );
      }
    });

    test('Six-player routes follow colors rather than player-list order', () {
      final players = [
        const Player(
          id: 'orange',
          name: 'Orange',
          color: PlayerColor.orange,
          type: PlayerType.human,
        ),
        const Player(
          id: 'red',
          name: 'Red',
          color: PlayerColor.red,
          type: PlayerType.human,
        ),
        const Player(
          id: 'purple',
          name: 'Purple',
          color: PlayerColor.purple,
          type: PlayerType.human,
        ),
        const Player(
          id: 'green',
          name: 'Green',
          color: PlayerColor.green,
          type: PlayerType.human,
        ),
        const Player(
          id: 'blue',
          name: 'Blue',
          color: PlayerColor.blue,
          type: PlayerType.human,
        ),
        const Player(
          id: 'yellow',
          name: 'Yellow',
          color: PlayerColor.yellow,
          type: PlayerType.human,
        ),
      ];
      final testState = GameState(
        boardType: BoardType.hex6,
        players: players,
        dice: MockDice([6]),
      );

      expect(List.generate(6, testState.playerPositionIndex), [
        4,
        0,
        5,
        1,
        3,
        2,
      ]);
      expect(List.generate(6, testState.startPosition), [
        52,
        0,
        65,
        13,
        39,
        26,
      ]);
      expect(
        testState.safeSpots,
        containsAll([0, 13, 26, 39, 52, 65, 8, 21, 34, 47, 60, 73]),
      );

      testState.currentPlayerIndex = 0;
      testState.rollDice();
      expect(testState.validTokenMoves, [0, 1, 2, 3]);
      expect(testState.moveToken(0), isFalse);
      expect(testState.tokenPositions[0][0], 52);
    });

    test('Six-player home entries are one step before each player start', () {
      final players = BoardType.hex6.availableColors
          .asMap()
          .entries
          .map(
            (entry) => Player(
              id: 'p${entry.key}',
              name: entry.value.label,
              color: entry.value,
              type: PlayerType.human,
            ),
          )
          .toList();
      final testState = GameState(
        boardType: BoardType.hex6,
        players: players,
        dice: MockDice(List.filled(6, 1)),
      );

      for (var playerIndex = 0; playerIndex < players.length; playerIndex++) {
        testState.currentPlayerIndex = playerIndex;
        testState.tokenPositions[playerIndex][0] = testState.homeEntryPosition(
          playerIndex,
        );
        testState.rollDice();
        expect(testState.validTokenMoves, contains(0));
        expect(testState.moveToken(0), isFalse);
        expect(
          testState.tokenPositions[playerIndex][0],
          BoardType.hex6.trackLength,
        );
        testState.phase = GamePhase.rolling;
      }
    });

    test('Six-player home lanes move inward for every route slot', () {
      final config = BoardConfig(
        boardType: BoardType.hex6,
        canvasSize: const Size(200, 200),
      );

      for (var routeSlot = 0; routeSlot < 6; routeSlot++) {
        final entry = config.homeStretchPosition(routeSlot, 0);
        final lastLaneCell = config.homeStretchPosition(routeSlot, 4);
        final home = config.homeStretchPosition(routeSlot, 5);

        expect(
          (entry - config.center).distance,
          greaterThan((lastLaneCell - config.center).distance),
        );
        expect(
          (lastLaneCell - config.center).distance,
          greaterThan((home - config.center).distance),
        );
        expect(home, config.center);
      }

      final bases = [
        for (var routeSlot = 0; routeSlot < 6; routeSlot++)
          config.basePosition(routeSlot, 0),
      ];
      expect(bases.toSet().length, 6);
    });

    test('Star 6 geometry repeats six cleanly rotated sectors', () {
      final config = BoardConfig(
        boardType: BoardType.hex6,
        canvasSize: const Size(360, 360),
      );

      final startCells = [
        for (var slot = 0; slot < 6; slot++)
          config.trackCellPosition(slot * BoardType.hex6.cellsPerArm),
      ];
      final baseCenters = [
        for (var slot = 0; slot < 6; slot++) config.hex6BaseCenter(slot),
      ];

      expect(startCells.toSet().length, 6);
      expect(baseCenters.toSet().length, 6);
      for (var slot = 0; slot < 6; slot++) {
        final corners = config.hex6BaseCorners(slot);
        expect(corners.length, 3);
        final outward = corners.first - config.hex6BaseCenter(slot);
        final routeDirection =
            config.trackCellPosition(slot * BoardType.hex6.cellsPerArm) -
            config.center;
        expect(
          outward.dx * routeDirection.dx + outward.dy * routeDirection.dy,
          greaterThan(0),
          reason: 'Star 6 room $slot must point away from the center',
        );
        expect(
          {
            for (var token = 0; token < tokensPerPlayer; token++)
              config.basePosition(slot, token),
          }.length,
          tokensPerPlayer,
        );

        final entryDistance =
            (config.homeStretchPosition(slot, 0) - config.center).distance;
        final homeDistance =
            (config.homeStretchPosition(slot, 5) - config.center).distance;
        expect(entryDistance, greaterThan(homeDistance));
        expect(homeDistance, 0);
      }
    });

    test('Six-player room keeps six-seat capacity through serialization', () {
      final players = BoardType.hex6.availableColors
          .asMap()
          .entries
          .map(
            (entry) => Player(
              id: 'p${entry.key}',
              name: entry.value.label,
              color: entry.value,
              type: PlayerType.human,
            ),
          )
          .toList();
      final room = RoomData(
        code: 'ABC123',
        hostId: players.first.id,
        boardType: BoardType.hex6,
        players: players,
        targetPlayerCount: 6,
      );
      final restored = RoomData.fromJson(room.toJson());

      expect(room.maxPlayers, 6);
      expect(room.isFull, isTrue);
      expect(restored.maxPlayers, 6);
      expect(
        restored.players.map((player) => player.color),
        BoardType.hex6.availableColors,
      );
    });

    test(
      'Six-player local factory fills the six physical colors exactly once',
      () {
        final service = GameService.createLocalGame(
          boardType: BoardType.hex6,
          humanPlayers: 1,
          aiPlayers: 5,
          humanColors: [PlayerColor.orange],
        );

        expect(service.state.players.length, 6);
        expect(
          service.state.players.map((player) => player.color).toSet().length,
          6,
        );
        expect(
          service.state.players
              .map((player) => player.color)
              .every(BoardType.hex6.availableColors.contains),
          isTrue,
        );
      },
    );

    test('A token on green route can be captured on its first unsafe cell', () {
      final players = [
        const Player(
          id: 'red',
          name: 'Red',
          color: PlayerColor.red,
          type: PlayerType.human,
        ),
        const Player(
          id: 'green',
          name: 'Green',
          color: PlayerColor.green,
          type: PlayerType.human,
        ),
      ];
      final testState = GameState(
        boardType: BoardType.classic4,
        players: players,
        dice: MockDice([1]),
      );
      testState.tokenPositions[1][0] = testState.startPosition(1);
      testState.tokenPositions[0][0] = testState.startPosition(1) + 1;
      testState.currentPlayerIndex = 1;

      testState.rollDice();

      expect(testState.validTokenMoves, contains(0));
      expect(testState.moveToken(0), isTrue);
      expect(testState.tokenPositions[1][0], 14);
      expect(testState.tokenPositions[0][0], posInBase);
    });

    test('A token on a real start cell cannot be captured', () {
      final players = [
        const Player(
          id: 'red',
          name: 'Red',
          color: PlayerColor.red,
          type: PlayerType.human,
        ),
        const Player(
          id: 'green',
          name: 'Green',
          color: PlayerColor.green,
          type: PlayerType.human,
        ),
      ];
      final testState = GameState(
        boardType: BoardType.classic4,
        players: players,
        dice: MockDice([1]),
      );
      testState.tokenPositions[1][0] = testState.startPosition(1);
      testState.tokenPositions[0][0] = testState.startPosition(1) - 1;
      testState.currentPlayerIndex = 0;

      testState.rollDice();

      expect(testState.validTokenMoves, contains(0));
      expect(testState.moveToken(0), isFalse);
      expect(testState.tokenPositions[1][0], testState.startPosition(1));
    });

    test('A safe start is not treated as an opponent blockade', () {
      final mockDice = MockDice([6]);
      final testState = GameState(
        boardType: BoardType.classic4,
        players: state.players,
        dice: mockDice,
      );
      testState.tokenPositions[1][0] = testState.startPosition(0);
      testState.tokenPositions[1][1] = testState.startPosition(0);

      testState.rollDice();

      expect(testState.validTokenMoves, [0, 1, 2, 3]);
    });

    test('Two-player matches still preserve all classic safe cells', () {
      final players = [
        const Player(
          id: 'red',
          name: 'Red',
          color: PlayerColor.red,
          type: PlayerType.human,
        ),
        const Player(
          id: 'green',
          name: 'Green',
          color: PlayerColor.green,
          type: PlayerType.human,
        ),
      ];
      final testState = GameState(
        boardType: BoardType.classic4,
        players: players,
        dice: MockDice([1]),
      );
      testState.tokenPositions[0][0] = 33;
      testState.tokenPositions[1][0] = 34;

      testState.rollDice();

      expect(state.safeSpots, containsAll([26, 34, 39, 47]));
      expect(testState.validTokenMoves, contains(0));
      expect(testState.moveToken(0), isFalse);
      expect(testState.tokenPositions[1][0], 34);
    });

    test('An unsafe opponent blockade blocks a landing path', () {
      final mockDice = MockDice([2]);
      final testState = GameState(
        boardType: BoardType.classic4,
        players: state.players,
        dice: mockDice,
      );
      testState.tokenPositions[0][0] = 0;
      testState.tokenPositions[1][0] = 2;
      testState.tokenPositions[1][1] = 2;

      testState.rollDice();

      expect(testState.validTokenMoves, isNot(contains(0)));
    });

    test('A third friendly token cannot land on a two-token blockade', () {
      final mockDice = MockDice([1]);
      final testState = GameState(
        boardType: BoardType.classic4,
        players: state.players,
        dice: mockDice,
      );
      testState.tokenPositions[0][0] = 1;
      testState.tokenPositions[0][1] = 1;
      testState.tokenPositions[0][2] = 0;

      testState.rollDice();

      expect(testState.validTokenMoves, isNot(contains(2)));
    });

    test('A two-token stack on a safe square does not block movement', () {
      final players = [
        const Player(
          id: 'red',
          name: 'Red',
          color: PlayerColor.red,
          type: PlayerType.human,
        ),
        const Player(
          id: 'green',
          name: 'Green',
          color: PlayerColor.green,
          type: PlayerType.human,
        ),
      ];
      final testState = GameState(
        boardType: BoardType.classic4,
        players: players,
        dice: MockDice([1]),
      );
      testState.tokenPositions[0][0] = 7;
      testState.tokenPositions[1][0] = 8;
      testState.tokenPositions[1][1] = 8;

      testState.rollDice();

      expect(testState.validTokenMoves, contains(0));
      expect(testState.moveToken(0), isFalse);
      expect(testState.tokenPositions[0][0], 8);
      expect(testState.tokenPositions[1][0], 8);
      expect(testState.tokenPositions[1][1], 8);
    });

    test('Teammate tokens do not form a blockade or get captured', () {
      final players = [
        const Player(
          id: 'red',
          name: 'Red',
          color: PlayerColor.red,
          type: PlayerType.human,
          teamId: 0,
        ),
        const Player(
          id: 'green',
          name: 'Green',
          color: PlayerColor.green,
          type: PlayerType.human,
          teamId: 1,
        ),
        const Player(
          id: 'yellow',
          name: 'Yellow',
          color: PlayerColor.yellow,
          type: PlayerType.human,
          teamId: 0,
        ),
        const Player(
          id: 'blue',
          name: 'Blue',
          color: PlayerColor.blue,
          type: PlayerType.human,
          teamId: 1,
        ),
      ];
      final testState = GameState(
        boardType: BoardType.classic4,
        players: players,
        dice: MockDice([1]),
      );
      testState.tokenPositions[0][0] = 0;
      testState.tokenPositions[1][0] = 1;
      testState.tokenPositions[2][0] = 1;

      testState.rollDice();

      expect(testState.validTokenMoves, contains(0));
      expect(testState.moveToken(0), isTrue);
      expect(testState.tokenPositions[0][0], 1);
      expect(testState.tokenPositions[1][0], posInBase);
      expect(testState.tokenPositions[2][0], 1);
    });

    test(
      'GameService completes an animated capture and preserves the extra turn',
      () async {
        final players = [
          const Player(
            id: 'red',
            name: 'Red',
            color: PlayerColor.red,
            type: PlayerType.human,
          ),
          const Player(
            id: 'green',
            name: 'Green',
            color: PlayerColor.green,
            type: PlayerType.human,
          ),
        ];
        final testState = GameState(
          boardType: BoardType.classic4,
          players: players,
          dice: MockDice([1]),
        );
        testState.tokenPositions[0][0] = 0;
        testState.tokenPositions[1][0] = 1;
        final service = GameService(
          state: testState,
          runAI: false,
          displayDelay: Duration.zero,
        );

        service.start();
        service.rollDice();
        service.selectToken(0);
        await Future<void>.delayed(const Duration(milliseconds: 2100));

        expect(testState.tokenPositions[0][0], 1);
        expect(testState.tokenPositions[1][0], posInBase);
        expect(testState.currentPlayerIndex, 0);
        expect(testState.phase, GamePhase.rolling);
        service.dispose();
      },
    );

    test('Every unsafe one-step capture path remains selectable', () {
      final players = [
        for (var i = 0; i < 4; i++)
          Player(
            id: 'p$i',
            name: 'Player $i',
            color: PlayerColor.values[i],
            type: PlayerType.human,
          ),
      ];

      for (var playerIndex = 0; playerIndex < players.length; playerIndex++) {
        for (
          var distance = 1;
          distance < BoardType.classic4.trackLength - 1;
          distance++
        ) {
          final testState = GameState(
            boardType: BoardType.classic4,
            players: players,
            dice: MockDice([1]),
          );
          final position =
              (testState.startPosition(playerIndex) + distance) %
              BoardType.classic4.trackLength;
          if (position == testState.homeEntryPosition(playerIndex)) continue;
          final target = (position + 1) % BoardType.classic4.trackLength;
          testState.tokenPositions[playerIndex][0] = position;
          testState.tokenPositions[(playerIndex + 1) % players.length][0] =
              target;
          testState.currentPlayerIndex = playerIndex;

          testState.rollDice();

          expect(
            testState.validTokenMoves,
            contains(0),
            reason: 'player=$playerIndex position=$position target=$target',
          );
        }
      }
    });

    test('AI advances from a saved no-move state', () async {
      final players = [
        const Player(
          id: 'ai',
          name: 'Bot',
          color: PlayerColor.red,
          type: PlayerType.ai,
        ),
        const Player(
          id: 'human',
          name: 'Human',
          color: PlayerColor.green,
          type: PlayerType.human,
        ),
      ];
      final testState =
          GameState(boardType: BoardType.classic4, players: players)
            ..phase = GamePhase.moving
            ..lastDiceRoll = 1;
      final service = GameService(
        state: testState,
        displayDelay: Duration.zero,
      );

      service.start();
      await Future<void>.delayed(Duration.zero);

      expect(testState.currentPlayerIndex, 1);
      expect(testState.phase, GamePhase.rolling);
      service.dispose();
    });

    test('A stale remote revision is ignored', () {
      final testState = GameState(
        boardType: BoardType.classic4,
        players: state.players,
      );
      testState.rollDice();
      final currentVersion = testState.stateVersion;

      testState.loadFromJson({
        'stateVersion': currentVersion - 1,
        'currentPlayerIndex': 1,
        'phase': GamePhase.rolling.index,
      });

      expect(testState.stateVersion, currentVersion);
      expect(testState.currentPlayerIndex, 0);
    });

    test('A token can land on and cut one opponent on an unsafe cell', () {
      final players = [
        const Player(
          id: 'red',
          name: 'Red',
          color: PlayerColor.red,
          type: PlayerType.human,
        ),
        const Player(
          id: 'green',
          name: 'Green',
          color: PlayerColor.green,
          type: PlayerType.human,
        ),
      ];
      final testState = GameState(
        boardType: BoardType.classic4,
        players: players,
        dice: MockDice([1]),
      );
      testState.tokenPositions[0][0] = 0;
      testState.tokenPositions[1][0] = 1;

      testState.rollDice();

      expect(testState.validTokenMoves, contains(0));
      expect(testState.moveToken(0), isTrue);
      expect(testState.tokenPositions[0][0], 1);
      expect(testState.tokenPositions[1][0], posInBase);
      expect(testState.currentPlayerIndex, 0);
      expect(testState.phase, GamePhase.rolling);
    });

    test(
      'A token remains movable after an opponent has a legal capture path',
      () {
        final players = [
          const Player(
            id: 'red',
            name: 'Red',
            color: PlayerColor.red,
            type: PlayerType.human,
          ),
          const Player(
            id: 'green',
            name: 'Green',
            color: PlayerColor.green,
            type: PlayerType.human,
          ),
        ];
        final testState = GameState(
          boardType: BoardType.classic4,
          players: players,
          dice: MockDice([1]),
        );
        testState.tokenPositions[0][0] = 1;
        testState.tokenPositions[1][0] = 0;

        testState.currentPlayerIndex = 1;
        testState.rollDice();

        expect(testState.validTokenMoves, contains(0));
        expect(testState.moveToken(0), isTrue);
        expect(testState.tokenPositions[1][0], 1);
        expect(testState.tokenPositions[0][0], posInBase);
      },
    );

    test(
      'A completed player loses extra-roll and the next active player rolls',
      () {
        final players = [
          for (var i = 0; i < 3; i++)
            Player(
              id: 'p$i',
              name: 'Player $i',
              color: BoardType.classic4.availableColors[i],
              type: PlayerType.human,
            ),
        ];
        final testState = GameState(
          boardType: BoardType.classic4,
          players: players,
        );
        for (var token = 0; token < tokensPerPlayer - 1; token++) {
          testState.tokenPositions[0][token] = posHome;
        }
        testState.tokenPositions[0][tokensPerPlayer - 1] =
            testState.boardType.trackLength +
            testState.boardType.homeStretchLength -
            1;
        testState.currentPlayerIndex = 0;
        testState.phase = GamePhase.moving;
        testState.lastDiceRoll = 1;
        testState.validTokenMoves = [tokensPerPlayer - 1];

        testState.moveToken(tokensPerPlayer - 1);

        expect(testState.hasPlayerFinished(0), isTrue);
        expect(testState.getsExtraRoll, isFalse);
        expect(testState.finishOrder, [0]);
        expect(testState.currentPlayerIndex, 1);
        expect(testState.phase, GamePhase.rolling);
      },
    );

    test('Turn rotation skips finished players when only two remain', () {
      final players = [
        for (var i = 0; i < 3; i++)
          Player(
            id: 'p$i',
            name: 'Player $i',
            color: BoardType.classic4.availableColors[i],
            type: PlayerType.human,
          ),
      ];
      final testState = GameState(
        boardType: BoardType.classic4,
        players: players,
      );
      testState.tokenPositions[2] = List.filled(tokensPerPlayer, posHome);
      testState.finishOrder = [2];
      testState.currentPlayerIndex = 1;

      testState.advanceTurn();

      expect(testState.currentPlayerIndex, 0);
      expect(testState.phase, GamePhase.rolling);
    });

    test('Game ends when three of four players finish', () {
      final testState = GameState(
        boardType: BoardType.classic4,
        players: state.players,
      );
      testState.finishOrder = [1, 2];
      testState.winner = 1;
      for (var token = 0; token < tokensPerPlayer - 1; token++) {
        testState.tokenPositions[0][token] = posHome;
      }
      testState.tokenPositions[0][tokensPerPlayer - 1] =
          testState.boardType.trackLength +
          testState.boardType.homeStretchLength -
          1;
      testState.currentPlayerIndex = 0;
      testState.phase = GamePhase.moving;
      testState.lastDiceRoll = 1;
      testState.validTokenMoves = [tokensPerPlayer - 1];

      testState.moveToken(tokensPerPlayer - 1);

      expect(testState.phase, GamePhase.finished);
      expect(testState.winner, 1);
      expect(testState.finishOrder, [1, 2, 0, 3]);
      expect(testState.hasPlayerFinished(3), isFalse);

      // The remaining player is recorded as last place but cannot roll.
      testState.currentPlayerIndex = 3;
      expect(testState.rollDice(), 0);
      expect(testState.phase, GamePhase.finished);
    });

    test('Completing all tokens with a six does not grant another turn', () {
      final testState = GameState(
        boardType: BoardType.classic4,
        players: state.players,
        dice: MockDice([6]),
      );
      for (var token = 0; token < tokensPerPlayer - 1; token++) {
        testState.tokenPositions[0][token] = posHome;
      }
      testState.tokenPositions[0][tokensPerPlayer - 1] = testState
          .homeEntryPosition(0);
      testState.currentPlayerIndex = 0;
      testState.phase = GamePhase.rolling;

      testState.rollDice();
      expect(testState.validTokenMoves, [tokensPerPlayer - 1]);
      testState.moveToken(tokensPerPlayer - 1);

      expect(testState.hasPlayerFinished(0), isTrue);
      expect(testState.finishOrder, [0]);
      expect(testState.getsExtraRoll, isFalse);
      expect(testState.currentPlayerIndex, 1);
      expect(testState.phase, GamePhase.rolling);
    });

    test('A restored completed player is normalized before rolling', () {
      final testState = GameState(
        boardType: BoardType.classic4,
        players: state.players,
        dice: MockDice([6]),
      );
      testState.tokenPositions[0] = List.filled(tokensPerPlayer, posHome);
      testState.currentPlayerIndex = 0;
      testState.phase = GamePhase.rolling;

      expect(testState.rollDice(), 0);
      expect(testState.currentPlayerIndex, 1);
      expect(testState.phase, GamePhase.rolling);
      expect(testState.lastDiceRoll, isNull);
    });

    test(
      'A six with no legal move passes for every home-row/home distribution',
      () async {
        for (var playerIndex = 0; playerIndex < 4; playerIndex++) {
          for (
            var rowTokenCount = 1;
            rowTokenCount <= tokensPerPlayer;
            rowTokenCount++
          ) {
            final testState = GameState(
              boardType: BoardType.classic4,
              players: state.players,
              dice: MockDice([6]),
            );
            final blockedRowPosition =
                testState.boardType.trackLength +
                testState.boardType.homeStretchLength -
                2;
            for (var token = 0; token < tokensPerPlayer; token++) {
              testState.tokenPositions[playerIndex][token] =
                  token < rowTokenCount ? blockedRowPosition : posHome;
            }
            testState.currentPlayerIndex = playerIndex;
            testState.phase = GamePhase.rolling;
            final service = GameService(
              state: testState,
              runAI: true,
              displayDelay: Duration.zero,
            );

            service.start();
            testState.rollDice();
            expect(testState.validTokenMoves, isEmpty);
            expect(testState.getsExtraRoll, isFalse);
            service.recoverNoMoveTurn();
            await Future<void>.delayed(Duration.zero);

            expect(testState.currentPlayerIndex, (playerIndex + 1) % 4);
            expect(testState.phase, GamePhase.rolling);
            expect(testState.getsExtraRoll, isFalse);
            service.dispose();
          }
        }
      },
    );

    test('Team mode ends only after both teammates finish', () {
      final players = [
        const Player(
          id: 'a1',
          name: 'A1',
          color: PlayerColor.red,
          type: PlayerType.human,
          teamId: 0,
        ),
        const Player(
          id: 'a2',
          name: 'A2',
          color: PlayerColor.green,
          type: PlayerType.human,
          teamId: 0,
        ),
        const Player(
          id: 'b1',
          name: 'B1',
          color: PlayerColor.yellow,
          type: PlayerType.human,
          teamId: 1,
        ),
        const Player(
          id: 'b2',
          name: 'B2',
          color: PlayerColor.blue,
          type: PlayerType.human,
          teamId: 1,
        ),
      ];
      final testState = GameState(
        boardType: BoardType.classic4,
        players: players,
      );

      for (var token = 0; token < tokensPerPlayer - 1; token++) {
        testState.tokenPositions[0][token] = posHome;
        testState.tokenPositions[1][token] = posHome;
      }
      testState.tokenPositions[0][tokensPerPlayer - 1] =
          testState.boardType.trackLength +
          testState.boardType.homeStretchLength -
          1;
      testState.currentPlayerIndex = 0;
      testState.phase = GamePhase.moving;
      testState.lastDiceRoll = 1;
      testState.validTokenMoves = [tokensPerPlayer - 1];

      expect(testState.moveToken(tokensPerPlayer - 1), isFalse);
      expect(testState.phase, isNot(GamePhase.finished));

      testState.tokenPositions[1][tokensPerPlayer - 1] =
          testState.boardType.trackLength +
          testState.boardType.homeStretchLength -
          1;
      testState.currentPlayerIndex = 1;
      testState.phase = GamePhase.moving;
      testState.lastDiceRoll = 1;
      testState.validTokenMoves = [tokensPerPlayer - 1];
      testState.moveToken(tokensPerPlayer - 1);
      expect(testState.phase, GamePhase.finished);
      expect(testState.winner, 1);
    });

    test('Reset increments the online revision', () {
      final before = state.stateVersion;
      state.reset();
      expect(state.stateVersion, before + 1);
    });

    test('Room capacity is clamped to the selected board maximum', () {
      final room = RoomData.fromJson({
        'code': 'ABC123',
        'hostId': 'host',
        'boardType': BoardType.classic4.index,
        'players': [],
        'targetPlayerCount': 6,
      });
      expect(room.maxPlayers, 4);
    });

    test('Star 6 ends after five players finish', () {
      final players = [
        for (var i = 0; i < BoardType.hex6.maxPlayers; i++)
          Player(
            id: 'star_$i',
            name: 'Star $i',
            color: BoardType.hex6.availableColors[i],
            type: PlayerType.human,
          ),
      ];
      final testState = GameState(boardType: BoardType.hex6, players: players);
      testState.finishOrder = [0, 1, 2, 3];
      testState.winner = 0;
      for (var token = 0; token < tokensPerPlayer - 1; token++) {
        testState.tokenPositions[4][token] = posHome;
      }
      testState.tokenPositions[4][tokensPerPlayer - 1] =
          testState.boardType.trackLength +
          testState.boardType.homeStretchLength -
          1;
      testState.currentPlayerIndex = 4;
      testState.phase = GamePhase.moving;
      testState.lastDiceRoll = 1;
      testState.validTokenMoves = [tokensPerPlayer - 1];

      testState.moveToken(tokensPerPlayer - 1);

      expect(testState.phase, GamePhase.finished);
      expect(testState.finishOrder, [0, 1, 2, 3, 4, 5]);
      expect(testState.hasPlayerFinished(5), isFalse);
    });

    test('Star 6 Pass & Play uses isolated six-player rules', () {
      final service = GameService.createLocalGame(
        boardType: BoardType.hex6,
        humanPlayers: 6,
        aiPlayers: 0,
        humanNames: [
          'Player 1',
          'Player 2',
          'Player 3',
          'Player 4',
          'Player 5',
          'Player 6',
        ],
        humanColors: BoardType.hex6.availableColors,
      );

      expect(service.state.boardType, BoardType.hex6);
      expect(service.state.players, hasLength(6));
      expect(SixPlayerRules.finishersBeforeGameEnds(6), 5);
      expect(SixPlayerRules.appliesTo(BoardType.classic4), isFalse);
      expect(SixPlayerRules.appliesTo(BoardType.hex6), isTrue);
      service.dispose();
    });

    test('Local-game factory rejects unsupported configurations', () {
      expect(
        () => GameService.createLocalGame(
          boardType: BoardType.classic4,
          humanPlayers: 1,
          aiPlayers: 4,
        ),
        throwsArgumentError,
      );
      expect(
        () => GameService.createLocalGame(
          boardType: BoardType.classic4,
          humanPlayers: 2,
          aiPlayers: 2,
          enableTeamUp: true,
          humanColors: [PlayerColor.red, PlayerColor.red],
        ),
        throwsArgumentError,
      );
    });
  });
}
