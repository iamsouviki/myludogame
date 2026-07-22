import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class SoundService {
  static final AudioPlayer _stepPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  static final AudioPlayer _capturePlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  static final AudioPlayer _dicePlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  static final AudioPlayer _victoryPlayer = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  /// Play rhythmic step tick sound ("pig, pig, pig...")
  static void playStepSound() {
    try {
      _stepPlayer.stop();
      _stepPlayer.play(AssetSource('sounds/step.mp3'), volume: 0.8);
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Play distinct capture / cut WHOOSH sound
  static void playCaptureSound() {
    try {
      _capturePlayer.stop();
      _capturePlayer.play(AssetSource('sounds/capture.mp3'), volume: 1.0);
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Play dice roll rattling sound
  static void playDiceRollSound() {
    try {
      _dicePlayer.stop();
      _dicePlayer.play(AssetSource('sounds/dice_roll.mp3'), volume: 0.9);
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Play victory fanfare sound
  static void playVictorySound() {
    try {
      _victoryPlayer.stop();
      _victoryPlayer.play(AssetSource('sounds/victory.mp3'), volume: 1.0);
      HapticFeedback.vibrate();
    } catch (_) {}
  }
}
