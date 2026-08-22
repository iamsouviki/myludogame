import 'package:flutter_test/flutter_test.dart';
import 'package:my_ludo/models/dice.dart';
import 'package:my_ludo/models/game_state.dart';
import 'package:my_ludo/services/game_service.dart';
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
      testState.rollDice();
      testState.moveToken(0);
      testState.rollDice();

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
      expect(List.generate(4, state.startPosition), [0, 12, 25, 38]);
      expect(List.generate(4, state.homeEntryPosition), [51, 11, 24, 37]);
      expect(state.safeSpots, containsAll([0, 12, 25, 38]));
    });

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
      expect(testState.tokenPositions[1][0], 13);
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
      testState.tokenPositions[0][0] = 32;
      testState.tokenPositions[1][0] = 33;

      testState.rollDice();

      expect(testState.safeSpots, containsAll([25, 33, 38, 46]));
      expect(testState.validTokenMoves, contains(0));
      expect(testState.moveToken(0), isFalse);
      expect(testState.tokenPositions[1][0], 33);
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
        await Future<void>.delayed(const Duration(milliseconds: 650));

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
  });
}
