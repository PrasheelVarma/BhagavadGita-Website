import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerController {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;

  AudioPlayer get player => _audioPlayer;

  Future<void> initialize(String audioAssetPath) async {
    try {
      await _audioPlayer.setSource(AssetSource(audioAssetPath));
    } catch (e) {
      debugPrint('Error initializing audio: $e');
      rethrow;
    }
  }

  Future<void> play() async {
    await _audioPlayer.resume();
    _isPlaying = true;
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _isPlaying = false;
  }

  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  void restart() {
    _audioPlayer.seek(Duration.zero);
  }

  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }

  void addOnDurationListener(void Function(Duration) callback) {
    _audioPlayer.onDurationChanged.listen(callback);
  }

  void addOnPositionListener(void Function(Duration) callback) {
    _audioPlayer.onPositionChanged.listen(callback);
  }

  void addOnPlayerCompleteListener(void Function() callback) {
    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _position = Duration.zero;
      callback();
    });
  }

  void updatePosition(Duration position) {
    _position = position;
  }

  void updateDuration(Duration duration) {
    _duration = duration;
  }
}
