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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Point) return false;
    return X == other.X && Y == other.Y && ID == other.ID;
  }

  @override
  int get hashCode => X.hashCode ^ Y.hashCode ^ ID.hashCode;
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  List<Point> _points = []; // Store the drawn points
  List<Map<String, dynamic>> savedDrawings = []; // Store the saved drawings
  // bool firstStroke = true;  // old
  // new
  bool firstStroke = false;
  List<Point> _firstStroke = [];
  List<Point> _secondStroke = [];
  late final AnimationController _plusAnimationController;
  bool showPlusHint = true;

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
    _plusAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: false);
    _loadHintState();
  }

  @override
  void dispose() {
    _plusAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadHintState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      showPlusHint = prefs.getBool('showPlusHint') ?? true;
    });
  }

  Future<void> _saveHintState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showPlusHint', showPlusHint);
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
      setState(() {
      showPlusHint = false;
      });
      _saveHintState();
      
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

        showDialog(context: context, builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Favorite / Unfavorite ${drawing['name']}?'),
            actions: [
              TextButton(
                onPressed: () {
                  toggleFavorite(drawing['name']);
                  Navigator.of(context).pop();
                },
                child: Text('Yes'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog without any action
                },
                child: Text('No'),
              ),
            ],
          );
        });
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

  List<Point> interpolate(Point start, Point end, int steps) {
    List<Point> interpolatedPoints = [];
    double dxIncrement = (end.X - start.X) / steps;
    double dyIncrement = (end.Y - start.Y) / steps;

    for (int i = 0; i <= steps; i++) {
      double newX = (start.X + dxIncrement * i).roundToDouble();
      double newY = (start.Y + dyIncrement * i).roundToDouble();
      Point newPoint = Point(newX, newY, strokeNum);
      if (!_points.contains(newPoint) && !interpolatedPoints.contains(newPoint)) {
        interpolatedPoints.add(newPoint);
      }
    }
    return interpolatedPoints;
  }

  @override
  Widget build(BuildContext context) {
    List<List<Map<String, dynamic>>> pages = _getPages(savedDrawings);
    Orientation orientation = MediaQuery.of(context).orientation;
    int columns = orientation == Orientation.portrait ? 2 : 3;
    getDrawingPositions();

    if (currentPageIndex < 0 || currentPageIndex >= pages.length) {
      currentPageIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(Icons.info),
            onPressed: (){
              showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text ('Help'),
                      content: Text('Info here')
                    );
                  }
              );
            },
          )
        ],
      ),
      body: Stack(children: [
        GestureDetector(
            onPanStart: (details) {
              _points.add(Point(details.localPosition.dx,
                  details.localPosition.dy, strokeNum));
            },
            onPanUpdate: (details) {
              setState(() {
                Point lastPoint = _points.last;

                List<Point> interpolatedPoints = interpolate(lastPoint,
                    Point(details.localPosition.dx, details.localPosition.dy, strokeNum),
                    5);

                _points.addAll(interpolatedPoints);
              });
            },
            // Try to recognize plus for new drawing
            //old Pan end
            // onPanEnd: (details) async {
            //   // for (var point in _points) {
            //   //   debugPrint('${point.X.round().toString()},${point.Y.round().toString()}');
            //   // }
            //   // _points.clear();
            //   if (_points.isNotEmpty) {
            //     // recognize for 2 stroke plus signs
            //     if (!firstStroke) {
            //       String gestureName = pDollarRecognizer(_points);
            //       if (gestureName == "plus") {
            //         // print("in 2 stroke");
            //         // print("gesture name: " + gestureName);
            //         _points.clear();
            //         _openNewDrawingScreen();
            //       } else {
            //         await keepLastStroke();
            //       }
            //     }
            //
            //     // recognize for 1 stroke plus signs
            //     if (_points.isNotEmpty) {
            //       String gestureName = pDollarRecognizer(_points);
            //       if (gestureName == "plus") {
            //         // print("in one stroke");
            //         // print("gesture name: " + gestureName);
            //         _points.clear();
            //         _openNewDrawingScreen();
            //       }
            //       else if (gestureName == "star") { // Try to recognize star for favoriting
            //         // print("in one stroke");
            //         // print("gesture name: " + gestureName);
            //
            //         double beginX = _points.first.X;
            //         double beginY = _points.first.Y;
            //
            //         List<Map<String, dynamic>> drawingPositions =
            //             getDrawingPositions();
            //
            //         // Add drawing to favorite if gesture ends on that drawing
            //         if (!favoriteDrawingThruGesture(
            //             beginX, beginY, drawingPositions)) {
            //           await showDialog(
            //             context: context,
            //             builder: (BuildContext context) {
            //               return AlertDialog(
            //                 title: Text("Error"),
            //                 actions: <Widget>[
            //                   TextButton(
            //                     child: Text("No drawing favorited"),
            //                     onPressed: () {
            //                       Navigator.of(context).pop();
            //                     },
            //                   )
            //                 ],
            //               );
            //             },
            //           );
            //         }
            //         _points.clear();
            //         print(_points.length);
            //       }
            //     }
            //     firstStroke = false;
            //   }
            //   strokeNum += 1;
            // },

            //new Pan end
            onPanEnd: (details) async {
              // for (var point in _points) {
              //   debugPrint('${point.X.round().toString()},${point.Y.round().toString()}');
              // }
              // _points.clear();
              if (_points.isNotEmpty) {
                if (!firstStroke) {
                  String gestureName = pDollarRecognizer(_points);
                  print("Detected gesture for first stroke: $gestureName");

                  if (gestureName == "verticalLine") {
                    _firstStroke = List.from(_points); // Save first stroke
                    _points.clear(); // Clear points for next stroke
                    firstStroke = true; // Mark that the first stroke is complete
                  } else {
                    // If it's not a vertical line, handle as a single-stroke gesture or other gesture
                    await keepLastStroke();
                  }
                }

                // Part 2: Process the second stroke for 2-stroke plus (expecting horizontal line)
                else if (firstStroke) {
                  String gestureName = pDollarRecognizer(_points);
                  print("Detected gesture for second stroke: $gestureName");

                  if (gestureName == "horizontalLine") {
                    _secondStroke = List.from(_points); // Save second stroke
                    _points.clear();
                    firstStroke = false; // Reset for next gesture

                    // Combine both strokes and check for "plus"
                    String combinedGestureName = pDollarRecognizer([..._firstStroke, ..._secondStroke]);
                    print("Combined gesture detected as: $combinedGestureName");
                    if (combinedGestureName == "plus") {
                      _openNewDrawingScreen();
                    }
                  } else {
                    // If not recognized as horizontal, reset and keep last stroke
                    await keepLastStroke();
                    firstStroke = false;
                  }
                }

                // Part 3: Recognize one-stroke plus sign only if first stroke hasn't started
                if (!firstStroke && _points.isNotEmpty) {
                  String gestureName = pDollarRecognizer(_points);
                  print("Detected single-stroke gesture: $gestureName");

                  if (gestureName == "plus") {
                    _points.clear();
                    print("One-stroke plus recognized");
                    _openNewDrawingScreen();
                  } else if (gestureName == "star") { // Star gesture for favoriting
                    double beginX = _points.first.X;
                    double beginY = _points.first.Y;

                    List<Map<String, dynamic>> drawingPositions = getDrawingPositions();

                    // Add drawing to favorite if gesture ends on that drawing
                    if (!favoriteDrawingThruGesture(beginX, beginY, drawingPositions)) {
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
                    print("Points cleared after star gesture: ${_points.length}");
                  }
                }
              }
              strokeNum += 1;
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
                    itemCount: pages.length == 0 ? 0 : pages[currentPageIndex].length,
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
                              leading: Icon(
                                  drawing['favorite']
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: drawing['favorite']
                                      ? Colors.yellow
                                      : Colors.grey,
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
        if (savedDrawings.isEmpty && showPlusHint)
          Positioned.fill(
            child: CustomPaint(
              painter: PlusSignAnimationPainter(
                animation: _plusAnimationController,
              ),
            ),
          ),
      ]),
    );
  }
}


class PlusSignAnimationPainter extends CustomPainter {
  final Animation<double> animation;

  PlusSignAnimationPainter({required this.animation}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final progress = animation.value;

    // Draw vertical line
    if (progress <= 0.5) {
      canvas.drawLine(
        center.translate(0, -50 * progress * 2),
        center.translate(0, 50 * progress * 2),
        paint,
      );
    } else {
      canvas.drawLine(
        center.translate(0, -50),
        center.translate(0, 50),
        paint,
      );
      // Draw horizontal line
      final horizontalProgress = (progress - 0.5) * 2;
      canvas.drawLine(
        center.translate(-50 * horizontalProgress, 0),
        center.translate(50 * horizontalProgress, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
