# Edge TTS

A Flutter package for Microsoft EdgeTTS (Text-to-Speech) service integration with persistent WebSocket connections and comprehensive language support.

## Features

- **Text-to-Speech Conversion**: Convert text to high-quality speech using Microsoft's EdgeTTS service
- **Multiple Languages**: Support for 100+ languages and regions including English, Spanish, French, German, Chinese, Japanese, Korean, and many more
- **Hundreds of Voices**: Access to hundreds of neural voices across different languages and accents
- **Real-time Streaming**: Stream audio as it's being generated with low latency
- **Persistent WebSocket Connections**: Efficient WebSocket connections using `web_socket_channel` package that are reused across requests
- **Speech Controls**: Adjust rate, volume, and pitch of speech with fine-grained control
- **Flexible Architecture**: Decoupled audio playback with callback interfaces
- **Cross-platform**: Works on iOS, Android, Web, Windows, macOS, and Linux
- **High Performance**: Optimized for fast response times and minimal resource usage
- **Modern WebSocket**: Uses the `web_socket_channel` package for robust cross-platform WebSocket support

## Getting started

### Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  edge_tts: ^1.6.0
```

### Live Demo

**Try the live demo**: [https://giddynaya.github.io/edge_tts/](https://giddynaya.github.io/edge_tts/)

The demo showcases all features including voice selection, speech customization, and real-time audio playback.

### WebSocket Implementation

This package uses the `web_socket_channel` package for robust cross-platform WebSocket support. The WebSocket connection is automatically managed and reused across multiple text-to-speech requests for optimal performance.

Key benefits of using `web_socket_channel`:
- **Cross-platform compatibility**: Works consistently across all Flutter platforms
- **Automatic reconnection**: Handles connection drops gracefully
- **Stream-based API**: Clean and efficient message handling
- **Proper error handling**: Comprehensive error management with status codes

### Basic Usage

```dart
import 'package:edge_tts/edge_tts.dart';

// Create TTS service instance
final ttsService = EdgeTTSService();

// Get available languages
final languages = await ttsService.getLanguages();

// Get available voices
final voices = await ttsService.getVoices();

// Get voices for a specific language
final englishVoices = await ttsService.getVoicesForLanguage('en');

// Convert text to speech
final audioData = await ttsService.textToSpeech(
  text: "Hello, world!",
  voice: voices.first, // Voice object
  rate: 0,    // -50 to 50 (speech rate)
  volume: 0,  // -50 to 50 (volume)
  pitch: 0,   // -50 to 50 (pitch)
  streamToPlayer: false, // Whether to stream to player
);

// Convert text to speech with streaming
final streamedAudioData = await ttsService.textToSpeechStream(
  text: "Hello, world!",
  voice: voices.first, // Voice object
  rate: 0,    // -50 to 50 (speech rate)
  volume: 0,  // -50 to 50 (volume)
  pitch: 0,   // -50 to 50 (pitch)
);
```

### Advanced Usage with Audio Manager

```dart
import 'package:edge_tts/edge_tts.dart';
import 'dart:typed_data';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  
  final EdgeTTSService _ttsService = EdgeTTSService();
  final AudioManager _audioManager = AudioManager();

  @override
  void initState() {
    super.initState();
    // Set up audio player state listener
    _audioManager.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
  }

  Future<void> convertToSpeech() async {
    final audioData = await _ttsService.textToSpeech(
      text: "Hello, world!",
      voice: voices.first, // Voice object
      rate: 0,    // -50 to 50 (speech rate)
      volume: 0,  // -50 to 50 (volume)
      pitch: 0,   // -50 to 50 (pitch)
      streamToPlayer: false, // Whether to stream to player
    );
    
    await _audioManager.playAudio(audioData);
  }

  Future<void> convertToSpeechStream() async {
    final audioData = await _ttsService.textToSpeechStream(
      text: "Hello, world!",
      voice: voices.first, // Voice object
      rate: 0,    // -50 to 50 (speech rate)
      volume: 0,  // -50 to 50 (volume)
      pitch: 0,   // -50 to 50 (pitch)
    );
    
    await _audioManager.playAudioAsStream(audioData);
  }

  @override
  void dispose() {
    _audioManager.dispose();
    super.dispose();
  }
}
```

### Language and Voice Management

```dart
// Get all available languages with regions
final languages = await ttsService.getLanguages();
// Returns: [Language(code: 'en', name: 'English', region: 'US'), ...]

// Get voices for a specific language
final englishVoices = await ttsService.getVoicesForLanguage('en');
final spanishVoices = await ttsService.getVoicesForLanguage('es');

// Get all available voices
final allVoices = await ttsService.getVoices();

// Filter voices by locale
final usVoices = allVoices.where((voice) => voice.locale == 'en-US').toList();
```

## API Reference

### EdgeTTSService

The main service class for interacting with Microsoft's EdgeTTS service.

#### Methods

- `getVoices()`: Get all available voices
- `getLanguages()`: Get all available languages with regions
- `getVoicesForLanguage(String languageCode)`: Get voices filtered by language code
- `textToSpeech({required String text, required Voice voice, int rate = 0, int volume = 0, int pitch = 0, bool streamToPlayer = false})`: Convert text to speech
- `textToSpeechStream({required String text, required Voice voice, int rate = 0, int volume = 0, int pitch = 0})`: Convert text to speech with streaming
- `closeConnection()`: Close the WebSocket connection
- `isConnected`: Check if WebSocket is connected
- `connectionStatus`: Get current connection status

#### Properties

- `availableVoices`: Static map of predefined voices with friendly names
- `isConnected`: Boolean indicating if WebSocket connection is active
- `connectionStatus`: String describing current connection state

### Language Class

Represents a language with its code, name, and region.

```dart
class Language {
  final String code;      // Language code (e.g., 'en', 'es')
  final String name;      // Language name (e.g., 'English', 'Spanish')
  final String region;    // Region code (e.g., 'US', 'MX')
  final String displayName; // Formatted display name (e.g., 'English (US)')
}
```

### Voice Class

Represents a voice with its properties.

```dart
class Voice {
  final String name;           // Full voice name
  final String shortName;      // Short voice identifier
  final String gender;         // Voice gender
  final String locale;         // Voice locale
  final String suggestedCodec; // Suggested audio codec
  final String friendlyName;   // User-friendly name
  final String status;         // Voice status
  final Map<String, dynamic> voiceTag; // Additional voice metadata
}
```

### AudioManager

Manages audio playback functionality.

#### Methods

- `playAudio(Uint8List audioData)`: Play audio from bytes
- `playAudioAsStream(Uint8List audioData)`: Play audio as stream
- `stopAudio()`: Stop current playback
- `pauseAudio()`: Pause current playback
- `resumeAudio()`: Resume current playback
- `dispose()`: Clean up resources

## Supported Languages

The library supports 100+ languages and regions, including:

- **English**: US, UK, Australia, Canada, India, Ireland, New Zealand, Philippines, Singapore, South Africa
- **Spanish**: Spain, Mexico, Argentina, Chile, Colombia, Peru, Venezuela, and more
- **French**: France, Canada, Belgium, Switzerland
- **German**: Germany, Austria, Switzerland
- **Chinese**: Simplified, Traditional, Cantonese
- **Japanese**: Japan
- **Korean**: Korea
- **Portuguese**: Portugal, Brazil
- **Italian**: Italy
- **Russian**: Russia
- **Arabic**: Multiple regional variants
- **Hindi**: India
- **Turkish**: Turkey
- **Dutch**: Netherlands, Belgium
- **Polish**: Poland
- **Swedish**: Sweden
- **Vietnamese**: Vietnam
- **Thai**: Thailand
- **Indonesian**: Indonesia
- **Malay**: Malaysia
- And many more...

## Example Project

Check out the [example project](example/) for a complete implementation showcasing:

- Language selection dropdown
- Voice filtering by language
- Real-time text-to-speech conversion
- Audio playback controls
- Streaming audio support
- Error handling and connection management

## Performance Features

- **Persistent WebSocket Connections**: Connections are reused across requests for better performance
- **Connection Health Monitoring**: Automatic connection validation and recovery
- **Keep-Alive Mechanism**: Maintains connection health with periodic checks
- **Error Recovery**: Automatic reconnection on connection failures
- **Resource Management**: Proper cleanup of connections and resources

## Error Handling

The library provides comprehensive error handling:

- Connection timeout and retry logic
- WebSocket connection health monitoring
- Automatic reconnection on failures
- Detailed error messages for debugging
- Graceful degradation when services are unavailable

## Deployment

### GitHub Pages

This repository includes automatic deployment to GitHub Pages. The Flutter web example is automatically built and deployed when you push to the main branch.

**Live Demo**: [https://giddynaya.github.io/edge_tts/](https://giddynaya.github.io/edge_tts/)

For detailed deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

### Local Web Development

To run the example locally:

```bash
cd example
flutter run -d chrome
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
