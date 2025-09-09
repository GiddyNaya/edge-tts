import 'package:edge_tts_demo/audio_manager.dart';
import 'package:flutter/material.dart';
import 'package:edge_tts/edge_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';

void main() {
  runApp(const EdgeTTSDemoApp());
}

class EdgeTTSDemoApp extends StatelessWidget {
  const EdgeTTSDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EdgeTTS by GiddyNaya',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const EdgeTTSDemoPage(),
    );
  }
}

class EdgeTTSDemoPage extends StatefulWidget {
  const EdgeTTSDemoPage({super.key});

  @override
  State<EdgeTTSDemoPage> createState() => _EdgeTTSDemoPageState();
}

class _EdgeTTSDemoPageState extends State<EdgeTTSDemoPage> {
  final EdgeTTSService _ttsService = EdgeTTSService();
  final AudioManager _audioManager = AudioManager();
  final TextEditingController _textController = TextEditingController();

  Voice? _selectedVoice;
  double _rate = 0.0;
  double _volume = 0.0;
  double _pitch = 0.0;

  bool _isLoading = false;
  bool _isConverting = false;
  bool _isFetching = false;
  bool _isPlaying = false;
  String _statusMessage = '';

  // Voice and language loading state
  List<Voice> _availableVoices = [];
  List<Voice> _filteredVoices = [];
  List<Language> _availableLanguages = [];
  bool _isLoadingVoices = true;
  String? _voiceLoadingError;
  String _selectedLanguageLocale =
      ''; // Use language locale instead of Language object

  @override
  void initState() {
    super.initState();
    _textController.text =
        'Hello! Welcome to the EdgeTTS demo. This is a Flutter implementation of Microsoft\'s text-to-speech service.';

    // Listen to player state changes
    _audioManager.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    // Pre-initialize WebSocket connection and load available voices
    _loadVoices();
    _preInitializeConnection();
  }

  Future<void> _preInitializeConnection() async {
    try {
      await _ttsService.preInitializeConnection();
    } catch (e) {
      // Pre-initialization failed, but that's okay - it will retry on first TTS request
      print('WebSocket pre-initialization failed: $e');
    }
  }

  Future<void> _loadVoices() async {
    try {
      setState(() {
        _isLoadingVoices = true;
        _voiceLoadingError = null;
      });

      // Load both voices and languages
      final voices = await _ttsService.getVoices();
      final languages = await _ttsService.getLanguages();

      setState(() {
        _availableVoices = voices;
        _availableLanguages = languages;
        _isLoadingVoices = false;

        // Set default to "All Languages" (empty string)
        _selectedLanguageLocale = 'en-US';

        // Filter voices by selected language (will show all voices initially)
        _filterVoicesByLanguage(_selectedLanguageLocale);

        // Set default voice if available - prefer Andrew
        if (_filteredVoices.isNotEmpty && _selectedVoice == null) {
          // Try to find Andrew first, otherwise use the first available voice
          _selectedVoice = _filteredVoices.firstWhere(
            (voice) => voice.shortName == 'en-US-AndrewNeural',
            orElse: () => _filteredVoices.first,
          );
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingVoices = false;
        _voiceLoadingError = e.toString();
      });
    }
  }

  void _filterVoicesByLanguage(String languageLocale) {
    setState(() {
      _selectedLanguageLocale = languageLocale;
      if (languageLocale.isEmpty) {
        _filteredVoices = _availableVoices;
      } else {
        _filteredVoices = _availableVoices.where((voice) {
          return voice.locale.toLowerCase() == languageLocale.toLowerCase();
        }).toList();
      }

      // Update selected voice if current selection is not in filtered list
      if (_filteredVoices.isNotEmpty &&
          !_filteredVoices
              .any((voice) => voice.shortName == _selectedVoice?.shortName)) {
        _selectedVoice = _filteredVoices.first;
      }
    });
  }

  String _getValidDropdownValue() {
    // Always return empty string if no languages are loaded yet
    if (_availableLanguages.isEmpty) {
      return '';
    }

    // Check if the selected locale exists in available languages (case-insensitive)
    final matchingLang = _availableLanguages.firstWhere(
      (lang) =>
          lang.locale.toLowerCase() == _selectedLanguageLocale.toLowerCase(),
      orElse: () => Language(locale: '', name: '', region: '', code: ''),
    );

    if (matchingLang.locale.isNotEmpty) {
      return matchingLang
          .locale; // Return the exact case from the language list
    }

    // Fallback to empty string
    return '';
  }

  @override
  void dispose() {
    _audioManager.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _convertToSpeech() async {
    if (_textController.text.trim().isEmpty) {
      _showMessage('Please enter some text to convert to speech.');
      return;
    }

    if (_selectedVoice == null) {
      _showMessage('Please select a voice first.');
      return;
    }

    setState(() {
      _isConverting = true;
      _statusMessage = 'Converting text to speech...';
    });

    try {
      final audioData = await _ttsService.textToSpeech(
        text: _textController.text,
        voice: _selectedVoice!,
        rate: _rate.round(),
        volume: _volume.round(),
        pitch: _pitch.round(),
      );

      setState(() {
        _statusMessage = 'Playing audio...';
      });

      await _audioManager.playAudio(audioData);

      setState(() {
        _statusMessage = 'Audio generated and playing successfully!';
      });
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      setState(() {
        _isConverting = false;
      });
    }
  }

  Future<void> _convertToSpeechAsStream() async {
    if (_textController.text.trim().isEmpty) {
      _showMessage('Please enter some text to convert to speech.');
      return;
    }

    if (_selectedVoice == null) {
      _showMessage('Please select a voice first.');
      return;
    }

    setState(() {
      _isFetching = true;
      _statusMessage = 'Converting text to speech with real-time streaming...';
    });

    try {
      final audioData = await _ttsService.textToSpeechStream(
        text: _textController.text,
        voice: _selectedVoice!,
        rate: _rate.round(),
        volume: _volume.round(),
        pitch: _pitch.round(),
      );

      setState(() {
        _statusMessage = 'Playing audio...';
      });

      await _audioManager.playAudioAsStream(audioData);

      setState(() {
        _statusMessage = 'Audio streaming completed successfully!';
      });
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      setState(() {
        _isFetching = false;
      });
    }
  }

  Future<void> _stopAudio() async {
    try {
      await _audioManager.stopAudio();
      setState(() {
        _statusMessage = 'Audio stopped.';
      });
    } catch (e) {
      _showMessage('Error stopping audio: $e');
    }
  }

  Future<void> _pauseAudio() async {
    try {
      await _audioManager.pauseAudio();
      setState(() {
        _statusMessage = 'Audio paused.';
      });
    } catch (e) {
      _showMessage('Error pausing audio: $e');
    }
  }

  Future<void> _resumeAudio() async {
    try {
      await _audioManager.resumeAudio();
      setState(() {
        _statusMessage = 'Audio resumed.';
      });
    } catch (e) {
      _showMessage('Error resuming audio: $e');
    }
  }

  void _showMessage(String message) {
    print(message);
    setState(() {
      _statusMessage = message;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EdgeTTS by GiddyNaya'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 2,
        actions: [
          Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final showText = screenWidth > 800;

              return TextButton.icon(
                onPressed: () {
                  // Open GitHub repository
                  launchUrl(
                    Uri.parse('https://github.com/GiddyNaya/edge-tts'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: Image.asset('assets/images/github-logo.png',
                    width: 40, height: 40),
                label: showText
                    ? const Text(
                        'View on GitHub',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : const SizedBox.shrink(),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Message
                if (_statusMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isLoading
                              ? Icons.hourglass_empty
                              : Icons.info_outline,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage,
                            style: TextStyle(color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Text Input
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Text to Convert',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _textController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Enter text to convert to speech...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Voice Selection
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Voice Selection',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!_isLoadingVoices && _voiceLoadingError == null)
                              IconButton(
                                onPressed: _loadVoices,
                                icon: const Icon(Icons.refresh),
                                tooltip: 'Refresh voices',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!_isLoadingVoices &&
                            _voiceLoadingError == null &&
                            _availableLanguages.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Filter by Language:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                value: _getValidDropdownValue(),
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Language',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: '',
                                    child: Text('All Languages'),
                                  ),
                                  ..._availableLanguages
                                      .where((lang) =>
                                          lang.locale.isNotEmpty &&
                                          lang.name.isNotEmpty)
                                      .map((lang) => DropdownMenuItem<String>(
                                            value: lang.locale,
                                            child: Text(lang.displayName),
                                          ))
                                      .toList(),
                                ],
                                onChanged: (value) {
                                  print('Dropdown changed to: $value');
                                  if (value != null) {
                                    _filterVoicesByLanguage(value);
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        if (_isLoadingVoices)
                          const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Loading voices...'),
                            ],
                          )
                        else if (_voiceLoadingError != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Error loading voices: $_voiceLoadingError',
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loadVoices,
                                child: const Text('Retry'),
                              ),
                            ],
                          )
                        else
                          DropdownButtonFormField<Voice>(
                            value: _selectedVoice,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select Voice',
                              border: OutlineInputBorder(),
                            ),
                            items: _filteredVoices.map((voice) {
                              final displayName =
                                  '${voice.shortName.split('-')[2].replaceAll('Neutral', '')} (${voice.gender})';
                              print(voice.shortName);
                              return DropdownMenuItem<Voice>(
                                value: voice,
                                child: Text(displayName),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedVoice = value!;
                              });
                            },
                          ),
                        const SizedBox(height: 8),
                        Text(
                          '${_filteredVoices.length} voices available',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Speech Controls
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Speech Controls',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Rate Control
                        _buildSliderControl(
                          label: 'Speech Rate',
                          value: _rate,
                          min: -50,
                          max: 50,
                          divisions: 20,
                          onChanged: (value) {
                            setState(() {
                              _rate = value;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        // Volume Control
                        _buildSliderControl(
                          label: 'Volume',
                          value: _volume,
                          min: -50,
                          max: 50,
                          divisions: 20,
                          onChanged: (value) {
                            setState(() {
                              _volume = value;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        // Pitch Control
                        _buildSliderControl(
                          label: 'Pitch',
                          value: _pitch,
                          min: -50,
                          max: 50,
                          divisions: 20,
                          onChanged: (value) {
                            setState(() {
                              _pitch = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                if (!_isPlaying)
                  // Action Buttons
                  ElevatedButton.icon(
                    onPressed:
                        (_isConverting || _isFetching || _selectedVoice == null)
                            ? null
                            : _convertToSpeechAsStream,
                    icon: _isFetching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_isFetching ? 'Fetching...' : 'Play now'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),

                if (_isPlaying)
                  OutlinedButton.icon(
                    onPressed: _stopAudio,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                const SizedBox(height: 24),

                // Information Card
                Card(
                  color: Colors.grey.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'About EdgeTTS',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This demo uses Microsoft\'s EdgeTTS service to convert text to speech. '
                          'The service provides high-quality, natural-sounding voices in multiple languages. '
                          'No API key is required as it uses the same service as Microsoft Edge browser.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderControl({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text('${value.round()}')],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
