// lib/screens/intro_screen.dart

import 'package:ai_assistant/screens/task_select_screen.dart';
import 'package:flutter/material.dart';
import 'main_screen.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF5CE1FF),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(4, 4),
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Math Assistant',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your voice-controlled math problem solver',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            // Features Section
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildFeatureSection(
                    title: 'Voice Commands',
                    features: [
                      '"Start camera" - Activate camera',
                      '"Yes" - Confirm detected problem',
                      '"Stop" or "Reset" - Try a new problem',
                      "Sometimes if it doesnt works use the buttons.",
                    ],
                    icon: Icons.mic,
                    color: const Color(0xFFFF5C5C),
                  ),
                  const SizedBox(height: 24),
                  _buildFeatureSection(
                    title: 'Problem Detection',
                    features: [
                      'Show problem in the capture box properly if it gets recognized cover the camera or press yes frequently',
                      'Keep paper steady and well-lit',
                      'Wait for problem confirmation',
                    ],
                    icon: Icons.camera_alt,
                    color: const Color(0xFF5CFF8F),
                  ),
                  const SizedBox(height: 24),
                  _buildFeatureSection(
                    title: 'Get Solutions',
                    features: [
                      'Step-by-step explanations',
                      'Voice-guided solutions',
                      'Clear and easy to understand',
                    ],
                    icon: Icons.lightbulb,
                    color: const Color(0xFFFFDE59),
                  ),
                ],
              ),
            ),

            // Start Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => TaskSelectionScreen()),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5CE1FF),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(4, 4),
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Let\'s Solve Math!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(width: 12),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.black,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureSection({
    required String title,
    required List<String> features,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            offset: const Offset(4, 4),
            color: Colors.black.withOpacity(0.2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}