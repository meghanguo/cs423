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

  // Variables to track if a plus was drawn
  bool _horizontal = false;
  bool _vertical = false;

  // Method to check if any gesture is detected
  void _detectGesture(List<Offset> points) {
    if (points.length < 2) return; // Too few points to be a plus sign

    List<double> slopes = [];

    for (int i = 1; i < points.length; i++) {
      double dx = (points[i].dx - points[i - 1].dx).abs();
      double dy = (points[i].dy - points[i - 1].dy).abs();
      slopes.add(dy / dx);
    }

    double slopeSum = 0;
    double count = 0;
    double countInfinities = 0;
    double countZeros = 0;
    for (int i = 0; i < slopes.length; i++) {
      if (slopes[i] != double.infinity){
        slopeSum += slopes[i];
        count += 1;
      }
      if (slopes[i] < 1) {
        countZeros += 1;
      } else if (slopes[i] == double.infinity) {
        countInfinities += 1;
      }
    }

    print(countZeros);
    print(countInfinities);
    if (countZeros > 2 && countInfinities > 2 && max(countZeros, countInfinities) / min(countZeros, countInfinities) <= 3.0) {
      _horizontal = false;
      _vertical = false;
      print("not linear");
      return;
    }

    // detect plus sign
    print(slopeSum/count);
    if ((slopeSum / count >= 1 || count == 0) && _horizontal) {
      _gestures[0] = true;
      _horizontal = false;
    } else if (slopeSum / count < 1 && _vertical) {
      _gestures[0] = true;
      _vertical = false;
    } else if (slopeSum / count >= 1 || count == 0) {
      _vertical = true;
    } else {
      _horizontal = true;
    }

    print(_horizontal);
    print(_vertical);
    print(_gestures[0]);
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
                _vertical = false;
                _horizontal = false;
                _gestures[0] = false;
                _openNewDrawingScreen(); // Open new screen on plus detection
              }
              else {
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
            Text("Favorites"),
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
