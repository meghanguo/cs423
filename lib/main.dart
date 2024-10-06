import 'package:flutter/material.dart';

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
      home: const MyHomePage(title: 'Plus Gesture Recognition'),
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
  List<Offset> _points = [];
  String _message = "Draw a + gesture!";
  bool _canDraw = true; // Control to allow redrawing

  // Method to check if a "+" gesture is detected
  bool _detectPlusGesture(List<Offset> points) {
    if (points.length < 10) return false; // Too few points to be a plus sign

    int horizontalCount = 0;
    int verticalCount = 0;

    for (int i = 1; i < points.length; i++) {
      double dx = (points[i].dx - points[i - 1].dx).abs();
      double dy = (points[i].dy - points[i - 1].dy).abs();

      // Detect horizontal movement (x changes significantly)
      if (dx > dy && dx > 20) {
        horizontalCount++;
      }
      // Detect vertical movement (y changes significantly)
      else if (dy > dx && dy > 20) {
        verticalCount++;
      }
    }

    // Simple condition for detecting "+" sign:
    // It needs to have both horizontal and vertical movement
    return horizontalCount > 5 && verticalCount > 5;
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
              if (_detectPlusGesture(_points)) {
                _message = "Plus sign detected!";
              } else {
                _message = "Not a plus sign, try again.";
              }
              _points.clear(); // Clear points after recognition

              // Allow redrawing after a short delay
              Future.delayed(Duration(seconds: 2), () {
                setState(() {
                  _canDraw = true; // Enable drawing again
                  _message = "Draw a + gesture!";
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
            Center(
              child: Text(
                _message,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
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
