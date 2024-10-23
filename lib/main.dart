import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For loading assets
import 'package:painting_app_423/drawing_page.dart'; // Your custom DrawingPage
import 'package:painting_app_423/stroke.dart'; // Import the Stroke classes
import 'package:flutter_js/flutter_js.dart';
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

class Gesture {
  final List<Point> points;
  final String name;

  Gesture(this.points, {this.name = ""});
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Gesture> gestureTemplates = [];
  List<Point> _points = []; // Store the drawn points
  bool _canDraw = true; // Control to allow redrawing
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
    // print('Result from JS after processing file: ${result.stringResult}');
  }

  void addDrawing(String name, List<Stroke> strokes) {
    setState(() {
      savedDrawings.add({
        'name': name,
        'strokes': strokes,
      });
    });
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
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => DrawingPage(onSave: addDrawing)),
      );
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
          // ListView.builder(
          //     itemCount: savedDrawings.length,
          //     itemBuilder: (context, index) {
          //       return ListTile(
          //         title: Text(savedDrawings[index]['name']),
          //         onTap: () {
          //           List<Stroke> strokes = savedDrawings[index]['strokes'];
          //           String drawingName = savedDrawings[index]['name'];
          //           Navigator.of(context).push(
          //             MaterialPageRoute(
          //               builder: (context) => DrawingPage(
          //                 onSave: addDrawing,
          //                 strokes: strokes, // Pass saved strokes to the DrawingPage
          //               ),
          //             ),
          //           );
          //         },
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
                    if (gestureName == "plus" || gestureName == "s") {
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
