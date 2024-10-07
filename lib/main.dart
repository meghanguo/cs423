import 'dart:math';
import 'package:flutter/material.dart';
import 'package:painting_app_423/drawing_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Gesture Detection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Welcome to Painting App!'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Track the gesture
  List<bool> _gestures = [false, false];

  List<Offset> _points = [];
  bool _canDraw = true; // Control to allow redrawing

  // Method to check if any gesture is detected
  void _detectGesture(List<Offset> points) {
    if (points.length < 4) return; // Need at least 4 points to form a plus

    // Find extreme points to determine center
    double minX = points.map((p) => p.dx).reduce(min);
    double maxX = points.map((p) => p.dx).reduce(max);
    double minY = points.map((p) => p.dy).reduce(min);
    double maxY = points.map((p) => p.dy).reduce(max);

    // Calculate the center of the drawn gesture
    double centerX = (minX + maxX) / 2;
    double centerY = (minY + maxY) / 2;

    // Variables to track horizontal and vertical strokes
    bool hasHorizontal = false;
    bool hasVertical = false;

    for (Offset point in points) {
      // Check for horizontal strokes
      if ((point.dy - centerY).abs() < 30 && point.dx >= minX && point.dx <= maxX) {
        hasHorizontal = true;
      }
      // Check for vertical strokes
      if ((point.dx - centerX).abs() < 30 && point.dy >= minY && point.dy <= maxY) {
        hasVertical = true;
      }
    }

    // Determine if both horizontal and vertical strokes are present
    if (hasHorizontal && hasVertical) {
      _gestures[0] = true; // Indicate a plus sign was detected
    } else {
      _gestures[0] = false; // No plus sign detected
    }

    print("Horizontal: $hasHorizontal, Vertical: $hasVertical, Gesture Detected: ${_gestures[0]}");
  }

  // Navigate to the new drawing screen
  void _openNewDrawingScreen() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => DrawingPage(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: GestureDetector(
        onPanStart: (details) {
          if (_canDraw) {
            setState(() {
              _points = [details.localPosition];
            });
          }
        },
        onPanUpdate: (details) {
          if (_canDraw) {
            setState(() {
              _points.add(details.localPosition); // Capture touch points
            });
          }
        },
        onPanEnd: (details) {
          if (_canDraw) {
            setState(() {
              _canDraw = false; // Disable further drawing until reset
              _detectGesture(_points);
              if (_gestures[0]) {
                print("Plus sign detected!");
                _openNewDrawingScreen(); // Open new screen on plus detection
              } else {
                print("No gesture detected");
              }
              _points.clear(); // Clear points after recognition

              // Allow redrawing after a short delay
              Future.delayed(const Duration(milliseconds: 1), () {
                setState(() {
                  _canDraw = true; // Enable drawing again
                });
              });
            });
          }
        },
        child: Stack(
          children: [
            CustomPaint(
              painter: GesturePainter(points: _points),
              child: Container(),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter to visualize the drawn gesture
class GesturePainter extends CustomPainter {
  final List<Offset> points;

  GesturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(GesturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
