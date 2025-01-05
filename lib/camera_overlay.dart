// Add this custom painter class at the bottom of your file
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class DarkOverlayPainter extends CustomPainter {
  final double boxWidth;
  final double boxHeight;

  DarkOverlayPainter({required this.boxWidth, required this.boxHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // Calculate the rectangle for the transparent cutout
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: boxWidth,
      height: boxHeight,
    );

    // Create a path for the entire screen
    final fullScreenPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create a path for the cutout
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(20)));

    // Use difference to create the overlay with cutout
    final overlayPath = Path.combine(
      PathOperation.difference,
      fullScreenPath,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Now modify your existing _buildCameraPreview method in the _MainScreenState class
