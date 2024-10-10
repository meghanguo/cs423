import 'package:flutter/material.dart';
import 'stroke.dart'; // Your Stroke class

class SavedDrawingPage extends StatelessWidget {
  final List<Stroke> strokes;
  final String drawingName;

  const SavedDrawingPage({Key? key, required this.strokes, required this.drawingName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(drawingName),
      ),
      body: CustomPaint(
        painter: DrawingPainter(strokes: strokes),
        child: Container(),
      ),
    );
  }
}

// This is a CustomPainter that takes strokes and draws them.
class DrawingPainter extends CustomPainter {
  final List<Stroke> strokes;

  DrawingPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (var stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.size
        ..strokeCap = StrokeCap.round;

      if (stroke.points.isNotEmpty) {
        for (int i = 0; i < stroke.points.length - 1; i++) {
          canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}