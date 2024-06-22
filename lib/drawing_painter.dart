import 'package:flutter/material.dart';

class DrawingPainter extends CustomPainter {
  final List<List<Offset>> drawings;
  final Color color;
  late double yOffset = 15; // Offset to the height of each point

  DrawingPainter(this.drawings, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    for (var drawing in drawings) {
      for (int i = 0; i < drawing.length - 1; i++) {
        if (drawing[i] != null && drawing[i + 1] != null) {
          Offset adjustedStart = Offset(drawing[i].dx, drawing[i].dy - yOffset);
          Offset adjustedEnd = Offset(drawing[i + 1].dx, drawing[i + 1].dy - yOffset);
          canvas.drawLine(adjustedStart, adjustedEnd, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
