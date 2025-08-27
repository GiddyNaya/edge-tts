import 'package:flutter_test/flutter_test.dart';
import 'package:edge_tts/edge_tts.dart';

void main() {
  group('EdgeTTSService Tests', () {
    test('should create EdgeTTSService instance', () {
      final ttsService = EdgeTTSService();
      expect(ttsService, isNotNull);
    });
  });
}
