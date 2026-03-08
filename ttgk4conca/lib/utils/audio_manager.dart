// lib/utils/audio_manager.dart
import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  bool _isMuted = false;
  String? _currentBgm; // Lưu tên bài nhạc đang phát để tránh load lại nếu trùng

  bool get isMuted => _isMuted;

  // HÀM CHUNG ĐỂ PHÁT NHẠC NỀN
  Future<void> _playMusic(String fileName) async {
    if (_isMuted) return;

    // Nếu bài này đang phát rồi thì thôi, không reset lại từ đầu
    if (_currentBgm == fileName && _bgmPlayer.state == PlayerState.playing) return;

    try {
      await _bgmPlayer.stop(); // Dừng bài cũ
      _currentBgm = fileName;

      await _bgmPlayer.setVolume(0.3); // Âm lượng vừa phải
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop); // Lặp lại vô tận
      await _bgmPlayer.play(AssetSource('audio/$fileName'));
    } catch (e) {
      print("Lỗi phát nhạc: $e");
    }
  }

  // 1. Phát nhạc Sảnh (Dùng cho Main Menu, Shop, Profile...)
  Future<void> playMainMenuMusic() async {
    await _playMusic('bit-beats.mp3');
  }

  // 2. Phát nhạc Trong Game (PvP, PvE, Group...)
  Future<void> playGameMusic() async {
    await _playMusic('sailor.mp3');
  }

  // 3. Phát hiệu ứng (SFX)
  Future<void> playSFX(String fileName) async {
    if (_isMuted) return;
    // Tạo player mới tạm thời nếu cần phát nhiều tiếng chồng nhau (tiếng nổ, tiếng click)
    // Hoặc dùng 1 player cố định như dưới đây
    await _sfxPlayer.stop();
    await _sfxPlayer.setVolume(1.0);
    await _sfxPlayer.play(AssetSource('audio/$fileName'));
  }

  // 4. Bật/Tắt âm thanh (Mute)
  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _bgmPlayer.stop();
    } else {
      // Nếu mở lại, phát lại bài gần nhất (hoặc mặc định là nhạc sảnh)
      if (_currentBgm != null) {
        _bgmPlayer.play(AssetSource('audio/$_currentBgm'));
      } else {
        playMainMenuMusic();
      }
    }
  }
}