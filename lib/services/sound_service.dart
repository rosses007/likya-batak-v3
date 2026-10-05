import 'package:audioplayers/audioplayers.dart';

class SoundService {
  static final AudioPlayer _cardPlayer = AudioPlayer();
  static final AudioPlayer _dealPlayer = AudioPlayer();
  static final AudioPlayer _chipsPlayer = AudioPlayer();
  
  static bool soundEnabled = true;
  static double volume = 1.0;

  static Future<void> playCardDeal() async {
    if (!soundEnabled) return;
    try {
      await _dealPlayer.setVolume(volume);
      await _dealPlayer.stop();
      await _dealPlayer.play(AssetSource('sounds/card_deal.wav'));
    } catch (_) {}
  }

  static Future<void> playCardThrow() async {
    if (!soundEnabled) return;
    try {
      await _cardPlayer.setVolume(volume);
      await _cardPlayer.stop();
      await _cardPlayer.play(AssetSource('sounds/card_throw.wav'));
    } catch (_) {
      playCardSlide();
    }
  }

  static Future<void> playCardSlide() async {
    if (!soundEnabled) return;
    try {
      await _cardPlayer.setVolume(volume);
      await _cardPlayer.stop();
      await _cardPlayer.play(AssetSource('sounds/card_slide.mp3'));
    } catch (_) {}
  }

  static Future<void> playChipsCollect() async {
    if (!soundEnabled) return;
    try {
      await _chipsPlayer.setVolume(volume);
      await _chipsPlayer.stop();
      await _chipsPlayer.play(AssetSource('sounds/chips_collect.mp3'));
    } catch (_) {}
  }
}
