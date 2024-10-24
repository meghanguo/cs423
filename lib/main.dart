import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:painting_app_423/drawing_page.dart';
import 'package:painting_app_423/stroke.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
    _loadDrawings();
  }

  Future<void> loadJs() async {
    jsCode = await rootBundle.loadString('assets/pdollar.js');
    jsRuntime.evaluate(jsCode);
    jsRuntime.evaluate('var recognizer = new PDollarRecognizer();');

    String fileContent = await rootBundle.loadString('assets/landing_page_gestures.txt');
    final result = jsRuntime.evaluate('recognizer.ProcessGesturesFile(`$fileContent`);');
  }

  String pDollarRecognizer(List<Point> points) {
    String pointsAsJson = jsonEncode(points);

    // Call the Recognize function and pass the points array
    final result = jsRuntime.evaluate('recognizer.Recognize($pointsAsJson);');
    print(result.stringResult);
    return result.stringResult;
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
      await Navigator.push(context,
        MaterialPageRoute(
          builder: (context) => DrawingPage(
            onSave: addDrawing,  // This function saves the strokes
            strokes: [], // Or pass existing strokes if editing
          ),
        ),
      );
      _loadDrawings();
    }
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

  Future<void> _loadDrawings() async {
    final directory = await getApplicationDocumentsDirectory();
    final drawings = await directory.list().toList();

    List<Map<String, dynamic>> loadedDrawings = [];

    for (var drawing in drawings) {
      if (drawing is File && (drawing.path.endsWith('png'))) {
        loadedDrawings.add({
          'name': drawing.uri.pathSegments.last,
          'path': drawing.path,
        });
      }
      setState(() {savedDrawings = loadedDrawings;});
    }
  }

  // load saved drawing and allow user to edit these drawings
  Future<List<Stroke>> _loadStrokesFromFile(String path) async {
    await showDialog(context: context,
        builder: (BuildContext context){
      return AlertDialog(
        title: Text("Opening drawing"),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("OK"),
          )
        ],
      );
        });
    String fileName = p.basenameWithoutExtension(path);
    final drawing = File(p.join(p.dirname(path), '$fileName.json'));
    if (await drawing.exists()) {
      final content = await drawing.readAsString();
      final List<dynamic> strokeJson = jsonDecode(content);
      return strokeJson.map((json) => Stroke.fromJson(json)).toList();
    }
    return [];
  }

  Future<void> _confirmDeleteDrawing(String path, String name) async{
    final bool? confirm = await showDialog(context: context, builder: (BuildContext context) {
      return AlertDialog(
        title: Text("Delete Drawing"),
        content: Text("Delete '$name'"),
        actions: <Widget>[
          TextButton(onPressed: () {Navigator.of(context).pop(false);}, child: Text("Cancel")),
          TextButton(onPressed: () {Navigator.of(context).pop(true);}, child: Text("Delete"))
        ],
      );
    });

    if (confirm == true) {
      try {
        final image = File(path);
        if (await image.exists()) {
          await image.delete();
          final shortName = name.replaceAll(".png", "");
          final directory = await getApplicationDocumentsDirectory();
          final jsonFile = File('${directory.path}/${shortName}.json');
          if (await jsonFile.exists()) {
            await jsonFile.delete();
          }
          _loadDrawings();
        }
      } catch (e) {
        AlertDialog(
          title: Text("Error"),
          content: Text("Image couldn't be deleted"),
          actions: <Widget>[
            TextButton(onPressed: () {Navigator.of(context).pop();}, child: Text("Ok")),
          ],
        );
      }
    }
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
          GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1, crossAxisSpacing: 4, mainAxisSpacing: 4,),
            itemCount: savedDrawings.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () async {
                  List<Stroke> strokes = await _loadStrokesFromFile(savedDrawings[index]['path']);

                  await Navigator.push(context,
                    MaterialPageRoute(builder: (context) => DrawingPage(
                      onSave: addDrawing,
                      strokes: strokes,
                      existingDrawingName: savedDrawings[index]['name'],
                    ),
                    ),
                  );
                  _loadDrawings();
                },
              child:
                GridTile(
                child: Image.file(
                  File(savedDrawings[index]['path']),
                  fit: BoxFit.cover,
                ),
                footer: GridTileBar(
                  backgroundColor: Colors.white,
                  title: Text(
                    savedDrawings[index]['name'],
                    style: TextStyle(color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  trailing: IconButton(
                    icon:Icon(Icons.delete, color: Colors.red,),
                    onPressed: () async {_confirmDeleteDrawing(savedDrawings[index]['path'], savedDrawings[index]['name']);},
                  ),
                ),
              ));
            },
          ),
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
