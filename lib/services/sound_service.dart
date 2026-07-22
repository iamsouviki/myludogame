// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class SoundService {
  static String? _stepWavUri;
  static String? _captureWavUri;
  static String? _diceWavUri;
  static String? _victoryWavUri;

  /// Play rhythmic step tick sound ("pig, pig, pig...")
  static void playStepSound() {
    _playAssetOrWav('assets/sounds/step.mp3', _getStepWavUri(), volume: 0.5);
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Play distinct capture / cut WHOOSH sound
  static void playCaptureSound() {
    _playAssetOrWav('assets/sounds/capture.mp3', _getCaptureWavUri(), volume: 0.8);
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Play dice roll rattling sound
  static void playDiceRollSound() {
    _playAssetOrWav('assets/sounds/dice_roll.mp3', _getDiceWavUri(), volume: 0.6);
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Play victory sound
  static void playVictorySound() {
    _playAssetOrWav('assets/sounds/victory.mp3', _getVictoryWavUri(), volume: 0.9);
    try {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.vibrate();
    } catch (_) {}
  }

  static void _playAssetOrWav(String assetPath, String fallbackDataUri, {double volume = 0.5}) {
    if (!kIsWeb) return;
    try {
      final audio = html.AudioElement('assets/$assetPath');
      audio.volume = volume;
      audio.play().catchError((_) {
        try {
          final fallbackAudio = html.AudioElement(fallbackDataUri);
          fallbackAudio.volume = volume;
          fallbackAudio.play();
        } catch (_) {}
      });
    } catch (_) {}
  }

  static String _getStepWavUri() {
    _stepWavUri ??= _generatePcmWavDataUri(
      durationMs: 40,
      generateSample: (t, total) {
        final env = 1.0 - (t / total);
        final freq = 550.0;
        final val = sin(2 * pi * freq * (t / 8000.0));
        return (128 + val * env * 110).clamp(0, 255).toInt();
      },
    );
    return _stepWavUri!;
  }

  static String _getCaptureWavUri() {
    _captureWavUri ??= _generatePcmWavDataUri(
      durationMs: 180,
      generateSample: (t, total) {
        final progress = t / total;
        final env = 1.0 - progress;
        final freq = 1200.0 - (progress * 900.0);
        final val = sin(2 * pi * freq * (t / 8000.0));
        return (128 + val * env * 120).clamp(0, 255).toInt();
      },
    );
    return _captureWavUri!;
  }

  static String _getDiceWavUri() {
    _diceWavUri ??= _generatePcmWavDataUri(
      durationMs: 220,
      generateSample: (t, total) {
        final progress = t / total;
        final env = sin(progress * pi);
        final noise = (Random(t).nextDouble() * 2 - 1);
        final pulse = sin(2 * pi * 40 * (t / 8000.0)) > 0 ? 1.0 : 0.2;
        return (128 + noise * env * pulse * 100).clamp(0, 255).toInt();
      },
    );
    return _diceWavUri!;
  }

  static String _getVictoryWavUri() {
    _victoryWavUri ??= _generatePcmWavDataUri(
      durationMs: 450,
      generateSample: (t, total) {
        final progress = t / total;
        final freq = progress < 0.33
            ? 523.25 // C5
            : (progress < 0.66 ? 659.25 : 783.99); // E5 -> G5
        final env = 1.0 - (progress % 0.33) * 2;
        final val = sin(2 * pi * freq * (t / 8000.0));
        return (128 + val * env.clamp(0.1, 1.0) * 110).clamp(0, 255).toInt();
      },
    );
    return _victoryWavUri!;
  }

  /// Synthesize an uncompressed 8kHz 8-bit mono WAV Data URI
  static String _generatePcmWavDataUri({
    required int durationMs,
    required int Function(int t, int total) generateSample,
  }) {
    const sampleRate = 8000;
    final numSamples = (sampleRate * durationMs ~/ 1000);
    final dataSize = numSamples;
    final fileSize = 36 + dataSize;

    final bytes = Uint8List(44 + dataSize);
    final bd = ByteData.sublistView(bytes);

    // RIFF header
    bd.setUint8(0, 0x52); // 'R'
    bd.setUint8(1, 0x49); // 'I'
    bd.setUint8(2, 0x46); // 'F'
    bd.setUint8(3, 0x46); // 'F'
    bd.setUint32(4, fileSize, Endian.little);
    bd.setUint8(8, 0x57); // 'W'
    bd.setUint8(9, 0x41); // 'A'
    bd.setUint8(10, 0x56); // 'V'
    bd.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    bd.setUint8(12, 0x66); // 'f'
    bd.setUint8(13, 0x6D); // 'm'
    bd.setUint8(14, 0x74); // 't'
    bd.setUint8(15, 0x20); // ' '
    bd.setUint32(16, 16, Endian.little); // Subchunk1Size
    bd.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    bd.setUint16(22, 1, Endian.little); // NumChannels (1 = Mono)
    bd.setUint32(24, sampleRate, Endian.little); // SampleRate
    bd.setUint32(28, sampleRate, Endian.little); // ByteRate
    bd.setUint16(32, 1, Endian.little); // BlockAlign
    bd.setUint16(34, 8, Endian.little); // BitsPerSample

    // data subchunk
    bd.setUint8(36, 0x64); // 'd'
    bd.setUint8(37, 0x61); // 'a'
    bd.setUint8(38, 0x74); // 't'
    bd.setUint8(39, 0x61); // 'a'
    bd.setUint32(40, dataSize, Endian.little);

    // PCM samples
    for (var i = 0; i < numSamples; i++) {
      bytes[44 + i] = generateSample(i, numSamples);
    }

    final b64 = base64Encode(bytes);
    return 'data:audio/wav;base64,$b64';
  }
}
