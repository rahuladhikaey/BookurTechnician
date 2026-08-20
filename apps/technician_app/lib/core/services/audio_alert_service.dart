import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

/// Service responsible for playing loud, looping incoming job ringtones
/// and triggering continuous emergency vibration patterns (Uber / Urban Company style).
class AudioAlertService {
  static final AudioAlertService _instance = AudioAlertService._internal();
  factory AudioAlertService() => _instance;
  AudioAlertService._internal();

  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  Timer? _vibrationTimer;

  bool get isPlaying => _isPlaying;

  /// Starts the loud looping ringtone and continuous vibration
  Future<void> startJobAlertRingtone() async {
    if (_isPlaying) return;
    _isPlaying = true;

    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.setVolume(1.0); // Maximum volume for high-priority alert

      // Play audio from local asset
      await _audioPlayer!.play(
        AssetSource('sounds/incoming_job_ringtone.mp3'),
        mode: PlayerMode.mediaPlayer,
      );
      debugPrint('[AudioAlertService] Loud incoming job ringtone playing in loop.');
    } catch (e) {
      debugPrint('[AudioAlertService] Error playing ringtone audio: $e');
    }

    _startVibrationLoop();
  }

  void _startVibrationLoop() {
    _vibrationTimer?.cancel();
    _triggerVibrationPulse();

    // Repeat vibration pulse every 2 seconds
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (_isPlaying) {
        _triggerVibrationPulse();
      }
    });
  }

  Future<void> _triggerVibrationPulse() async {
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // [wait, vibrate, wait, vibrate]
        Vibration.vibrate(
          pattern: [0, 500, 200, 500, 200, 600],
          intensities: [0, 255, 0, 255, 0, 255],
        );
      }
    } catch (e) {
      debugPrint('[AudioAlertService] Vibration error: $e');
    }
  }

  /// Stops all audio playback and vibration immediately
  Future<void> stopAlert() async {
    _isPlaying = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
      }
      await Vibration.cancel();
      debugPrint('[AudioAlertService] Ringtone and vibration halted.');
    } catch (e) {
      debugPrint('[AudioAlertService] Error stopping alert: $e');
    }
  }

  void dispose() {
    stopAlert();
    _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}
