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
import 'package:shared_preferences/shared_preferences.dart';

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

// Store individual point in this class
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
  List<Map<String, dynamic>> savedDrawings = []; // Store the saved drawings
  bool firstStroke = true;
  int strokeNum = 1;

  // Setup to read JS code
  late JavascriptRuntime jsRuntime;
  String jsCode = ' ';
  bool isLoading = true;

  // Setup for displaying images on home page
  int drawingsPerPage = 6;
  int currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    loadJs();
    jsRuntime = getJavascriptRuntime();
    _loadDrawings();
  }

  // load JS code to be called from Flutter
  Future<void> loadJs() async {
    jsCode = await rootBundle.loadString('assets/pdollar.js');
    jsRuntime.evaluate(jsCode);
    jsRuntime.evaluate('var recognizer = new PDollarRecognizer();');

    String fileContent =
        await rootBundle.loadString('assets/landing_page_gestures.txt');
    final result =
        jsRuntime.evaluate('recognizer.ProcessGesturesFile(`$fileContent`);');
  }

  // Recognizer
  String pDollarRecognizer(List<Point> points) {
    String pointsAsJson = jsonEncode(points);

    // Call the Recognize function and pass the points array
    final result = jsRuntime.evaluate('recognizer.Recognize($pointsAsJson);');
    print(result.stringResult);
    return result.stringResult;
  }

  // Add new and updated drawings to ds
  void addDrawing(String name, List<Stroke> strokes) {
    setState(() {
      // Check if the drawing already exists
      int existingIndex =
          savedDrawings.indexWhere((drawing) => drawing['name'] == name);

      if (existingIndex != -1) {
        bool isFavorite = savedDrawings[existingIndex]['favorite'];
        savedDrawings[existingIndex] = {
          'name': name,
          'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
          'favorite': isFavorite, // Preserve favorite status
        };
      } else {
        // Add new drawing with default favorite status
        savedDrawings.add({
          'name': name,
          'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
          'favorite': false, // Default favorite status for new drawings
        });
      }
    });
  }

  // Open new screen with canvas so user can start new drawing - Feedback loop requires user to confirm to start new drawing
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
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DrawingPage(
            onSave: addDrawing, // This function saves the strokes
            strokes: [], // Or pass existing strokes if editing
          ),
        ),
      );
      _loadDrawings();
    }
  }

  // Remove last stroke if there are 2 strokes stored and there's no match- we are only looking at single or 2 stroke matches right now
  Future<void> keepLastStroke() async {
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

  // Load images of drawings that user previously saved to device
  Future<void> _loadDrawings() async {
    final directory = await getApplicationDocumentsDirectory();
    final drawings = await directory.list().toList();

    List<Map<String, dynamic>> loadedDrawings = [];
    SharedPreferences preferences = await SharedPreferences.getInstance();

    for (var drawing in drawings) {
      if (drawing is File && (drawing.path.endsWith('png'))) {
        String imageName = drawing.uri.pathSegments.last;
        bool favorite = preferences.getBool(imageName) ?? false;
        loadedDrawings.add({
          'name': imageName,
          'path': drawing.path,
          'favorite': favorite,
        });
      }

      loadedDrawings.sort(
          (a, b) => (b['favorite'] ? 1 : 0).compareTo(a['favorite'] ? 1 : 0));
      setState(() {
        savedDrawings = loadedDrawings;
      });
    }
  }

  // Load strokes of saved drawing and allow user to edit the drawing
  Future<List<Stroke>> _loadStrokesFromFile(String path) async {
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          Future.delayed(const Duration(milliseconds: 500), () {
            Navigator.of(context).pop();
          });
          return AlertDialog(
            title: Text("Opening drawing"),
            content: Text("Please wait..."),
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

  // Make user confirm to delete a drawing
  Future<void> _confirmDeleteDrawing(String path, String name) async {
    final bool? confirm = await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Delete Drawing"),
            content: Text("Delete '$name'"),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text("Cancel")),
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: Text("Delete"))
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
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text("Ok")),
          ],
        );
      }
    }
  }

  // Allow users to add to favorites via an icon toggle
  void toggleFavorite(String name) {
    setState(() {
      final drawing =
          savedDrawings.firstWhere((drawing) => drawing['name'] == name);
      drawing['favorite'] = !drawing['favorite'];

      SharedPreferences.getInstance().then((preferences) {
        preferences.setBool(name, drawing['favorite']);
      });

      savedDrawings.sort(
          (a, b) => (b['favorite'] ? 1 : 0).compareTo(a['favorite'] ? 1 : 0));
    });
  }

  // Also allow users to favorite a drawing through gesture
  bool favoriteDrawingThruGesture(
      double x, double y, List<Map<String, dynamic>> drawings) {
    for (var drawing in drawings) {
      double drawingX = drawing['x'];
      double drawingY = drawing['y'];
      double drawingWidth = drawing['width'];
      double drawingHeight = drawing['height'];

      if (x >= drawingX &&
          x <= drawingX + drawingWidth &&
          y >= drawingY &&
          y <= drawingY + drawingHeight) {
        toggleFavorite(drawing['name']); // Toggle the favorite status
        return true;
      }
    }
    return false;
  }

  // Layout of drawings on home page
  List<Map<String, dynamic>> getDrawingPositions() {
    Orientation orientation = MediaQuery.of(context).orientation;
    int columns = orientation == Orientation.portrait ? 2 : 3;
    List<Map<String, dynamic>> drawingPositions = [];

    double tileWidth = 0;
    double tileHeight = 0;

    tileWidth =
        MediaQuery.of(context).size.width / columns; // Width of each tile
    tileHeight = tileWidth;

    for (int index = 0; index < savedDrawings.length; index++) {
      double drawingX = (index % columns) * tileWidth;
      double drawingY = (index ~/ columns) * tileHeight;

      drawingPositions.add({
        'name': savedDrawings[index]['name'],
        'x': drawingX,
        'y': drawingY,
        'width': tileWidth,
        'height': tileHeight,
        'path': savedDrawings[index]['path'],
      });
    }
    return drawingPositions;
  }

  // Spread drawings out on multiple pages if >6 drawings
  List<List<Map<String, dynamic>>> _getPages(
      List<Map<String, dynamic>> drawings) {
    List<List<Map<String, dynamic>>> pages = [];
    for (int i = 0; i < drawings.length; i += drawingsPerPage) {
      pages.add(drawings.sublist(
          i,
          i + drawingsPerPage > drawings.length
              ? drawings.length
              : i + drawingsPerPage));
    }
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    List<List<Map<String, dynamic>>> pages = _getPages(savedDrawings);
    Orientation orientation = MediaQuery.of(context).orientation;
    int columns = orientation == Orientation.portrait ? 2 : 3;
    getDrawingPositions();

    if (pages.isEmpty) {
      return Container(
        color: Colors.white,
      );
    }

    if (currentPageIndex < 0 || currentPageIndex >= pages.length) {
      currentPageIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Stack(children: [
        GestureDetector(
            onPanStart: (details) {
              _points.add(Point(details.localPosition.dx,
                  details.localPosition.dy, strokeNum));
            },
            onPanUpdate: (details) {
              setState(() {
                _points.add(Point(details.localPosition.dx,
                    details.localPosition.dy, strokeNum));
              });
            },
            // Try to recognize plus for new drawing
            onPanEnd: (details) async {
              if (_points.isNotEmpty) {
                // recognize for 2 stroke plus signs
                if (!firstStroke) {
                  String gestureName = pDollarRecognizer(_points);
                  if (gestureName == "plus") {
                    // print("in 2 stroke");
                    // print("gesture name: " + gestureName);
                    _points.clear();
                    _openNewDrawingScreen();
                  } else {
                    await keepLastStroke();
                  }
                }

                // recognize for 1 stroke plus signs
                if (_points.isNotEmpty) {
                  String gestureName = pDollarRecognizer(_points);
                  if (gestureName == "plus") {
                    // print("in one stroke");
                    // print("gesture name: " + gestureName);
                    _points.clear();
                    _openNewDrawingScreen();
                  }
                  else if (gestureName == "star" || gestureName == "heart") { // Try to recognize star or heart for favoriting
                    // print("in one stroke");
                    // print("gesture name: " + gestureName);

                    double endX = _points.last.X;
                    double endY = _points.last.Y;

                    List<Map<String, dynamic>> drawingPositions =
                        getDrawingPositions();

                    // Add drawing to favorite if gesture ends on that drawing
                    if (!favoriteDrawingThruGesture(
                        endX, endY, drawingPositions)) {
                      await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text("Error"),
                            actions: <Widget>[
                              TextButton(
                                child: Text("No drawing favorited"),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              )
                            ],
                          );
                        },
                      );
                    }

                    _points.clear();
                  }
                }

                strokeNum += 1;
                firstStroke = false;
              }
            },
            // Widget tree
            child: Column(children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: GridView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: 1,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: pages[currentPageIndex].length,
                    itemBuilder: (context, index) {
                      final drawing = pages[currentPageIndex][index];

                      return GestureDetector(
                          onTap: () async {
                            List<Stroke> strokes =
                                await _loadStrokesFromFile(drawing['path']);

                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DrawingPage(
                                  onSave: addDrawing,
                                  strokes: strokes,
                                  existingDrawingName: drawing['name'],
                                ),
                              ),
                            );
                            _loadDrawings();
                          },
                          child: GridTile(
                            child: Image.file(
                              File(drawing['path']),
                              fit: BoxFit.cover,
                            ),
                            footer: GridTileBar(
                              backgroundColor: Colors.white,
                              title: Text(
                                drawing['name'],
                                style: TextStyle(color: Colors.black),
                                textAlign: TextAlign.center,
                              ),
                              leading: IconButton(
                                onPressed: () =>
                                    toggleFavorite(drawing['name']),
                                icon: Icon(
                                  drawing['favorite']
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: drawing['favorite']
                                      ? Colors.yellow
                                      : Colors.grey,
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  _confirmDeleteDrawing(
                                      drawing['path'], drawing['name']);
                                },
                              ),
                            ),
                          ));
                    },
                  ),
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Padding(
                  padding: const EdgeInsets.only(
                      left: 10.0, right: 10.0, bottom: 30.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                          onPressed: currentPageIndex > 0
                              ? () {
                                  setState(() {
                                    currentPageIndex--;
                                  });
                                }
                              : null,
                          child: Text('Previous')),
                      Text('Page ${currentPageIndex + 1} of ${pages.length}'),
                      ElevatedButton(
                        onPressed: currentPageIndex < pages.length - 1
                            ? () {
                                setState(() {
                                  currentPageIndex++;
                                });
                              }
                            : null,
                        child: Text('Next'),
                      )
                    ],
                  ))
            ])),
      ]),
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
      canvas.drawLine(Offset(points[i].X, points[i].Y),
          Offset(points[i + 1].X, points[i + 1].Y), paint);
    }
  }

  @override
  bool shouldRepaint(GesturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
