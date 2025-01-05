// lib/screens/task_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'main_screen.dart';

class TaskSelectionScreen extends StatefulWidget {
  @override
  _TaskSelectionScreenState createState() => _TaskSelectionScreenState();
}

class _TaskSelectionScreenState extends State<TaskSelectionScreen> {
  late FlutterTts _flutterTts;
  late SpeechToText _speechToText;
  bool _isListening = false;
  String _lastCommand = '';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Initialize TTS
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    
    // Initialize STT
    _speechToText = SpeechToText();
    await _speechToText.initialize(
      onStatus: (status) => print('Speech recognition status: $status'),
      onError: (error) => print('Speech recognition error: $error'),
    );

    _speak("What would you like to do? You can say 'solve math' or 'translate text'");
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      final bool available = await _speechToText.initialize();
      if (available) {
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
          cancelOnError: false,
        );
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  void _handleVoiceCommand(String command) {
    setState(() => _lastCommand = command);
    
    if (command.contains('math') || command.contains('solve')) {
      _navigateToMathScreen();
    } else if (command.contains('translate')) {
      _navigateToTranslationScreen();
    } else {
      _speak("I didn't catch that. Please say 'solve math' or 'translate text'");
    }
  }

  void _navigateToMathScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(
          mode: 'math',
          onTaskComplete: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => TaskSelectionScreen()),
            );
          },
        ),
      ),
    );
  }

  void _navigateToTranslationScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(
          mode: 'translation',
          onTaskComplete: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => TaskSelectionScreen()),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1A1A1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'What would you like to do?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: _buildOptionButton(
                      'Solve Math',
                      Icons.calculate,
                      Color(0xFF5CE1FF),
                      _navigateToMathScreen,
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: _buildOptionButton(
                      'Translate Text',
                      Icons.translate,
                      Color(0xFF5CFF8F),
                      _navigateToTranslationScreen,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 40),
              GestureDetector(
                onTap: _toggleListening,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: _isListening ? Color(0xFF5CFF8F) : Color(0xFFFF5C5C),
                    borderRadius: BorderRadius.circular(15),
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
                      Icon(
                        _isListening ? Icons.mic : Icons.mic_off,
                        color: Colors.black,
                        size: 30,
                      ),
                      SizedBox(width: 10),
                      Text(
                        _isListening ? 'Listening...' : 'Tap to Speak',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_lastCommand.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    'I heard: $_lastCommand',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton(
      String text, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              offset: Offset(4, 4),
              color: Colors.black,
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.black),
            SizedBox(height: 10),
            Text(
              text,
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}