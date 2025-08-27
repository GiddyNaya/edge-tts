# EdgeTTS Demo

A comprehensive Flutter demo application showcasing the [edge_tts](https://github.com/yourusername/edge_tts) library for Microsoft EdgeTTS (Text-to-Speech) service integration.

## Features

This demo showcases all the capabilities of the edge_tts library:

- 🎤 **Text-to-Speech Conversion**: Convert text to high-quality speech using Microsoft's EdgeTTS service
- 🌍 **Dynamic Voice Loading**: Load available voices from the server with real-time filtering
- 🗺️ **Country-based Filtering**: Filter voices by country with alphabetical sorting
- ⚡ **Real-time Streaming**: Stream audio as it's being generated with "Play as Stream" functionality
- 🎛️ **Speech Controls**: Adjust rate, volume, and pitch of speech with intuitive sliders
- 🔧 **Decoupled Architecture**: Audio playback separated from TTS service using callback interfaces
- 📱 **Cross-platform**: Works on iOS, Android, Web, Windows, macOS, and Linux
- 🎨 **Modern UI**: Beautiful Material Design 3 interface with loading states and error handling

## Screenshots

*Add screenshots here when available*

## Getting Started

### Prerequisites

- Flutter SDK (>=3.1.0)
- Dart SDK (>=3.1.0)

### Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/edge_tts_demo.git
cd edge_tts_demo
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Usage

### Basic Text-to-Speech

1. Enter text in the "Text to Convert" field
2. Select a voice from the dropdown (filtered by country)
3. Adjust speech controls (rate, volume, pitch) if desired
4. Click "Convert & Play" to generate and play audio

### Real-time Streaming

1. Enter text and select a voice
2. Click "Play as Stream" to stream audio as it's generated
3. The audio will start playing once the stream is complete

### Voice Management

- **Refresh Voices**: Click the refresh icon to reload available voices
- **Country Filtering**: Use the country dropdown to filter voices by language/country
- **Voice Selection**: Choose from hundreds of available voices with different accents and genders

### Audio Controls

- **Play/Pause**: Control audio playback
- **Stop**: Stop current audio playback
- **Resume**: Resume paused audio

## Architecture

This demo demonstrates the decoupled architecture of the edge_tts library:

- **EdgeTTSService**: Handles all TTS operations and WebSocket communication
- **AudioManager**: Manages audio playback independently
- **Callback Interfaces**: `AudioPlaybackCallback` and `AudioStreamCallback` for event handling
- **Separation of Concerns**: TTS logic is completely separate from audio playback

## Dependencies

This demo uses the [edge_tts](https://github.com/yourusername/edge_tts) library which includes:

- `http`: For voice fetching
- `uuid`: For request ID generation
- `path_provider`: For file operations
- `audioplayers`: For audio playback
- `dart:io`: For WebSocket communication

## Contributing

This is a demo project for the edge_tts library. For contributions to the library itself, please visit the [edge_tts repository](https://github.com/yourusername/edge_tts).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Microsoft EdgeTTS service for providing high-quality text-to-speech
- The Flutter team for the excellent framework
- The edge_tts library contributors
