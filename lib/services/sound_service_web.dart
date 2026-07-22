// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

void playWebAudio(String assetPath, String fallbackDataUri, double volume) {
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
