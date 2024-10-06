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
  List<Offset> _points = [];
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

  // Navigate to the new drawing screen
  void _openNewDrawingScreen() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const NewScreen(),
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
              if (_detectPlusGesture(_points)) {
                print("Plus sign detected!");
                _openNewDrawingScreen(); // Open new screen on plus detection
              } else {
                print("Not a plus sign, try again.");
              }
              _points.clear(); // Clear points after recognition

              // Allow redrawing after a short delay
              Future.delayed(const Duration(seconds: 2), () {
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
            // The box with the plus button
            Positioned(
              top: 20, // Adjust top position
              left: 20, // Adjust left position
              child: Container(
                width: 200, // Adjust width as needed
                height: 250, // Adjust height as needed
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3), // changes position of shadow
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Click or draw a plus gesture to start a new drawing',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton(
                      onPressed: () {
                        print('Plus button clicked');
                        _openNewDrawingScreen(); // Open new screen on button click
                      },
                      child: const Icon(Icons.add),
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

// New screen widget
class NewScreen extends StatelessWidget {
  const NewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Screen'),
      ),
      body: Center(
        child: const Text(
          'You opened a new screen!',
          style: TextStyle(fontSize: 24),
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
