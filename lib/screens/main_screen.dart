// lib/screens/main_screen.dart

import 'dart:developer';

import 'package:ai_assistant/camera_overlay.dart';
import 'package:ai_assistant/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';
import 'dart:io';

class MainScreen extends StatefulWidget {
  final String mode; // 'math' or 'translation'
  final VoidCallback onTaskComplete;

  const MainScreen({
    Key? key,
    required this.mode,
    required this.onTaskComplete,
  }) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late final TextRecognizer _textRecognizer;
  bool _isContinuousListening = true;
  bool _isInitialized = false; // Add this at the start of your class

  late final GenerativeModel _model;
  late final FlutterTts _flutterTts;
  late final SpeechToText _speechToText;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isListening = false;
  String _lastDetectedText = '';
  List<ChatMessage> _messages = [];
  bool _isProblemConfirmed = false;
  Timer? _focusTimer;
  bool _isFocused = false;
  bool _isSpeaking = false;
  bool _isThinking = false;
  final double aspectRatio = 3 / 4;

  // Capture area dimensions
  final double captureWidth = 300;
  final double captureHeight = 200;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupTts();
  }

  Future<void> _setupTts() async {
    _flutterTts = FlutterTts();
// In MainScreen's initState
    final prefs = await SharedPreferences.getInstance();
    await _flutterTts.setSpeechRate(prefs.getDouble('speechRate') ?? 0.5);
    await _flutterTts.setLanguage(prefs.getString('language') ?? 'en-US');
    await _flutterTts.setVolume(prefs.getDouble('volume') ?? 1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusTimer?.cancel();
    _stopVoiceListening();
    _cameraController?.dispose();
    _textRecognizer.close();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize text recognizer
      _textRecognizer = TextRecognizer();

      // Initialize Gemini AI
      _model = GenerativeModel(
        model: 'gemini-pro',
        apiKey: 'AIzaSyC2Wapy4T3QA1T56K_vDnPGf53MgIjmYOs',
      );

      // Initialize TTS
      _flutterTts = FlutterTts();
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);

      // Initialize STT
      _speechToText = SpeechToText();
      await _speechToText.initialize(
        onError: (error) => print('Speech recognition error: $error'),
        onStatus: (status) => print('Speech recognition status: $status'),
      );

      _addMessage("Say 'start camera' or tap the button to begin!", false);
      await _speak("Say start camera or tap the button to begin!");
    } catch (e) {
      print('Error initializing services: $e');
    }
  }

  Future<void> _toggleVoiceListening() async {
    if (_isListening) {
      await _stopVoiceListening();
    } else {
      await _startVoiceListening();
    }
  }

  Future<void> _startVoiceListening() async {
    if (_isListening) return;

    try {
      if (!_isInitialized) {
        _isInitialized = await _speechToText.initialize(
          onError: (error) => print('Speech recognition error: $error'),
          onStatus: (status) => print('Speech recognition status: $status'),
        );
      }

      if (_isInitialized) {
        setState(() => _isListening = true);
        await _speechToText.listen(
          onResult: (result) {
            if (result.finalResult) {
              _handleVoiceCommand(result.recognizedWords.toLowerCase());
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          partialResults: false,
          listenMode: ListenMode.confirmation,
          cancelOnError: false,
        );
      }
    } catch (e) {
      print('Error in voice listening: $e');
      setState(() => _isListening = false);
    }
  }

  Future<void> _stopVoiceListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  Future<void> _handleVoiceCommand(String command) async {
    print('Voice command received: $command');

    if (command.contains('start camera') && !_isCameraInitialized) {
      await _initializeCamera();
    } else if (command.contains('yes') &&
        !_isProblemConfirmed &&
        _lastDetectedText.isNotEmpty) {
      await _confirmProblem();
    } else if ((command.contains('stop') || command.contains('reset')) &&
        _isCameraInitialized) {
      _resetDetection();
    }

    // Restart voice listening for next command
    await _startVoiceListening();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.medium, // Changed to medium for better performance
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();

      if (!mounted) return;

      // Set better camera parameters
      await _cameraController!.setFocusMode(FocusMode.auto);
      await _cameraController!.setExposureMode(ExposureMode.auto);
      await _cameraController!.setZoomLevel(1.0); // Reset zoom

      setState(() {
        _isCameraInitialized = true;
      });

      // Start image stream with reduced processing rate
      await _cameraController!.startImageStream((image) {
        if (!_isProcessing && !_isProblemConfirmed) {
          _processCameraImage(image);
        }
      });

      // In _initializeCamera method:
      _addMessage(
          widget.mode == 'math'
              ? "Camera ready! Show your math problem in the box."
              : "Camera ready! Show the text you want to translate in the box.",
          false);
      await _speak(widget.mode == 'math'
          ? "Camera ready! Show your math problem in the box."
          : "Camera ready! Show the text you want to translate in the box.");
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _autoFocus() async {
    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        await _cameraController!.setFocusPoint(Offset(0.5, 0.5));
        setState(() => _isFocused = true);
        await Future.delayed(Duration(milliseconds: 500));
        setState(() => _isFocused = false);
      }
    } catch (e) {
      print('Error during auto-focus: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _isProblemConfirmed) return;
    _isProcessing = true;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) return;

      final recognizedText = await _textRecognizer.processImage(inputImage);
      String textInBox = '';

      // Get capture area boundaries
      final captureRect = _getCaptureRect(image);

      // Only process text blocks that are within or overlap with the capture area
      for (TextBlock block in recognizedText.blocks) {
        final blockRect = Rect.fromLTRB(
          block.boundingBox?.left ?? 0,
          block.boundingBox?.top ?? 0,
          block.boundingBox?.right ?? 0,
          block.boundingBox?.bottom ?? 0,
        );

        if (blockRect.overlaps(captureRect)) {
          textInBox += block.text + ' ';
        }
      }

      textInBox = textInBox.trim();

      if (textInBox.isNotEmpty &&
          textInBox != _lastDetectedText &&
          _isMathProblem(textInBox)) {
        setState(() {
          _lastDetectedText = textInBox;
        });

        // Customize message based on mode
        String confirmMessage = widget.mode == 'math'
            ? "I see this problem: $textInBox. Is this correct?"
            : "I see this text: $textInBox. Should I translate it?";

        // In _confirmProblem method:
        _addMessage(
            widget.mode == 'math'
                ? "Solving: $_lastDetectedText"
                : "Translating: $_lastDetectedText",
            false);
        await _speak(widget.mode == 'math'
            ? "Alright, let me solve this for you!"
            : "Alright, let me translate this for you!");
        await _speak(confirmMessage);
      }
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isProcessing = false;
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: Platform.isAndroid
            ? InputImageFormat.nv21
            : InputImageFormat.bgra8888,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: metadata,
      );
    } catch (e) {
      print('Error converting image: $e');
      return null;
    }
  }

// Replace _isMathProblem method:
  bool _isMathProblem(String text) {
    if (widget.mode == 'translation') {
      // For translation, accept any reasonable text
      return text.length >= 2 &&
          text.length <= 500 &&
          text.trim().split(' ').length > 1; // At least 2 words
    } else {
      // For math mode, keep existing math detection logic
      final hasNumbers = RegExp(r'\d').hasMatch(text);
      final hasBasicOperators = RegExp(r'[+\-*/=×÷]').hasMatch(text);
      final hasAdvancedOperators = RegExp(r'[∫∂√∑∏≠≈≤≥±]').hasMatch(text);
      final hasVariables = RegExp(r'[a-zA-Z]').hasMatch(text);
      final isReasonableLength = text.length >= 2 && text.length <= 200;

      return isReasonableLength &&
          (hasBasicOperators ||
              hasAdvancedOperators ||
              (hasNumbers && hasVariables));
    }
    // // Check if it's a translation request first
    // if (text.toLowerCase().contains('translate') ||
    //     text.toLowerCase().contains('in hindi') ||
    //     text.toLowerCase().contains('in english') ||
    //     text.toLowerCase().contains('to hindi') ||
    //     text.toLowerCase().contains('to english')) {
    //   return true;
    // }

    // // Then check if it's a math problem
    // final hasNumbers = RegExp(r'\d').hasMatch(text);
    // final hasBasicOperators = RegExp(r'[+\-*/=×÷]').hasMatch(text);
    // final hasAdvancedOperators = RegExp(r'[∫∂√∑∏≠≈≤≥±]').hasMatch(text);
    // final hasVariables = RegExp(r'[a-zA-Z]').hasMatch(text);
    // final isReasonableLength = text.length >= 2 && text.length <= 200;

    // return isReasonableLength &&
    //     (hasBasicOperators ||
    //         hasAdvancedOperators ||
    //         (hasNumbers && hasVariables));
  }

  Future<void> _confirmProblem() async {
    setState(() {
      _isProblemConfirmed = true;
      _isThinking = true;
    });

    _addMessage("Solving: $_lastDetectedText", false);
    await _speak("Alright, let me solve this for you!");

    final solution = await _solveProblem(_lastDetectedText);
    setState(() {
      _isThinking = false;
    });

    _addMessage(solution, false);
    await _speakSol(solution);
  }

  Future<void> _speakSol(String text) async {
    try {
      // Enable awaitSpeakCompletion
      await _flutterTts.awaitSpeakCompletion(true);

      if (_isSpeaking) {
        await _flutterTts.stop();
      }

      setState(() => _isSpeaking = true);

      // Start speaking
      await _flutterTts.speak(text);

      // Wait for speech completion
      debugPrint("Waiting for TTS to complete...");
    } catch (e) {
      print('Error speaking: $e');
    } finally {
      // Ensure resetDetection is called after speech ends
      setState(() => _isSpeaking = false);
      Future.delayed(Duration(seconds: 1));
      widget.onTaskComplete();

      // _resetDetection();
    }
  }

  Future<String> _solveProblem(String problem) async {
    try {
      String prompt;
      if (widget.mode == 'translation') {
        prompt = '''
  You are a professional translator. Translate the following text clearly and concisely:
  $problem

  Ensure your response is:
  1. Start with "Translation:"
  2. If translating to Hindi, provide both Devanagari and romanized versions
  3. If requested, explain any cultural context or idioms
  4. Use simple, clear language...give only and only the translated text nothing else
  ''';
      }
      // Check if it's a calculus problem
      else if (problem.toLowerCase().contains('differentiate') ||
          problem.toLowerCase().contains('integrate') ||
          problem.toLowerCase().contains('derivative')) {
        prompt = '''
      You are a calculus expert. Solve the following problem clearly for text-to-speech:
      $problem

      Respond with:
      - A clear explanation of the steps in plain text.
      - Use words for symbols (e.g., "squared" instead of "^2", "plus" instead of "+").
      - Avoid any bold, italic, or formatting markers like stars (*).
      - Conclude with "The final answer is [answer]" in simple text.
      ''';
      }
      // For other math problems
      else {
        prompt = '''
      You are an expert mathematics tutor. Solve the following math problem clearly and concisely for text-to-speech:
      $problem

      Respond with:
      - A step-by-step explanation in plain text.
      - Use words to describe mathematical symbols (e.g., "times" for "*", "divided by" for "/").
      - Avoid any formatting symbols like stars (*), carets (^), or slashes (/).
      - Conclude with "The final answer is [answer]" in plain, readable text.
      ''';
      }

      final response = await _model.generateContent([Content.text(prompt)]);
      final solution = response.candidates.first.content.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join(' ');

      // Post-process the solution to ensure full TTS compatibility
      final cleanedSolution = _sanitizeResponseForTTS(solution);

      return cleanedSolution;
    } catch (e) {
      print('Error solving problem: $e');
      return "I encountered an error. Could you please show me the problem again?";
    }
  }

  String _sanitizeResponseForTTS(String response) {
    return response
        .replaceAll('*', '') // Remove stars
        .replaceAll('^', ' to the power of ') // Replace carets for exponents
        .replaceAll('/', ' divided by ') // Replace slashes for fractions
        .replaceAll('*', ' times ') // Replace asterisks for multiplication
        .replaceAll('+', ' plus ') // Replace addition symbols
        .replaceAll('-', ' minus ') // Replace subtraction symbols
        .replaceAll('=', ' equals '); // Replace equal signs
  }

  void _resetDetection() {
    setState(() {
      _lastDetectedText = '';
      _isProblemConfirmed = false;
      _isProcessing = false;
    });
    _speak("Ready for a new problem!");
  }

  Future<void> _speak(String text) async {
    try {
      if (_isSpeaking) {
        await _flutterTts.stop();
      }

      setState(() => _isSpeaking = true);
      await _flutterTts.speak(text);
    } catch (e) {
      print('Error speaking: $e');
      setState(() => _isSpeaking = false);
    }
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.insert(
          0,
          ChatMessage(
            text: text,
            isUser: isUser,
            timestamp: DateTime.now(),
          ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Top Section with Camera
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    // Camera or Start Button
                    Container(
                      color: Color(0xFF1A1A1A),
                      child: Center(
                        child: _isCameraInitialized
                            ? _buildCameraPreview()
                            : _buildStartButton(),
                      ),
                    ),
                    // Capture Box Overlay
                    if (_isCameraInitialized)
                      Center(
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: MediaQuery.of(context).size.width * 0.6,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Color(0xFF5CE1FF),
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: -30,
                                left: 0,
                                right: 0,
                                child: Container(
                                  margin: EdgeInsets.symmetric(horizontal: 20),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF5CE1FF),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        offset: Offset(2, 2),
                                        color: Colors.black,
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'Show problem here',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Voice Indicator
                    Positioned(
                      top: 40,
                      right: 20,
                      child: GestureDetector(
                        onTap: _toggleVoiceListening,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _isListening
                                ? const Color(0xFF5CFF8F)
                                : const Color(0xFFFF5C5C),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(
                                offset: Offset(2, 2),
                                color: Colors.black,
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isListening ? Icons.mic : Icons.mic_off,
                                color: Colors.black,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isListening ? 'Stop' : 'Listen',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Section with Chat and Controls
              Container(
                height: MediaQuery.of(context).size.height * 0.4,
                child: Column(
                  children: [
                    if (_lastDetectedText.isNotEmpty && !_isProblemConfirmed)
                      _buildConfirmationBar(),
                    Expanded(
                      child: _buildChatArea(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Replace the existing Positioned widget in the build method with:
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  // Settings Button
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF5CE1FF),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          offset: Offset(2, 2),
                          color: Colors.black,
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.settings,
                        size: 30,
                        color: Colors.black,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => SettingsScreen()),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  // Stop Button
                  GestureDetector(
                    onTap: () {
                      _resetDetection();
                      setState(() {
                        _isCameraInitialized = false;
                        _cameraController?.dispose();
                      });
                      _speak(
                          "Camera stopped. Say start camera or tap the button to begin again.");
                    },
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFFFF5C5C),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            offset: Offset(2, 2),
                            color: Colors.black,
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stop_circle, color: Colors.black),
                          SizedBox(width: 8),
                          Text(
                            'Stop',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              offset: Offset(2, 2),
              color: Colors.black,
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Color(0xFF1A1A1A).withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, -4),
            color: Colors.black,
            blurRadius: 0,
          ),
        ],
      ),
      child: ListView(
        reverse: true,
        padding: EdgeInsets.all(16),
        children: [
          // Thinking indicator comes first (when active)
          if (_isThinking)
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Color(0xFF5CE1FF),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    offset: Offset(2, 2),
                    color: Colors.black,
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    "I'm thinking...",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

          // Regular messages below
          ...List.generate(
            _messages.length,
            (index) => _buildMessageBubble(_messages[index]),
          ),
        ],
      ),
    );
  }

  Rect _getCaptureRect(CameraImage image) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double boxWidth = screenWidth * 0.8; // Same as your capture box width
    final double boxHeight =
        screenWidth * 0.6; // Same as your capture box height

    // Calculate center position
    final double centerX = image.width / 2;
    final double centerY = image.height / 2;

    // Calculate the box coordinates in image space
    return Rect.fromCenter(
      center: Offset(centerX, centerY),
      width: boxWidth,
      height: boxHeight,
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.isUser ? Color(0xFFFF5C5C) : Color(0xFF5CE1FF),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            offset: Offset(2, 2),
            color: Colors.black,
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        message.text,
        style: TextStyle(
          color: Colors.black,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: _initializeCamera,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        decoration: BoxDecoration(
          color: Color(0xFFFF5C5C),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              offset: Offset(4, 4),
              color: Colors.black,
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt, color: Colors.black, size: 24),
            SizedBox(width: 12),
            Text(
              'Start Camera',
              style: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return Stack(
      children: [
        // Base camera preview
        AspectRatio(
          aspectRatio: aspectRatio,
          child: CameraPreview(_cameraController!),
        ),

        // Dark overlay with cutout
        AspectRatio(
          aspectRatio: aspectRatio,
          child: CustomPaint(
            painter: DarkOverlayPainter(
              boxWidth: MediaQuery.of(context).size.width * 0.8,
              boxHeight: MediaQuery.of(context).size.width * 0.6,
            ),
          ),
        ),

        // Blue capture box
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.width * 0.6,
            decoration: BoxDecoration(
              border: Border.all(
                color: Color(0xFF5CE1FF),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -30,
                  left: 0,
                  right: 0,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Color(0xFF5CE1FF),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          offset: Offset(2, 2),
                          color: Colors.black,
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      'Show problem here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF5CE1FF),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, -4),
            color: Colors.black,
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.mode == 'math' ? 'Detected Problem:' : 'Detected Text:',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _lastDetectedText,
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                widget.mode == 'math' ? 'Yes, solve it!' : 'Yes, translate it!',
                Color(0xFF5CFF8F),
                _confirmProblem,
              ),
              _buildActionButton(
                'No, try again',
                Color(0xFFFF5C5C),
                _resetDetection,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}
