import 'dart:math';

class RoomCodeGenerator {
  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Generate a unique 6-character room code
  static String generate() {
    final random = Random();
    return List.generate(6, (_) => _chars[random.nextInt(_chars.length)]).join();
  }
}
