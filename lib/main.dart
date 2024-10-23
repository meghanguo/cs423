import 'dart:convert';
import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For loading assets
import 'package:painting_app_423/drawing_page.dart'; // Your custom DrawingPage
import 'package:painting_app_423/stroke.dart'; // Import the Stroke classes
import 'package:flutter_js/flutter_js.dart';
import 'package:painting_app_423/saved_drawings_page.dart';
import 'package:win32/win32.dart';

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
  final double X;
  final double Y;
  final int ID;

  Point(this.X, this.Y, this.ID);
  Map<String, dynamic> toJson() {
    return {
      'x': X,
      'y': Y,
      'ID': ID,
    };
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Point> _points = []; // Store the drawn points
  List<Map<String, dynamic>> savedDrawings = [];
  bool firstStroke = true;
  int strokeNum = 1;

  late JavascriptRuntime jsRuntime;
  String jsCode = ' ';

  @override
  void initState() {
    super.initState();
    loadJs();
    jsRuntime = getJavascriptRuntime();
  }

  Future<void> loadJs() async {
    jsCode = await rootBundle.loadString('assets/pdollar.js');
    jsRuntime.evaluate(jsCode);
    jsRuntime.evaluate('var recognizer = new PDollarRecognizer();');

    String fileContent = await rootBundle.loadString('assets/landing_page_gestures.txt');
    final result = jsRuntime.evaluate('recognizer.ProcessGesturesFile(`$fileContent`);');
  }

  void addDrawing(String name, List<Stroke> strokes) {
    bool exists = savedDrawings.any((drawing) => drawing['name'] == name);
    if (!exists) {
      setState(() {
        savedDrawings.add({
          'name': name,
          'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
        });
      });
    }
    else {
      savedDrawings.removeWhere((drawing) => drawing['name'] == name);
      setState(() {
        savedDrawings.add({
          'name': name,
          'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
        });
      });
    }
  }

  Future<void> _openNewDrawingScreen() async {
    final bool? confirmNewDrawing = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Start new drawing"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: Text("Yes"),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmNewDrawing == true) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DrawingPage(
            onSave: addDrawing,  // This function saves the strokes
            strokes: [], // Or pass existing strokes if editing
          ),
        ),
      );;
    }
  }

  String pDollarRecognizer(List<Point> points) {
    String pointsAsJson = jsonEncode(points);

    // Call the Recognize function and pass the points array
    final result = jsRuntime.evaluate('recognizer.Recognize($pointsAsJson);');
    print(result.stringResult);
    return result.stringResult;
  }

  Future<void> keepLastStroke() async{
    List<Point> pointsToRemove = [];

    for (var point in _points) {
      if (point.ID != strokeNum) {
        pointsToRemove.add(point);
      }
    }

    setState(() {
      _points.removeWhere((point) => pointsToRemove.contains(point));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          Text("hello"),
          // ListView.builder(
          //     itemCount: savedDrawings.length,
          //     itemBuilder: (context, index) {
          //       return ListTile(
          //         title: Text(savedDrawings[index]['name']),
          //         onTap: () {
          //           // Deserialize strokes from saved data
          //           List<Stroke> strokes = (savedDrawings[index]['strokes'] as List)
          //               .map((strokeData) => Stroke.fromJson(strokeData))
          //               .toList(); // Deserialize strokes
          //
          //           String drawingName = savedDrawings[index]['name'];
          //
          //           Navigator.of(context).push(
          //             MaterialPageRoute(
          //               builder: (context) => SavedDrawingPage(
          //                 strokes: strokes, // Pass deserialized strokes to the SavedDrawingPage
          //                 drawingName: drawingName,
          //               ),
          //             ),
          //           );
          //         },
          //
          //       );
          //     },
          //   ),
            GestureDetector(
              onPanStart: (details) {
                  _points.add(Point(details.localPosition.dx, details.localPosition.dy, strokeNum));
              },
              onPanUpdate: (details) {
                  setState(() {
                    _points.add(Point(details.localPosition.dx, details.localPosition.dy, strokeNum));
                  });
              },
              onPanEnd: (details) async {
                if (_points.isNotEmpty) {
                  // recognize for 2 stroke plus signs
                  if (!firstStroke) {
                    String gestureName = pDollarRecognizer(_points);
                    if (gestureName == "plus") {
                      print("in 2 stroke");
                      print("gesture name: " + gestureName);
                      _points.clear();
                      _openNewDrawingScreen();
                    }
                    else {
                      await keepLastStroke();
                    }
                  }

                  // recognize for 1 stroke plus signs
                  if (_points.isNotEmpty) {
                    String gestureName = pDollarRecognizer(_points);
                    if ( (gestureName == "plus" || gestureName == "s") & (gestureName != "line")) {
                      print("in one stroke");
                      print("gesture name: " + gestureName);
                      _points.clear();
                      _openNewDrawingScreen();
                    }
                  }

                  strokeNum += 1;
                  firstStroke = false;
                }
              },
            ),
        ],
      ),
    );
  }
}

class GesturePainter extends CustomPainter {
  final List<Point> points;

  GesturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(Offset(points[i].X, points[i].Y), Offset(points[i + 1].X, points[i + 1].Y), paint);
    }
  }

  @override
  bool shouldRepaint(GesturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
