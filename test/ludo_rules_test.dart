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
  group('Ludo King Rules Validation', () {
    late GameState state;

    setUp(() {
      final players = [
        const Player(id: 'p1', name: 'Red', color: PlayerColor.red, type: PlayerType.human),
        const Player(id: 'p2', name: 'Green', color: PlayerColor.green, type: PlayerType.human),
        const Player(id: 'p3', name: 'Yellow', color: PlayerColor.yellow, type: PlayerType.human),
        const Player(id: 'p4', name: 'Blue', color: PlayerColor.blue, type: PlayerType.human),
      ];
      state = GameState(
        boardType: BoardType.classic4,
        players: players,
      );
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

    test('A blocked start cell prevents a token from leaving base', () {
      final mockDice = MockDice([6]);
      final testState = GameState(
        boardType: BoardType.classic4,
        players: state.players,
        dice: mockDice,
      );
      testState.tokenPositions[1][0] = testState.startPosition(0);
      testState.tokenPositions[1][1] = testState.startPosition(0);

      testState.rollDice();

      expect(testState.validTokenMoves, isEmpty);
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

    test('AI advances from a saved no-move state', () async {
      final players = [
        const Player(id: 'ai', name: 'Bot', color: PlayerColor.red, type: PlayerType.ai),
        const Player(id: 'human', name: 'Human', color: PlayerColor.green, type: PlayerType.human),
      ];
      final testState = GameState(
        boardType: BoardType.classic4,
        players: players,
      )
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
  });
}
