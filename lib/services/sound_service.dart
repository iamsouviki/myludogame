// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class SoundService {
  static AudioPlayer _createPlayer() {
    final player = AudioPlayer();
    // AudioPlayer initializes asynchronously; handle missing platform plugins.
    player.creatingCompleter.future.catchError((_) {});
    player.setReleaseMode(ReleaseMode.stop).catchError((_) {});
    return player;
  }

  static final AudioPlayer _stepPlayer = _createPlayer();
  static final AudioPlayer _capturePlayer = _createPlayer();
  static final AudioPlayer _dicePlayer = _createPlayer();
  static final AudioPlayer _victoryPlayer = _createPlayer();

  /// Play rhythmic step tick sound ("pig, pig, pig...")
  static void playStepSound() {
    try {
      _stepPlayer.stop().catchError((_) {});
      _stepPlayer
          .play(AssetSource('sounds/step.mp3'), volume: 0.8)
          .catchError((_) {});
      HapticFeedback.lightImpact().catchError((_) {});
    } catch (_) {}
  }

  /// Play distinct capture / cut WHOOSH sound
  static void playCaptureSound() {
    try {
      _capturePlayer.stop().catchError((_) {});
      _capturePlayer
          .play(AssetSource('sounds/capture.mp3'), volume: 1.0)
          .catchError((_) {});
      HapticFeedback.heavyImpact().catchError((_) {});
    } catch (_) {}
  }

  /// Play dice roll rattling sound
  static void playDiceRollSound() {
    try {
      _dicePlayer.stop().catchError((_) {});
      _dicePlayer
          .play(AssetSource('sounds/dice_roll.mp3'), volume: 0.9)
          .catchError((_) {});
      HapticFeedback.mediumImpact().catchError((_) {});
    } catch (_) {}
  }

  /// Play victory fanfare sound
  static void playVictorySound() {
    try {
      _victoryPlayer.stop().catchError((_) {});
      _victoryPlayer
          .play(AssetSource('sounds/victory.mp3'), volume: 1.0)
          .catchError((_) {});
      HapticFeedback.vibrate().catchError((_) {});
    } catch (_) {}
  }
}
