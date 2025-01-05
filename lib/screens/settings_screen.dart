// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late FlutterTts _flutterTts;
  late SharedPreferences _prefs;
  
  // Settings state
  double _speechRate = 0.5;
  String _language = 'en-US';
  double _volume = 1.0;
  
  // Available options
  final List<Map<String, String>> _languages = [
    {'code': 'en-US', 'name': 'English (US)'},
    {'code': 'en-GB', 'name': 'English (UK)'},
    {'code': 'es-ES', 'name': 'Spanish'},
    {'code': 'fr-FR', 'name': 'French'},
    {'code': 'de-DE', 'name': 'German'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    _flutterTts = FlutterTts();
    _prefs = await SharedPreferences.getInstance();
    
    // Load saved settings or use defaults
    setState(() {
      _speechRate = _prefs.getDouble('speechRate') ?? 0.5;
      _language = _prefs.getString('language') ?? 'en-US';
      _volume = _prefs.getDouble('volume') ?? 1.0;
    });

    // Apply settings to TTS
    await _applySettings();
  }

  Future<void> _applySettings() async {
    await _flutterTts.setLanguage(_language);
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.setVolume(_volume);
    
    // Save settings
    await _prefs.setDouble('speechRate', _speechRate);
    await _prefs.setString('language', _language);
    await _prefs.setDouble('volume', _volume);
  }

  Future<void> _testSpeech() async {
    await _flutterTts.speak("This is a test of the current speech settings.");
  }

  Widget _buildSlider({
    required String title,
    required double value,
    required Function(double) onChanged,
    required String minLabel,
    required String maxLabel,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Color(0xFF5CE1FF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            offset: Offset(4, 4),
            color: Colors.black,
            blurRadius: 0,
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Text(
                minLabel,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Slider(
                  value: value,
                  onChanged: onChanged,
                  activeColor: Colors.black,
                  inactiveColor: Colors.black.withOpacity(0.3),
                ),
              ),
              Text(
                maxLabel,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Color(0xFF5CFF8F),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            offset: Offset(4, 4),
            color: Colors.black,
            blurRadius: 0,
          ),
        ],
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Language',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: DropdownButton<String>(
              value: _language,
              isExpanded: true,
              underline: SizedBox(),
              icon: Icon(Icons.arrow_drop_down, color: Colors.black),
              items: _languages.map((lang) {
                return DropdownMenuItem(
                  value: lang['code'],
                  child: Text(
                    lang['name']!,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() => _language = newValue);
                  _applySettings();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Color(0xFF5CE1FF),
        title: Text(
          'Speech Settings',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSlider(
              title: 'Speech Rate',
              value: _speechRate,
              onChanged: (value) {
                setState(() => _speechRate = value);
                _applySettings();
              },
              minLabel: 'Slow',
              maxLabel: 'Fast',
            ),
            _buildSlider(
              title: 'Volume',
              value: _volume,
              onChanged: (value) {
                setState(() => _volume = value);
                _applySettings();
              },
              minLabel: 'Quiet',
              maxLabel: 'Loud',
            ),
            _buildLanguageSelector(),
            SizedBox(height: 20),
            GestureDetector(
              onTap: _testSpeech,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 16),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.volume_up, color: Colors.black),
                    SizedBox(width: 8),
                    Text(
                      'Test Speech',
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
          ],
        ),
      ),
    );
  }
}