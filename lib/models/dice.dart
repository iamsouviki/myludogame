import 'dart:math';

import '../utils/constants.dart';

// ponytail: it's a dice. it rolls.
class Dice {
  final Random _random;

  Dice([int? seed]) : _random = Random(seed);

  int roll() => _random.nextInt(diceMax - diceMin + 1) + diceMin;
}
