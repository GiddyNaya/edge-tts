import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// Voice interface matching the official EdgeTTS implementation
class Voice {
  final String name;
  final String shortName;
  final String gender;
  final String locale;
  final String suggestedCodec;
  final String friendlyName;
  final String status;
  final Map<String, dynamic> voiceTag;

  Voice({
    required this.name,
    required this.shortName,
    required this.gender,
    required this.locale,
    required this.suggestedCodec,
    required this.friendlyName,
    required this.status,
    required this.voiceTag,
  });

  factory Voice.fromJson(Map<String, dynamic> json) {
    return Voice(
      name: json['Name'] ?? '',
      shortName: json['ShortName'] ?? '',
      gender: json['Gender'] ?? '',
      locale: json['Locale'] ?? '',
      suggestedCodec: json['SuggestedCodec'] ?? '',
      friendlyName: json['FriendlyName'] ?? '',
      status: json['Status'] ?? '',
      voiceTag: json['VoiceTag'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Name': name,
      'ShortName': shortName,
      'Gender': gender,
      'Locale': locale,
      'SuggestedCodec': suggestedCodec,
      'FriendlyName': friendlyName,
      'Status': status,
      'VoiceTag': voiceTag,
    };
  }
}

/// Language interface for representing available languages
class Language {
  final String code;
  final String locale;
  final String name;
  final String region;

  Language({
    required this.code,
    required this.locale,
    required this.name,
    required this.region,
  });

  String get displayName {
    if (region.isEmpty || region == name) {
      return name;
    }
    return '$name ($region)';
  }

  @override
  String toString() => displayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Language &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// EdgeTTS Service for Flutter
/// This class provides functionality to interact with Microsoft's EdgeTTS service
class EdgeTTSService {
  static const String _baseUrl = 'https://speech.platform.bing.com';
  // static const String _synthesizeUrl = '$_baseUrl/consumer/speech/synthesize';
  static const String _voicesUrl =
      '$_baseUrl/consumer/speech/synthesize/readaloud/voices/list?trustedclienttoken=6A5AA1D4EAFF4E9FB37E23D68491D6F4';

  // WebSocket configuration for synthesis
  static const String _wsBaseUrl = 'wss://speech.platform.bing.com';
  static const String _wsPath = '/consumer/speech/synthesize/readaloud/edge/v1';
  static const String _trustedClientToken = '6A5AA1D4EAFF4E9FB37E23D68491D6F4';
  static const String _defaultOutputFormat = 'audio-24khz-96kbitrate-mono-mp3';

  // Prepare headers
  static const Map<String, String> headers = {
    'Content-Type': 'application/ssml+xml',
    'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
    'Authority': 'speech.platform.bing.com',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'Sec-CH-UA':
        '" Not;A Brand";v="99", "Microsoft Edge";v="130", "Chromium";v="130"',
    'Sec-CH-UA-Mobile': '?0',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Dest': 'empty',
  };

  // WebSocket connection management
  WebSocketChannel? _webSocketChannel;
  bool _isConnecting = false;
  bool _isConnected = false;
  Completer<void>? _connectionCompleter;
  Timer? _keepAliveTimer;
  static const Duration _keepAliveInterval = Duration(seconds: 30);
  static const Duration _connectionTimeout = Duration(seconds: 15);
  String? _connectionId;

  // Message handling
  StreamController<dynamic>? _messageController;
  StreamSubscription<dynamic>? _messageSubscription;

  /// Initialize WebSocket connection
  Future<void> _initializeWebSocket() async {
    if (_isConnected && _webSocketChannel != null) {
      return; // Already connected
    }

    if (_isConnecting) {
      // Wait for existing connection attempt to complete
      await _connectionCompleter!.future;
      return;
    }

    _isConnecting = true;
    _connectionCompleter = Completer<void>(); // Reset completer

    try {
      // Generate connection ID for this session
      _connectionId = _generateConnectionId();

      // Create WebSocket URL with additional parameters
      final wsUrl =
          '$_wsBaseUrl$_wsPath?TrustedClientToken=$_trustedClientToken&Sec-MS-GEC=24879F5E6E617B819EFB7214C2BF3A6F8316E91A9D0EB5888133D0A77DE430A2&Sec-MS-GEC-Version=1-130.0.2849.68&ConnectionId=$_connectionId';

      // Create WebSocket connection using WebSocketChannel
      _webSocketChannel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: null,
      );

      // Wait for the channel to be ready with a longer timeout
      await _webSocketChannel!.ready.timeout(_connectionTimeout);

      // Set up message handling BEFORE marking as connected
      _messageController = StreamController<dynamic>.broadcast();
      _messageSubscription = _webSocketChannel!.stream.listen(
        (message) {
          _messageController!.add(message);
        },
        onError: (error) {
          _handleConnectionError(error);
        },
        onDone: () {
          _handleConnectionClosed();
        },
      );

      // Send initial configuration and wait for it to be processed
      await _sendConfigMessage();

      // Add a small delay to ensure the server has processed the config
      await Future.delayed(const Duration(milliseconds: 200));

      // Only mark as connected after configuration is sent and processed
      _isConnected = true;
      _isConnecting = false;

      // Start keep-alive timer
      _startKeepAliveTimer();

      // Complete the connection completer successfully
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete();
      }
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      _webSocketChannel = null;
      _connectionId = null;
      // Complete the connection completer with error if not already completed
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(e);
      }
      _connectionCompleter = null;
      throw Exception('Failed to initialize WebSocket connection: $e');
    }
  }

  /// Handle WebSocket connection errors
  void _handleConnectionError(dynamic error) {
    _isConnected = false;
    _isConnecting = false;
    _webSocketChannel = null;
    _connectionId = null;
    _stopKeepAliveTimer();
    _disposeMessageHandling();
    // Complete the connection completer with error if it exists and not already completed
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.completeError(error);
    }
    _connectionCompleter = null;
    // Log error or notify callbacks as needed
  }

  /// Handle WebSocket connection closure
  void _handleConnectionClosed() {
    _isConnected = false;
    _isConnecting = false;
    _webSocketChannel = null;
    _connectionId = null;
    _stopKeepAliveTimer();
    _disposeMessageHandling();
    // Complete the connection completer if it exists and not already completed
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete();
    }
    _connectionCompleter = null;
    // Log closure or notify callbacks as needed
  }

  /// Dispose message handling resources
  void _disposeMessageHandling() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _messageController?.close();
    _messageController = null;
  }

  /// Start keep-alive timer to maintain connection
  void _startKeepAliveTimer() {
    _stopKeepAliveTimer(); // Stop existing timer if any
    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (timer) {
      if (_isConnected && _webSocketChannel != null) {
        // Send ping or keep-alive message if needed
        // For now, just check if connection is still alive
      } else {
        timer.cancel();
      }
    });
  }

  /// Stop keep-alive timer
  void _stopKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  /// Send configuration message to WebSocket
  Future<void> _sendConfigMessage() async {
    if (_webSocketChannel == null) {
      throw Exception('WebSocket not available');
    }

    final configMessage = _createConfigMessage();
    _webSocketChannel!.sink.add(configMessage);

    // Wait for configuration to be processed
    await Future.delayed(const Duration(milliseconds: 150));
  }

  /// Close WebSocket connection
  Future<void> closeConnection() async {
    _stopKeepAliveTimer();
    _disposeMessageHandling();
    if (_webSocketChannel != null) {
      await _webSocketChannel!.sink.close(status.goingAway);
      _webSocketChannel = null;
    }
    _isConnected = false;
    _isConnecting = false;
    _connectionId = null;
    try {
      // Complete the connection completer if it exists and not already completed
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete();
      }
    } catch (e) {
      print('Error completing connection completer: $e');
    }
    _connectionCompleter = null;
  }

  /// Check if WebSocket is connected
  bool get isConnected => _isConnected && _webSocketChannel != null;

  /// Get connection status
  String get connectionStatus {
    if (_isConnecting) return 'Connecting...';
    if (_isConnected && _webSocketChannel != null) return 'Connected';
    return 'Disconnected';
  }

  /// Get current connection ID
  String? get connectionId => _connectionId;

  /// Pre-initialize the WebSocket connection for immediate use
  /// Call this method when the app starts to avoid delays on first TTS request
  Future<void> preInitializeConnection() async {
    if (!_isConnected && !_isConnecting) {
      try {
        await _initializeWebSocket();
      } catch (e) {
        // Log error but don't throw - connection will be retried on first TTS request
        print('Pre-initialization failed: $e');
      }
    }
  }

  /// Check and reset connection if needed
  Future<void> _ensureConnection() async {
    // If currently connecting, wait for it to complete
    if (_isConnecting && _connectionCompleter != null) {
      try {
        await _connectionCompleter!.future.timeout(Duration(seconds: 15));
        return;
      } catch (e) {
        // If connection attempt failed, reset and try again
        await closeConnection();
      }
    }

    if (!_isConnected ||
        _webSocketChannel == null ||
        _messageController == null) {
      // Connection is not in a good state, reset and reinitialize
      await closeConnection();
      await _initializeWebSocket();
    }
  }

  /// Available voices for text-to-speech
  static const Map<String, String> availableVoices = {
    'en-US-AndrewNeural': 'Andrew (US English, Male)',
    'en-US-JennyNeural': 'Jenny (US English, Female)',
    'en-US-GuyNeural': 'Guy (US English, Male)',
    'en-GB-SoniaNeural': 'Sonia (British English, Female)',
    'en-GB-RyanNeural': 'Ryan (British English, Male)',
    'es-ES-ElviraNeural': 'Elvira (Spanish, Female)',
    'es-ES-AlvaroNeural': 'Alvaro (Spanish, Male)',
    'fr-FR-DeniseNeural': 'Denise (French, Female)',
    'fr-FR-HenriNeural': 'Henri (French, Male)',
    'de-DE-KatjaNeural': 'Katja (German, Female)',
    'de-DE-ConradNeural': 'Conrad (German, Male)',
    'it-IT-IsabellaNeural': 'Isabella (Italian, Female)',
    'it-IT-DiegoNeural': 'Diego (Italian, Male)',
    'pt-BR-FranciscaNeural': 'Francisca (Portuguese, Female)',
    'pt-BR-AntonioNeural': 'Antonio (Portuguese, Male)',
    'ja-JP-NanamiNeural': 'Nanami (Japanese, Female)',
    'ja-JP-KeitaNeural': 'Keita (Japanese, Male)',
    'ko-KR-SunHiNeural': 'SunHi (Korean, Female)',
    'ko-KR-InJoonNeural': 'InJoon (Korean, Male)',
    'zh-CN-XiaoxiaoNeural': 'Xiaoxiao (Chinese, Female)',
    'zh-CN-YunxiNeural': 'Yunxi (Chinese, Male)',
  };

  /// Get available voices from the server
  /// Matches the official edge-tts implementation
  Future<List<Voice>> getVoices() async {
    try {
      // Use appropriate headers for voice fetching (GET request)
      final voiceHeaders = {
        'Accept': 'application/json',
        'Authority': 'speech.platform.bing.com',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0',
        'Accept-Language': 'en-US,en;q=0.9',
        'Accept-Encoding': 'gzip, deflate, br',
        'Sec-CH-UA':
            '" Not;A Brand";v="99", "Microsoft Edge";v="130", "Chromium";v="130"',
        'Sec-CH-UA-Mobile': '?0',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Dest': 'empty',
      };

      final response = await http.get(
        Uri.parse(_voicesUrl),
        headers: voiceHeaders,
      );

      if (response.statusCode == 200) {
        final List<dynamic> voicesJson = json.decode(response.body);

        // Convert to Voice objects
        final List<Voice> voices = voicesJson
            .where(
              (voice) =>
                  voice['Name'] != null && voice['Name'].toString().isNotEmpty,
            )
            .map((voice) => Voice.fromJson(voice))
            .toList();

        // Sort voices by locale and name for better organization
        voices.sort((a, b) {
          if (a.locale != b.locale) {
            return a.locale.compareTo(b.locale);
          }
          return a.name.compareTo(b.name);
        });

        return voices;
      } else {
        throw Exception(
          'Failed to load voices: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error loading voices: $e');
    }
  }

  /// Get available languages from the server
  /// Returns a list of unique languages with their regions
  Future<List<Language>> getLanguages() async {
    try {
      final voices = await getVoices();
      final Map<String, Language> languagesMap = {};

      for (final voice in voices) {
        final locale = voice.locale;
        if (locale.isNotEmpty) {
          // Parse locale (e.g., "en-US" -> code: "en", region: "US")
          final parts = locale.split('-');
          final code = parts[0].toLowerCase();
          final region = parts.length > 1 ? parts[1] : '';

          // Get language name from locale code
          final languageName = _getLanguageNameFromCode(code);

          final languageKey = '$code-$region';
          if (!languagesMap.containsKey(languageKey)) {
            languagesMap[languageKey] = Language(
              locale: locale,
              code: code,
              name: languageName,
              region: region,
            );
          }
        }
      }

      final languages = languagesMap.values.toList();
      // languages.sort((a, b) {
      //   if (a.name != b.name) {
      //     return a.name.compareTo(b.name);
      //   }
      //   return a.region.compareTo(b.region);
      // });

      return languages;
    } catch (e) {
      throw Exception('Error loading languages: $e');
    }
  }

  /// Get voices for a specific language
  Future<List<Voice>> getVoicesForLanguage(String languageCode) async {
    try {
      final voices = await getVoices();
      return voices
          .where((voice) =>
              voice.locale.toLowerCase().startsWith(languageCode.toLowerCase()))
          .toList();
    } catch (e) {
      throw Exception('Error loading voices for language $languageCode: $e');
    }
  }

  /// Helper method to get language name from ISO code
  String _getLanguageNameFromCode(String code) {
    const languageNames = {
      'en': 'English',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'fr': 'French',
      'de': 'German',
      'es': 'Spanish',
      'it': 'Italian',
      'ru': 'Russian',
      'pt': 'Portuguese',
      'nl': 'Dutch',
      'pl': 'Polish',
      'hi': 'Hindi',
      'ar': 'Arabic',
      'tr': 'Turkish',
      'sv': 'Swedish',
      'vi': 'Vietnamese',
      'th': 'Thai',
      'id': 'Indonesian',
      'ms': 'Malay',
      'fil': 'Filipino',
      'uk': 'Ukrainian',
      'ro': 'Romanian',
      'cs': 'Czech',
      'hu': 'Hungarian',
      'el': 'Greek',
      'af': 'Afrikaans',
      'am': 'Amharic',
      'sw': 'Swahili',
      'zu': 'Zulu',
      'so': 'Somali',
      'bg': 'Bulgarian',
      'hr': 'Croatian',
      'da': 'Danish',
      'et': 'Estonian',
      'fi': 'Finnish',
      'ga': 'Irish',
      'is': 'Icelandic',
      'lv': 'Latvian',
      'lt': 'Lithuanian',
      'mk': 'Macedonian',
      'mt': 'Maltese',
      'sk': 'Slovak',
      'sl': 'Slovenian',
      'sr': 'Serbian',
      'cy': 'Welsh',
      'az': 'Azerbaijani',
      'bn': 'Bengali',
      'my': 'Burmese',
      'ka': 'Georgian',
      'gu': 'Gujarati',
      'he': 'Hebrew',
      'jv': 'Javanese',
      'kk': 'Kazakh',
      'km': 'Khmer',
      'kn': 'Kannada',
      'lo': 'Lao',
      'ml': 'Malayalam',
      'mr': 'Marathi',
      'mn': 'Mongolian',
      'ne': 'Nepali',
      'fa': 'Persian',
      'ps': 'Pashto',
      'si': 'Sinhala',
      'su': 'Sundanese',
      'ta': 'Tamil',
      'te': 'Telugu',
      'ur': 'Urdu',
      'uz': 'Uzbek',
      'bs': 'Bosnian',
      'ca': 'Catalan',
      'gl': 'Galician',
      'sq': 'Albanian',
      'nb': 'Norwegian Bokmål',
    };

    return languageNames[code.toLowerCase()] ?? code.toUpperCase();
  }

  /// Get available voices filtered by locale
  Future<List<Voice>> getVoicesByLocale(String locale) async {
    try {
      final allVoices = await getVoices();
      return allVoices.where((voice) {
        return voice.locale.toLowerCase().startsWith(locale.toLowerCase());
      }).toList();
    } catch (e) {
      throw Exception('Error filtering voices by locale: $e');
    }
  }

  /// Get available locales
  Future<List<String>> getAvailableLocales() async {
    try {
      final voices = await getVoices();
      final locales = voices.map((voice) => voice.locale).toSet();
      return locales.where((locale) => locale.isNotEmpty).toList()..sort();
    } catch (e) {
      throw Exception('Error getting available locales: $e');
    }
  }

  /// Convert text to speech using EdgeTTS WebSocket
  /// [text] - The text to convert to speech
  /// [voice] - The voice to use (e.g., 'en-US-AndrewNeural')
  /// [rate] - Speech rate (default: 0, range: -100 to 100)
  /// [volume] - Volume (default: 0, range: -100 to 100)
  /// [pitch] - Pitch (default: 0, range: -100 to 100)
  /// [streamToPlayer] - If true, streams audio directly to player as it arrives
  Future<Uint8List> textToSpeech({
    required String text,
    required Voice voice,
    int rate = 0,
    int volume = 0,
    int pitch = 0,
    bool streamToPlayer = false,
  }) async {
    try {
      // Ensure WebSocket is initialized and in good state
      await _ensureConnection();

      // Final verification that connection is ready
      if (!_isConnected ||
          _webSocketChannel == null ||
          _messageController == null) {
        throw Exception('Failed to establish WebSocket connection');
      }

      // Create request ID
      final requestId = Uuid().v4();

      // Create SSML message
      final ssmlMessage = _createSSMLMessage(
        text,
        voice,
        rate,
        volume,
        pitch,
        requestId,
      );

      // Stream controller for collecting audio data
      final audioData = <int>[];
      bool isAudioStarted = false;
      bool isCompleted = false;
      StreamSubscription<dynamic>? messageSubscription;

      // For streaming playback - we'll collect all data and play at once
      // since individual chunks aren't valid MP3 files
      if (streamToPlayer) {
        // Streaming mode enabled - will play audio when complete
      }

      // Listen to WebSocket messages using the shared message stream
      messageSubscription = _messageController!.stream.listen(
        (message) {
          if (message is String) {
            // Handle text messages (metadata, etc.)
            final lines = message.split('\r\n');
            for (final line in lines) {
              if (line.startsWith('Path:')) {
                final path = line.substring(5).trim();
                if (path == 'response') {
                  isAudioStarted = true;
                } else if (path == 'turn.end') {
                  isCompleted = true;
                } else if (path == 'error') {
                  throw Exception('Server error: $message');
                }
              }
            }
          } else if (message is List<int>) {
            // Handle binary audio data - extract audio content from the message
            if (isAudioStarted && !isCompleted) {
              final audioContent = _extractAudioFromMessage(message);
              if (audioContent.isNotEmpty) {
                audioData.addAll(audioContent);
              }
            }
          }
        },
        onError: (error) {
          throw Exception('WebSocket error: $error');
        },
      );

      // Send SSML message
      _webSocketChannel!.sink.add(ssmlMessage);

      // Wait for completion with timeout
      int timeoutCounter = 0;
      const maxTimeout = 100; // 5 seconds max
      while (!isCompleted && timeoutCounter < maxTimeout) {
        await Future.delayed(const Duration(milliseconds: 50));
        timeoutCounter++;

        // Check if connection is still alive
        if (!_isConnected ||
            _webSocketChannel == null ||
            _messageController == null) {
          messageSubscription.cancel();
          throw Exception('WebSocket connection lost during synthesis');
        }

        // Debug: Progress tracking
        if (timeoutCounter % 20 == 0) {
          // WebSocket TTS: Waiting for completion... (${timeoutCounter * 50}ms)
        }
      }

      if (!isCompleted) {
        messageSubscription.cancel();
        throw Exception(
          'Synthesis timeout - no completion signal received. Audio data size: ${audioData.length} bytes',
        );
      }

      // Clean up message subscription (but keep WebSocket connection alive)
      messageSubscription.cancel();

      // Clean up streaming resources
      if (streamToPlayer) {
        // Streaming completed. Total audio data: ${audioData.length} bytes
      }

      if (audioData.isEmpty) {
        throw Exception('No audio data received');
      }

      return Uint8List.fromList(audioData);
    } catch (e) {
      // If it's a connection error, try to reset the connection for next time
      if (e.toString().contains('WebSocket') ||
          e.toString().contains('connection')) {
        await closeConnection();
      }
      throw Exception('Error in text-to-speech conversion: $e');
    }
  }

  /// Helper method to generate WebSocket key
  String _generateWebSocketKey() {
    final random = List.generate(16, (i) => Random().nextInt(256));
    return base64.encode(random);
  }

  /// Generate a unique connection ID for the WebSocket session
  /// Matches the JavaScript implementation format: xxxxxxxx-xxxx-xxxx-yxxx-xxxxxxxxxxxx
  String _generateConnectionId() {
    final random = Random();

    String generateHex(int length) {
      return List.generate(
          length, (index) => random.nextInt(16).toRadixString(16)).join();
    }

    String generateY() {
      // For the 'y' position, generate a hex digit where the first bit is set to 8, 9, A, or B
      final yValue = (3 & random.nextInt(16)) | 8;
      return yValue.toRadixString(16);
    }

    // Generate connection ID in format: xxxxxxxx-xxxx-xxxx-yxxx-xxxxxxxxxxxx
    return '${generateHex(8)}-${generateHex(4)}-${generateHex(4)}-${generateY()}${generateHex(3)}-${generateHex(12)}';
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

  /// Create WebSocket configuration message
  String _createConfigMessage() {
    return '''Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n{
  "context": {
    "synthesis": {
      "audio": {
        "metadataoptions": {
          "sentenceBoundaryEnabled": "false",
          "wordBoundaryEnabled": "true"
        },
        "outputFormat": "$_defaultOutputFormat"
      }
    }
  }
}''';
  }

  /// Create WebSocket SSML message
  String _createSSMLMessage(
    String text,
    Voice voice,
    int rate,
    int volume,
    int pitch,
    String requestId,
  ) {
    // Convert rate, volume, and pitch to string format (like Node.js implementation)
    final rateStr =
        rate != 0 ? ' rate="${rate > 0 ? '+' : ''}$rate%"' : ' rate="default"';
    final volumeStr = volume != 0
        ? ' volume="${volume > 0 ? '+' : ''}$volume%"'
        : ' volume="default"';
    final pitchStr = pitch != 0
        ? ' pitch="${pitch > 0 ? '+' : ''}$pitch%"'
        : ' pitch="default"';

    // Extract language from voice (e.g., "en-US-JennyNeural" -> "en-US")
    final language = voice.locale;

    final ssml = '''<?xml version="1.0"?>
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="$language">
  <voice name="${voice.shortName}">
    <prosody$rateStr$volumeStr$pitchStr>
      ${_escapeXml(text)}
    </prosody>
  </voice>
</speak>''';

    // Format message to match the JavaScript implementation
    var message =
        '''X-RequestId:$requestId\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n$ssml''';
    return message;
  }

  /// Escape XML special characters
  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Convert text to speech with real-time streaming playback
  /// Audio starts playing as soon as the first chunk arrives
  Future<Uint8List> textToSpeechStream({
    required String text,
    required Voice voice,
    int rate = 0,
    int volume = 0,
    int pitch = 0,
  }) async {
    return await textToSpeech(
      text: text,
      voice: voice,
      rate: rate,
      volume: volume,
      pitch: pitch,
      streamToPlayer: true,
    );
  }
}
