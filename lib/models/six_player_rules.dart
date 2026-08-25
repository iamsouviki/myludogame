import '../utils/constants.dart';

/// Rules that are specific to the Star 6 board.
///
/// Kept separate from the classic four-player rules so six-player changes do
/// not silently alter the established classic game behavior.
class SixPlayerRules {
  SixPlayerRules._();

  static bool appliesTo(BoardType boardType) => boardType == BoardType.hex6;

  /// Star 6 ends when only one unfinished player remains.
  static int finishersBeforeGameEnds(int playerCount) {
    if (playerCount < 2) return 0;
    return playerCount - 1;
  }
}
