// lib/main.dart

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/intro_screen.dart';

late List<CameraDescription> cameras;

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
    runApp(const MyApp());
  } catch (e) {
    print('Error initializing app: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF5CE1FF),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        fontFamily: 'Inter',
      ),
      home: const IntroScreen(),
    );
  }
}
// lib/screens/main_screen.dart

// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// import 'package:google_generative_ai/google_generative_ai.dart';
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:speech_to_text/speech_to_text.dart';
// import 'dart:io';

// late List<CameraDescription> cameras;

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   cameras = await availableCameras();
//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       home: MainScreen(),
//     );
//   }
// }

// class MainScreen extends StatefulWidget {
//   @override
//   _MainScreenState createState() => _MainScreenState();
// }

// class _MainScreenState extends State<MainScreen> {
//   late final TextRecognizer _textRecognizer;
//   late final GenerativeModel _model;
//   late final FlutterTts _flutterTts;
//   late final SpeechToText _speechToText;
//   CameraController? _cameraController;
//   bool _isCameraInitialized = false;
//   bool _isProcessing = false;
//   bool _isListening = false;
//   String _lastDetectedText = '';
//   List<ChatMessage> _messages = [];
//   double captureWidth = 300;
//   double captureHeight = 200;
//   bool _isProblemConfirmed = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializeServices();
//   }

//   Future<void> _initializeServices() async {
//     _textRecognizer = TextRecognizer();
//     _model = GenerativeModel(
//       model: 'gemini-pro',
//       apiKey: 'AIzaSyC2Wapy4T3QA1T56K_vDnPGf53MgIjmYOs',
//     );
//     _flutterTts = FlutterTts();
//     _speechToText = SpeechToText();

//     await _flutterTts.setLanguage('en-US');
//     await _flutterTts.setSpeechRate(0.5);
//     await _speechToText.initialize();

//     _addMessage("Ready to help! Say 'start camera' or tap the button to begin.", false);
//     await _speak("Ready to help! Say start camera or tap the button to begin.");
//     _startListening();
//   }

//   Future<void> _startListening() async {
//     if (!_isListening) {
//       bool available = await _speechToText.initialize();
//       if (available) {
//         setState(() => _isListening = true);
//         _speechToText.listen(
//           onResult: (result) {
//             if (result.finalResult) {
//               _handleVoiceCommand(result.recognizedWords.toLowerCase());
//             }
//           },
//           listenFor: Duration(seconds: 30),
//           pauseFor: Duration(seconds: 3),
//           partialResults: false,
//           // onError: (error) => print('Error: $error'),
//           cancelOnError: true,
//         );
//       }
//     }
//   }

//   void _handleVoiceCommand(String command) {
//     print('Voice command received: $command');
//     if (command.contains('start camera') && !_isCameraInitialized) {
//       _initializeCamera();
//     } else if (command.contains('yes') && !_isProblemConfirmed && _lastDetectedText.isNotEmpty) {
//       _confirmProblem();
//     } else if (command.contains('stop') || command.contains('reset')) {
//       _resetDetection();
//     }
//   }

//   Future<void> _initializeCamera() async {
//     _cameraController = CameraController(
//       cameras[0],
//       ResolutionPreset.medium,
//       enableAudio: false,
//       imageFormatGroup: Platform.isAndroid
//           ? ImageFormatGroup.nv21
//           : ImageFormatGroup.bgra8888,
//     );

//     try {
//       await _cameraController!.initialize();
      
//       if (!mounted) return;

//       setState(() {
//         _isCameraInitialized = true;
//       });

//       _cameraController!.startImageStream((image) {
//         if (!_isProcessing && !_isProblemConfirmed) {
//           _processImage(image);
//         }
//       });

//       _addMessage("Camera ready! Show your math problem in the box.", false);
//       await _speak("Camera ready! Show your math problem in the box.");
//     } catch (e) {
//       print('Error initializing camera: $e');
//     }
//   }

//   Future<void> _processImage(CameraImage image) async {
//     _isProcessing = true;

//     try {
//       final inputImage = _convertCameraImage(image);
//       if (inputImage == null) return;

//       final recognizedText = await _textRecognizer.processImage(inputImage);
//       final text = recognizedText.text.trim();

//       if (text.isNotEmpty && 
//           text != _lastDetectedText && 
//           _isMathProblem(text)) {
//         setState(() {
//           _lastDetectedText = text;
//         });
        
//         _addMessage("I see: $text\nIs this correct?", false);
//         await _speak("I see this problem: $text. Is this correct?");
//       }
//     } catch (e) {
//       print('Error processing image: $e');
//     } finally {
//       _isProcessing = false;
//     }
//   }

//   InputImage? _convertCameraImage(CameraImage image) {
//     try {
//       final rotation = InputImageRotationValue.fromRawValue(0) ?? 
//                       InputImageRotation.rotation0deg;

//       final format = Platform.isAndroid
//           ? InputImageFormat.nv21
//           : InputImageFormat.bgra8888;

//       final metadata = InputImageMetadata(
//         size: Size(image.width.toDouble(), image.height.toDouble()),
//         rotation: rotation,
//         format: format,
//         bytesPerRow: image.planes[0].bytesPerRow,
//       );

//       return InputImage.fromBytes(
//         bytes: image.planes[0].bytes,
//         metadata: metadata,
//       );
//     } catch (e) {
//       print('Error converting image: $e');
//       return null;
//     }
//   }

//   bool _isMathProblem(String text) {
//     final hasNumbers = RegExp(r'\d').hasMatch(text);
//     final hasOperators = RegExp(r'[+\-*/=×÷]').hasMatch(text);
//     return text.length > 1 && hasNumbers && hasOperators;
//   }

//   Future<void> _confirmProblem() async {
//     setState(() {
//       _isProblemConfirmed = true;
//     });

//     _addMessage("Solving: $_lastDetectedText", false);
//     await _speak("Alright, let me solve this for you!");

//     final solution = await _solveProblem(_lastDetectedText);
//     _addMessage(solution, false);
//     await _speak(solution);
//   }

//   Future<String> _solveProblem(String problem) async {
//     try {
//       final prompt = '''
//       You are a helpful math tutor. Solve this problem step by step: $problem
//       1. First explain what we're solving
//       2. Show the solution process clearly
//       3. Provide the final answer
//       Keep it simple and clear.
//       ''';

//       final response = await _model.generateContent([
//         Content.text(prompt)
//       ]);

//       return response.candidates.first.content.parts
//           .whereType<TextPart>()
//           .map((part) => part.text)
//           .join(' ');
//     } catch (e) {
//       return "Sorry, I had trouble solving that. Could you show me the problem again?";
//     }
//   }

//   void _resetDetection() {
//     setState(() {
//       _lastDetectedText = '';
//       _isProblemConfirmed = false;
//     });
//     _speak("Ready for a new problem!");
//   }

//   Future<void> _speak(String text) async {
//     try {
//       await _flutterTts.stop();
//       await _flutterTts.speak(text);
//     } catch (e) {
//       print('Error speaking: $e');
//     }
//   }

//   void _addMessage(String text, bool isUser) {
//     setState(() {
//       _messages.insert(0, ChatMessage(
//         text: text,
//         isUser: isUser,
//       ));
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           // Main Container
//           Container(
//             color: Color(0xFF1A1A1A),
//             child: Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   if (!_isCameraInitialized)
//                     _buildStartButton()
//                   else
//                     _buildCameraPreview(),
//                 ],
//               ),
//             ),
//           ),

//           // Capture Box Overlay
//           if (_isCameraInitialized)
//             Center(
//               child: Container(
//                 width: captureWidth + 40,
//                 height: captureHeight + 40,
//                 decoration: BoxDecoration(
//                   border: Border.all(
//                     color: Color(0xFF5CE1FF),
//                     width: 3,
//                   ),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Stack(
//                   children: [
//                     Positioned(
//                       top: -30,
//                       left: 0,
//                       right: 0,
//                       child: Container(
//                         margin: EdgeInsets.symmetric(horizontal: 20),
//                         padding: EdgeInsets.symmetric(
//                           horizontal: 16,
//                           vertical: 8,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Color(0xFF5CE1FF),
//                           borderRadius: BorderRadius.circular(8),
//                           boxShadow: [
//                             BoxShadow(
//                               offset: Offset(2, 2),
//                               color: Colors.black,
//                               blurRadius: 0,
//                             ),
//                           ],
//                         ),
//                         child: Text(
//                           'Show problem here',
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.black,
//                             fontWeight: FontWeight.bold,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//           // Voice Indicator
//           Positioned(
//             top: 40,
//             right: 20,
//             child: Container(
//               padding: EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: _isListening ? Color(0xFF5CFF8F) : Color(0xFFFF5C5C),
//                 borderRadius: BorderRadius.circular(30),
//                 boxShadow: [
//                   BoxShadow(
//                     offset: Offset(2, 2),
//                     color: Colors.black,
//                     blurRadius: 0,
//                   ),
//                 ],
//               ),
//               child: Icon(
//                 _isListening ? Icons.mic : Icons.mic_off,
//                 color: Colors.black,
//                 size: 24,
//               ),
//             ),
//           ),

//           // Bottom Chat Area
//           Positioned(
//             bottom: 0,
//             left: 0,
//             right: 0,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 if (_lastDetectedText.isNotEmpty && !_isProblemConfirmed)
//                   _buildConfirmationBar(),
//                 _buildChatArea(),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildStartButton() {
//     return GestureDetector(
//       onTap: _initializeCamera,
//       child: Container(
//         padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
//         decoration: BoxDecoration(
//           color: Color(0xFFFF5C5C),
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               offset: Offset(4, 4),
//               color: Colors.black,
//               blurRadius: 0,
//             ),
//           ],
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.camera_alt, color: Colors.black, size: 24),
//             SizedBox(width: 12),
//             Text(
//               'Start Camera',
//               style: TextStyle(
//                 color: Colors.black,
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCameraPreview() {
//     return Container(
//       width: captureWidth + 40,
//       height: captureHeight + 40,
//       decoration: BoxDecoration(
//         color: Colors.black,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             offset: Offset(4, 4),
//             color: Colors.black,
//             blurRadius: 0,
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(20),
//         child: CameraPreview(_cameraController!),
//       ),
//     );
//   }

//   Widget _buildConfirmationBar() {
//     return Container(
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Color(0xFF5CE1FF),
//         boxShadow: [
//           BoxShadow(
//             offset: Offset(0, -4),
//             color: Colors.black,
//             blurRadius: 0,
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Detected Problem:',
//             style: TextStyle(
//               color: Colors.black,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             _lastDetectedText,
//             style: TextStyle(
//               color: Colors.black,
//               fontSize: 18,
//             ),
//           ),
//           SizedBox(height: 12),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: [
//               _buildActionButton(
//                 'Yes, solve it!',
//                 Color(0xFF5CFF8F),
//                 _confirmProblem,
//               ),
//               _buildActionButton(
//                 'No, try again',
//                 Color(0xFFFF5C5C),
//                 _resetDetection,
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildActionButton(String text, Color color, VoidCallback onTap) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//         decoration: BoxDecoration(
//           color: color,
//           borderRadius: BorderRadius.circular(8),
//           boxShadow: [
//             BoxShadow(
//               offset: Offset(2, 2),
//               color: Colors.black,
//               blurRadius: 0,
//             ),
//           ],
//         ),
//         child: Text(
//           text,
//           style: TextStyle(
//             color: Colors.black,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         ),
      
//     );
//   }

//   Widget _buildChatArea() {
//     return Container(
//       height: 200,
//       decoration: BoxDecoration(
//         color: Color(0xFF1A1A1A).withOpacity(0.95),
//         boxShadow: [
//           BoxShadow(
//             offset: Offset(0, -4),
//             color: Colors.black,
//             blurRadius: 0,
//           ),
//         ],
//       ),
//       child: ListView.builder(
//         reverse: true,
//         padding: EdgeInsets.all(16),
//         itemCount: _messages.length,
//         itemBuilder: (context, index) {
//           return _buildMessageBubble(_messages[index]);
//         },
//       ),
//     );
//   }

//   Widget _buildMessageBubble(ChatMessage message) {
//     return Container(
//       margin: EdgeInsets.only(bottom: 12),
//       padding: EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: message.isUser ? Color(0xFFFF5C5C) : Color(0xFF5CE1FF),
//         borderRadius: BorderRadius.circular(8),
//         boxShadow: [
//           BoxShadow(
//             offset: Offset(2, 2),
//             color: Colors.black,
//             blurRadius: 0,
//           ),
//         ],
//       ),
//       child: Text(
//         message.text,
//         style: TextStyle(
//           color: Colors.black,
//           fontSize: 16,
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _cameraController?.dispose();
//     _textRecognizer.close();
//     _flutterTts.stop();
//     _speechToText.stop();
//     super.dispose();
//   }
// }

// class ChatMessage {
//   final String text;
//   final bool isUser;

//   ChatMessage({
//     required this.text,
//     required this.isUser,
//   });
// }