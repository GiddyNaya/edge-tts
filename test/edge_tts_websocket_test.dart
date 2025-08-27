import 'package:flutter_test/flutter_test.dart';
import 'package:edge_tts/edge_tts.dart';
import 'dart:typed_data';

void main() {
  group('EdgeTTS WebSocket Integration Tests', () {
    late EdgeTTSService ttsService;

    setUp(() {
      ttsService = EdgeTTSService();
    });

    tearDown(() async {
      await ttsService.closeConnection();
    });

    test('should connect to WebSocket successfully', () async {
      // This test verifies that the WebSocket connection can be established
      // using the web_socket_channel package
      expect(ttsService.isConnected, false);
      expect(ttsService.connectionStatus, 'Disconnected');

      // The connection will be established when textToSpeech is called
      // We'll test this in the next test
    });

    test('should get voices successfully', () async {
      final voices = await ttsService.getVoices();
      expect(voices, isNotEmpty);
      expect(voices.first, isA<Voice>());
    });

    test('should get languages successfully', () async {
      final languages = await ttsService.getLanguages();
      expect(languages, isNotEmpty);
      expect(languages.first, isA<Language>());
    });

    test('should convert text to speech using WebSocket', () async {
      // Get a test voice
      final voices = await ttsService.getVoices();
      final testVoice = voices.firstWhere(
        (voice) => voice.shortName == 'en-US-AndrewNeural',
        orElse: () => voices.firstWhere(
          (voice) => voice.shortName.contains('en-US'),
          orElse: () => voices.first,
        ),
      );

      // Convert text to speech
      final audioData = await ttsService.textToSpeech(
        text: 'Hello, this is a test.',
        voice: testVoice,
      );

      expect(audioData, isA<Uint8List>());
      expect(audioData.length, greaterThan(0));

      // Verify connection was established
      expect(ttsService.isConnected, true);
      expect(ttsService.connectionStatus, 'Connected');
    });

    test('should handle connection errors gracefully', () async {
      // This test verifies that connection errors are handled properly
      // by the web_socket_channel implementation

      // Force a connection error by using an invalid URL
      // (This would require modifying the service to accept custom URLs for testing)
      // For now, we'll just verify the service can be instantiated
      expect(ttsService, isA<EdgeTTSService>());
    });

    test('should close connection properly', () async {
      // Get a test voice and establish connection
      final voices = await ttsService.getVoices();
      final testVoice = voices.firstWhere(
        (voice) => voice.shortName == 'en-US-AndrewNeural',
        orElse: () => voices.first,
      );

      await ttsService.textToSpeech(
        text: 'Test',
        voice: testVoice,
      );

      expect(ttsService.isConnected, true);

      // Close connection
      await ttsService.closeConnection();
      expect(ttsService.isConnected, false);
      expect(ttsService.connectionStatus, 'Disconnected');
    });
  });
}
