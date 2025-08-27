import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Audio Manager for handling audio playback
class AudioManager {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  /// Get current playback state
  Stream<PlayerState> get playerStateStream =>
      _audioPlayer.onPlayerStateChanged;

  /// Check if audio is currently playing
  bool get isPlaying => _isPlaying;

  /// Play audio from bytes
  Future<void> playAudio(Uint8List audioData) async {
    try {
      // Save audio temporarily
      final tempFile = await _saveAudioTemporarily(audioData);

      // Play the audio
      await _audioPlayer.play(DeviceFileSource(tempFile));
      _isPlaying = true;
    } catch (e) {
      throw Exception('Error playing audio: $e');
    }
  }

  /// Play audio as stream from bytes (no file saving)
  Future<void> playAudioAsStream(Uint8List audioData) async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        // Play the audio directly from bytes
        await _audioPlayer.play(BytesSource(audioData));
      } else {
        await _audioPlayer.play(_urlSourceFromBytes(audioData));
      }
      _isPlaying = true;
    } catch (e) {
      throw Exception('Error playing audio as stream: $e');
    }
  }

  /// Play audio from file path
  Future<void> playAudioFromFile(String filePath) async {
    try {
      await _audioPlayer.play(DeviceFileSource(filePath));
      _isPlaying = true;
    } catch (e) {
      throw Exception('Error playing audio from file: $e');
    }
  }

  /// Stop current audio playback
  Future<void> stopAudio() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {
      throw Exception('Error stopping audio: $e');
    }
  }

  /// Pause current audio playback
  Future<void> pauseAudio() async {
    try {
      await _audioPlayer.pause();
      _isPlaying = false;
    } catch (e) {
      throw Exception('Error pausing audio: $e');
    }
  }

  /// Resume current audio playback
  Future<void> resumeAudio() async {
    try {
      await _audioPlayer.resume();
      _isPlaying = true;
    } catch (e) {
      throw Exception('Error resuming audio: $e');
    }
  }

  /// Save audio to temporary file
  Future<String> _saveAudioTemporarily(Uint8List audioData) async {
    try {
      // Get the temporary directory (no permission required)
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.mp3',
      );

      // Write the audio data
      await file.writeAsBytes(audioData);

      return file.path;
    } catch (e) {
      throw Exception('Error saving audio: $e');
    }
  }

  /// Save audio to device storage
  Future<String> saveAudio(Uint8List audioData, String filename) async {
    try {
      // Get the temporary directory (no permission required)
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$filename');

      // Write the audio data
      await file.writeAsBytes(audioData);

      return file.path;
    } catch (e) {
      throw Exception('Error saving audio: $e');
    }
  }

  UrlSource _urlSourceFromBytes(Uint8List bytes,
      {String mimeType = "audio/mp3"}) {
    String url = "data:audio/mp3;base64," + base64Encode(bytes);
    return UrlSource(url);
  }

  /// Dispose resources
  void dispose() {
    _audioPlayer.dispose();
  }
}
