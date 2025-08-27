import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() {
  group('Audio Extraction Tests', () {
    test('should extract audio data from message with header', () {
      // Create a sample message with header
      final header = utf8.encode('Path:audio\r\n');
      final audioData =
          List<int>.generate(100, (i) => i % 256); // Sample audio data
      final message = [...header, ...audioData];

      // Test the extraction function
      final extracted = _extractAudioFromMessage(message);

      expect(extracted.length, equals(100));
      expect(extracted, equals(audioData));
    });

    test('should return full message when no header found', () {
      // Create a sample message without header
      final audioData = List<int>.generate(100, (i) => i % 256);

      // Test the extraction function
      final extracted = _extractAudioFromMessage(audioData);

      expect(extracted.length, equals(100));
      expect(extracted, equals(audioData));
    });

    test('should handle empty message', () {
      final extracted = _extractAudioFromMessage([]);
      expect(extracted, isEmpty);
    });
  });
}

/// Extract audio content from WebSocket message
/// Based on the JavaScript implementation that removes the header
List<int> _extractAudioFromMessage(List<int> message) {
  // Convert to Uint8Array for easier manipulation
  final data = Uint8List.fromList(message);

  // Look for the audio header marker
  final headerMarker = utf8.encode('Path:audio\r\n');
  int headerEndIndex = -1;

  // Find the end of the header
  for (int i = 0; i <= data.length - headerMarker.length; i++) {
    bool found = true;
    for (int j = 0; j < headerMarker.length; j++) {
      if (data[i + j] != headerMarker[j]) {
        found = false;
        break;
      }
    }
    if (found) {
      headerEndIndex = i + headerMarker.length;
      break;
    }
  }

  // If header found, return the audio data after the header
  if (headerEndIndex != -1 && headerEndIndex < data.length) {
    return data.sublist(headerEndIndex);
  }

  // If no header found, assume the entire message is audio data
  return message;
}
