// lib/screens/main_screen.dart

import 'package:ai_assistant/camera_overlay.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';
import 'dart:io';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late final TextRecognizer _textRecognizer;
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
    _startVoiceListening();
    _setupTts(); // Add this line
  }

  Future<void> _setupTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
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

  Future<void> _startVoiceListening() async {
    if (!_isListening && await _speechToText.initialize()) {
      setState(() => _isListening = true);
      _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
            _handleVoiceCommand(result.recognizedWords.toLowerCase());
          }
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 3),
        partialResults: false,
        listenMode: ListenMode.confirmation,
        cancelOnError: true,
      );
    }
  }

  void _stopVoiceListening() {
    _speechToText.stop();
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

      _addMessage("Camera ready! Show your math problem in the box.", false);
      await _speak("Camera ready! Show your math problem in the box.");
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

        _addMessage(
            "I see: $textInBox\nIs this correct? Say 'yes' or tap confirm.",
            false);
        await _speak("I see this problem: $textInBox. Is this correct?");
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

  bool _isMathProblem(String text) {
    // Enhanced math problem detection
    final hasNumbers = RegExp(r'\d').hasMatch(text);
    final hasOperators = RegExp(r'[+\-*/=×÷]').hasMatch(text);
    final isReasonableLength = text.length >= 2 && text.length <= 50;
    return isReasonableLength && hasNumbers && hasOperators;
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
    _resetDetection();
  }
}

  // Future<void> _confirmProblem() async {
  //   setState(() {
  //     _isProblemConfirmed = true;
  //     _isThinking = true;
  //   });

  //   _addMessage("I'm thinking about this problem...", false);
  //   await _speak("Let me think about this problem");

  //   try {
  //     // Get the solution
  //     final solution = await _solveProblem(_lastDetectedText);

  //     setState(() {
  //       _isThinking = false;
  //     });

  //     // Add the complete solution to chat
  //     _addMessage(solution, false);

  //     // Speak the complete solution
  //     await _speakSolution(solution);

  //     // Small delay before resetting
  //     // await Future.delayed(Duration(seconds: 2));
  //   } catch (e) {
  //     print('Error in confirmation: $e');
  //     setState(() {
  //       _isThinking = false;
  //     });
  //     _addMessage("Sorry, I had trouble with that. Let's try again.", false);
  //     await _speak("Sorry, I had trouble with that. Let's try again.");
  //   }

  //   _resetDetection();
  // }
  Future<String> _solveProblem(String problem) async {
    try {
      final prompt = '''
      You are a helpful math tutor. Solve this problem step by step: $problem
      
      Format your response exactly like this:
      1. Let's understand the problem.
      2. Here's how we solve it:
      3. Step 1: [First step explanation]
      4. Step 2: [Second step explanation]
      5. Therefore, the answer is [final answer].
      
      Keep each step clear and easy to understand. Dont include any symbols only text and numbers. Dont give anything in bold. 
      Use periods to separate sentences clearly.
      ''';

      final response = await _model.generateContent([Content.text(prompt)]);

      final solution = response.candidates.first.content.parts
          .whereType<TextPart>()
          .map((part) => part.text)
          .join(' ');

      return solution;
    } catch (e) {
      print('Error solving problem: $e');
      return "Sorry, I had trouble solving that. Could you show me the problem again?";
    }
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
      body: Column(
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
                    onTap: _startVoiceListening,
                    child: Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isListening
                            ? Color(0xFF5CFF8F)
                            : Color(0xFFFF5C5C),
                        borderRadius: BorderRadius.circular(30),
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
                          Icon(
                            _isListening ? Icons.mic : Icons.mic_off,
                            color: Colors.black,
                            size: 24,
                          ),
                          if (_isListening) ...[
                            SizedBox(width: 8),
                            Text(
                              'Listening',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
            'Detected Problem:',
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
                'Yes, solve it!',
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
