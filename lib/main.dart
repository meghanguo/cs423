import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For loading assets
import 'dart:math' as math;
import 'dart:convert';
import 'package:painting_app_423/drawing_page.dart'; // Your custom DrawingPage

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

class Point {
  final double x;
  final double y;

  Point(this.x, this.y);

  // Factory method to create a Point from JSON
  factory Point.fromJson(Map<String, dynamic> json) {
    return Point(json['x'], json['y']);
  }

  // Convert Point to JSON
  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
  };
}

// Class to represent a gesture
class Gesture {
  final List<Point> points;
  final String name;

  Gesture(this.points, {this.name = ""});

  // Factory method to create a Gesture from JSON
  factory Gesture.fromJson(Map<String, dynamic> json) {
    List<Point> points = (json['points'] as List)
        .map((p) => Point.fromJson(p))
        .toList();
    return Gesture(points, name: json['name']);
  }

  // Convert Gesture to JSON
  Map<String, dynamic> toJson() => {
    'name': name,
    'points': points.map((p) => p.toJson()).toList(),
  };
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Track the gesture templates
  List<Gesture> gestureTemplates = [];
  List<Offset> _points = []; // Store the drawn points
  bool _canDraw = true; // Control to allow redrawing

  String s = 'No gesture recognized';

  @override
  void initState() {
    super.initState();
    loadGestureTemplates(); // Load templates when the app starts
  }

  // Load saved gesture templates from assets/gestures
  Future<void> loadGestureTemplates() async {
    try {
      // Get a list of JSON files in the assets gestures directory
      List<String> gestureFiles = [
        'assets/gestures/plus.json',
        // Add more files as needed
      ];

      // Load each file from assets and parse it into gesture templates
      for (String file in gestureFiles) {
        String jsonString = await rootBundle.loadString(file);
        Map<String, dynamic> templateData = jsonDecode(jsonString);

        // Extract the gesture name
        String gestureName = templateData['name'];
        List<Point> points = (templateData['points'] as List)
            .map((p) => Point(p['x'], p['y']))
            .toList();

        Gesture gesture = Gesture(points, name: gestureName);
        setState(() {
          gestureTemplates.add(gesture);
        });
      }

      print("Loaded gestures: $gestureTemplates"); // Debugging all loaded gestures
    } catch (e) {
      print("Error loading gesture templates: $e");
    }
  }

  // Method to classify a gesture based on templates
  String classifyGesture(Gesture candidate) {
    double minDistance = double.infinity;
    String recognizedGestureName = "No match";

    for (Gesture template in gestureTemplates) {
      double distance = calculateDistance(candidate.points, template.points);
      print('Comparing with template: ${template.name}, Distance: $distance');
      if (distance < minDistance) {
        minDistance = distance;
        recognizedGestureName = template.name;
      }
    }
    return recognizedGestureName;
  }

  // Calculate the distance between two gestures
  double calculateDistance(List<Point> points1, List<Point> points2) {
    List<Point> norm1 = normalize(points1);
    List<Point> norm2 = normalize(points2);

    int length = math.min(norm1.length, norm2.length);
    double distance = 0.0;
    for (int i = 0; i < length; i++) {
      distance += math.sqrt(math.pow(norm1[i].x - norm2[i].x, 2) +
          math.pow(norm1[i].y - norm2[i].y, 2));
    }
    return distance / length; // Return average distance
  }

  // Normalize points (translate and scale)
  List<Point> normalize(List<Point> points) {
    if (points.isEmpty) return points;

    // Step 1: Find the bounding box
    double minX = points.map((p) => p.x).reduce(math.min);
    double maxX = points.map((p) => p.x).reduce(math.max);
    double minY = points.map((p) => p.y).reduce(math.min);
    double maxY = points.map((p) => p.y).reduce(math.max);

    double width = maxX - minX;
    double height = maxY - minY;

    // If width or height is zero, return normalized points at (0, 0)
    if (width == 0 || height == 0) return points.map((p) => Point(0, 0)).toList();

    return points.map((p) {
      double normalizedX = (p.x - minX) / width;
      double normalizedY = (p.y - minY) / height;
      return Point(normalizedX, normalizedY);
    }).toList();
  }

  // Method to open a new drawing screen
  void _openNewDrawingScreen() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => DrawingPage(),
    ));
  }

  // Gesture drawing and detection logic
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
            _points = [details.localPosition]; // Start accumulating points
          }
        },
        onPanUpdate: (details) {
          if (_canDraw) {
            setState(() {
              _points.add(details.localPosition); // Keep adding points
            });
          }
        },
        onPanEnd: (details) async {
          if (_canDraw) {
            // Only recognize if there are points drawn
            if (_points.isNotEmpty) {
              Gesture candidateGesture = Gesture(
                _points.map((offset) => Point(offset.dx, offset.dy)).toList(),
              );
              String gestureName = classifyGesture(candidateGesture);

              // Show a SnackBar with the recognized gesture name
              await ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: gestureName == "No match" ? Text(s) : Text('Recognized gesture: $gestureName'),
                  duration: Duration(milliseconds: 600),
                ),
              ).closed;

              if (gestureName == "plus") {
                s = 'Starting a new drawing!';
                _openNewDrawingScreen();
              }
              // Clear points after recognition
              setState(() {
                _points.clear(); // Clear points after recognition
                gestureName = '';
              });
            }
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