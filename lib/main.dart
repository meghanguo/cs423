import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For loading assets
import 'dart:math' as math;
import 'dart:convert';
import 'package:painting_app_423/drawing_page.dart'; // Your custom DrawingPage
import 'package:painting_app_423/stroke.dart'; // Import the Stroke classes
import 'package:painting_app_423/pdollar_recognizer.dart';
import 'package:painting_app_423/saved_drawings_page.dart';


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

  factory Point.fromJson(Map<String, dynamic> json) {
    return Point(json['x'], json['y']);
  }

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
  };
}

class Gesture {
  final List<Point> points;
  final String name;

  Gesture(this.points, {this.name = ""});

  factory Gesture.fromJson(Map<String, dynamic> json) {
    List<Point> points = (json['points'] as List)
        .map((p) => Point.fromJson(p))
        .toList();
    return Gesture(points, name: json['name']);
  }

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
  List<Gesture> gestureTemplates = [];
  List<Offset> _points = []; // Store the drawn points
  bool _canDraw = true; // Control to allow redrawing
  List<Map<String, dynamic>> savedDrawings = [];

  @override
  void initState() {
    super.initState();
    loadGestureTemplates(); // Load templates when the app starts
  }

  void addDrawing(String name, List<Stroke> strokes) {
    setState(() {
      savedDrawings.add({
        'name': name,
        'strokes': strokes,
      });
    });
  }

  Future<void> loadGestureTemplates() async {
    try {
      List<String> gestureFiles = [
        'assets/gestures/plus.json',
      ];

      for (String file in gestureFiles) {
        String jsonString = await rootBundle.loadString(file);
        Map<String, dynamic> templateData = jsonDecode(jsonString);
        String gestureName = templateData['name'];
        List<Point> points = (templateData['points'] as List)
            .map((p) => Point(p['x'], p['y']))
            .toList();

        Gesture gesture = Gesture(points, name: gestureName);
        setState(() {
          gestureTemplates.add(gesture);
        });
      }

      print("Loaded gestures: $gestureTemplates");
    } catch (e) {
      print("Error loading gesture templates: $e");
    }
  }

  String classifyGesture(Gesture candidate) {
    double minDistance = double.infinity;
    String recognizedGestureName = "No match";

    for (Gesture template in gestureTemplates) {
      double distance = calculateDistance(candidate.points, template.points);
      if (distance < minDistance) {
        minDistance = distance;
        recognizedGestureName = template.name;
      }
    }
    return recognizedGestureName;
  }

  double calculateDistance(List<Point> points1, List<Point> points2) {
    List<Point> norm1 = normalize(points1);
    List<Point> norm2 = normalize(points2);

    int length = math.min(norm1.length, norm2.length);
    double distance = 0.0;
    for (int i = 0; i < length; i++) {
      distance += math.sqrt(math.pow(norm1[i].x - norm2[i].x, 2) +
          math.pow(norm1[i].y - norm2[i].y, 2));
    }
    return distance / length;
  }

  List<Point> normalize(List<Point> points) {
    if (points.isEmpty) return points;

    double minX = points.map((p) => p.x).reduce(math.min);
    double maxX = points.map((p) => p.x).reduce(math.max);
    double minY = points.map((p) => p.y).reduce(math.min);
    double maxY = points.map((p) => p.y).reduce(math.max);

    double width = maxX - minX;
    double height = maxY - minY;

    if (width == 0 || height == 0) return points.map((p) => Point(0, 0)).toList();

    return points.map((p) {
      double normalizedX = (p.x - minX) / width;
      double normalizedY = (p.y - minY) / height;
      return Point(normalizedX, normalizedY);
    }).toList();
  }

  void _openNewDrawingScreen() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => DrawingPage(onSave: addDrawing)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: ListView.builder(
              itemCount: savedDrawings.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(savedDrawings[index]['name']),
                  onTap: () {
                    List<Stroke> strokes = savedDrawings[index]['strokes'];
                    String drawingName = savedDrawings[index]['name'];

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DrawingPage(
                          onSave: addDrawing,
                          strokes: strokes, // Pass saved strokes to the DrawingPage
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: GestureDetector(
              onPanStart: (details) {
                if (_canDraw) {
                  _points = [details.localPosition];
                }
              },
              onPanUpdate: (details) {
                if (_canDraw) {
                  setState(() {
                    _points.add(details.localPosition);
                  });
                }
              },
              onPanEnd: (details) async {
                if (_canDraw && _points.isNotEmpty) {
                  Gesture candidateGesture = Gesture(
                    _points.map((offset) => Point(offset.dx, offset.dy)).toList(),
                  );
                  String gestureName = classifyGesture(candidateGesture);

                  await ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        gestureName == "plus"
                            ? 'Starting a new drawing!'
                            : 'Recognized gesture: $gestureName',
                      ),
                      duration: Duration(milliseconds: 600),
                    ),
                  ).closed;

                  if (gestureName == "plus") {
                    _openNewDrawingScreen();
                  }

                  setState(() {
                    _points.clear();
                  });
                }
              },
              child: Container(
                color: Colors.grey[200],
                child: Stack(
                  children: [
                    CustomPaint(
                      painter: GesturePainter(points: _points),
                      child: Center(
                        child: Text(
                          'Draw plus sign here to start new drawing',
                          style: TextStyle(color: Colors.black38),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  bool shouldRepaint(GesturePainter oldDelgate) {
    return oldDelgate.points != points;
  }
}
