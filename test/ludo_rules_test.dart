import 'package:flutter_test/flutter_test.dart';
import 'package:my_ludo/models/dice.dart';
import 'package:my_ludo/models/game_state.dart';
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

      // Roll 1: 6
      testState.rollDice();
      expect(testState.consecutiveSixes, 1);
      expect(testState.getsExtraRoll, true);

      // Move token and finish turn (extra turn granted)
      testState.moveToken(0);
      expect(testState.currentPlayerIndex, 0); // Still Red's turn

      // Roll 2: 6
      testState.rollDice();
      expect(testState.consecutiveSixes, 2);
      expect(testState.getsExtraRoll, true);
      expect(testState.currentPlayerIndex, 0); // Still Red's turn
    });

    test('Triple 6 forfeits turn and passes to next player', () {
      final mockDice = MockDice([6, 6, 6]);
      final testState = GameState(
        boardType: BoardType.classic4,
        players: state.players,
        dice: mockDice,
      );

      // Roll 1: 6
      testState.rollDice();
      testState.moveToken(0);

      // Roll 2: 6
      testState.rollDice();
      testState.moveToken(0);

      // Roll 3: 6 (Triple 6!)
      testState.rollDice();

      expect(testState.consecutiveSixes, 0);
      expect(testState.getsExtraRoll, false);
      expect(testState.currentPlayerIndex, 1); // Advanced to Green (Player 2)
      expect(testState.validTokenMoves.isEmpty, true);
    });
  });
}
