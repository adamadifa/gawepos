import 'package:audioplayers/audioplayers.dart';

class ScanSoundHelper {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playBeep() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/beep.wav'));
    } catch (e) {
      // Ignore audio errors silently
    }
  }
}
