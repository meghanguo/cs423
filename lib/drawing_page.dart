import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:painting_app_423/stroke.dart';

import 'canvas_side_bar.dart';
import 'current_stroke_value_notifier.dart';
import 'drawing_canvas.dart';
import 'drawing_canvas_options.dart';
import 'drawing_tool.dart';
import 'package:flutter/services.dart'; // For loading assets
import 'dart:convert';
import 'dart:math' as math;

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

class DrawingPage extends StatefulWidget {
  final Function(String, List<Stroke>) onSave;
  final List<Stroke>? strokes; // Accept saved strokes

  const DrawingPage({super.key, required this.onSave, this.strokes});

  @override
  _DrawingPageState createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController animationController;
  final ValueNotifier<Color> selectedColor = ValueNotifier(Colors.black);
  final ValueNotifier<double> strokeSize = ValueNotifier(10.0);
  final ValueNotifier<double> eraserSize = ValueNotifier(30.0);
  final ValueNotifier<DrawingTool> drawingTool = ValueNotifier(DrawingTool.pencil);
  final GlobalKey canvasGlobalKey = GlobalKey();
  final ValueNotifier<ui.Image?> backgroundImage = ValueNotifier(null);
  final CurrentStrokeValueNotifier currentStroke = CurrentStrokeValueNotifier();
  final ValueNotifier<List<Stroke>> allStrokes = ValueNotifier([]);

  bool _isLocked = false;
  bool _canDraw = false;

  List<Gesture> gestureTemplates = [];
  List<Offset> _points = []; // Store the drawn points for gesture recognition

  List<Stroke> strokes = [];
  String recognizedGesture = '';
  List<Offset?> _currentStroke = [];

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    loadGestureTemplates();
    _canDraw = true;
    if (widget.strokes != null) {
      strokes = widget.strokes!;
    }
  }

  // Load saved gesture templates from assets/gestures
  Future<void> loadGestureTemplates() async {
    try {
      // Get a list of JSON files in the assets gestures directory
      List<String> gestureFiles = [
        'assets/gestures/check.json', // Make sure this file exists
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

  void onPanUpdate(DragUpdateDetails details) {
    if (_canDraw) {
      RenderBox renderBox = context.findRenderObject() as RenderBox;
      Offset point = renderBox.globalToLocal(details.globalPosition);
      setState(() {
        _points.add(point);
      });
    }
  }

  void onPanEnd(DragEndDetails details) {
    if (_isLocked) {
      recognizeGesture();
      _points.clear(); // Clear points after recognition
    }
  }

  void recognizeGesture() {
    // Normalize points for recognition
    List<Point> normalizedPoints = _points
        .map((offset) => Point(offset.dx, offset.dy))
        .toList();

    // Create a candidate gesture
    Gesture candidateGesture = Gesture(normalizedPoints);

    // Classify the gesture
    String gestureName = classifyGesture(candidateGesture);
    if (gestureName == 'check') {
      // showSnackBar();
      showSaveDialog();
    }
  }

  void showSnackBar() {
    final snackBar = SnackBar(content: Text('Check mark recognized!'));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _drawingMode() {
    setState(() {
      _canDraw = !_canDraw;
      _isLocked = !_isLocked;

      // Show message based on the current mode
      final snackBar = SnackBar(
        content: Text(_canDraw ? 'Drawing Mode On' : 'No Drawing Mode On'),
        duration: Duration(seconds: 2),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    });
  }



  // Method to show save prompt
  Future<void> showSaveDialog() async {
    final nameController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Drawing'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Enter drawing name'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  widget.onSave(nameController.text, strokes);
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Return to main page
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      drawer: Drawer(
        child: _canDraw
            ? CanvasSideBar(
          drawingTool: drawingTool,
          selectedColor: selectedColor,
          strokeSize: strokeSize,
          eraserSize: eraserSize,
          currentSketch: currentStroke,
          allSketches: allStrokes,
          canvasGlobalKey: canvasGlobalKey,
        )
            : null, // Disable drawer interaction when locked
      ),
      backgroundColor: Color(0xfff2f3f7),
      body: GestureDetector(
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([
                currentStroke,
                allStrokes,
                selectedColor,
                strokeSize,
                eraserSize,
                drawingTool,
                backgroundImage,
              ]),
              builder: (context, _) {
                return DrawingCanvas(
                  options: DrawingCanvasOptions(
                    currentTool: drawingTool.value,
                    size: strokeSize.value,
                    strokeColor: selectedColor.value,
                    backgroundColor: Color(0xfff2f3f7),
                  ),
                  canvasKey: canvasGlobalKey,
                  currentStrokeListenable: currentStroke,
                  strokesListenable: allStrokes,
                  backgroundImageListenable: backgroundImage,
                  canDraw: _canDraw, // Pass canDraw flag here
                );
              },
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: _drawingMode,
                child: Icon(_isLocked ? Icons.lock : Icons.lock_open),
              ),
            ),
          ],
        ),
      ),
    );
  }
}