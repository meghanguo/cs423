import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For loading assets
import 'package:painting_app_423/drawing_page.dart'; // Your custom DrawingPage
import 'package:painting_app_423/stroke.dart'; // Import the Stroke classes
import 'package:flutter_js/flutter_js.dart';

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
      'y': X,
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

    String fileContent = await rootBundle.loadString('assets/gestures.txt');
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

  void _openNewDrawingScreen() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => DrawingPage(onSave: addDrawing)),
    );
  }

  String pDollarRecognizer(List<Point> points) {
    // List<Map<String, dynamic>> pointsJs = points.map((point) => point.toJson()).toList();

    // Define an array of points in JavaScript to pass to the Recognize function
    final jsPointsArray = '''
      [
        { "X": 30, "Y": 7, "ID": 1 },
        { "X": 103, "Y": 7, "ID": 1 },
        { "X": 66, "Y": 7, "ID": 2 },
        { "X": 66, "Y": 87, "ID": 2 }
      ]
    ''';

    // Call the Recognize function and pass the points array
    final result = jsRuntime.evaluate('recognizer.Recognize($jsPointsArray);');

    // Process the result (assumes result is a JSON-like structure)
    // print('Result from JS (PointCloud): ${result.stringResult}');

    return "";
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
          // ElevatedButton(
          //   onPressed: runCustomJsFunction,
          //   child: Text('Run Custom JS Function'),
          // ),
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
                  _points.add(Point(details.localPosition.dx, details.localPosition.dy, 0));
                  // _points = [details.localPosition];
                }
              },
              onPanUpdate: (details) {
                if (_canDraw) {
                  setState(() {
                    _points.add(Point(details.localPosition.dx, details.localPosition.dy, 0));
                  });
                }
              },
              onPanEnd: (details) async {
                if (_canDraw && _points.isNotEmpty) {
                  // for (int i = 0; i < _points.length - 1; i++) {
                  //   print("${_points[i].X}, ${_points[i].Y}");
                  // }
                  String gestureName = pDollarRecognizer(_points);


                  // await ScaffoldMessenger.of(context).showSnackBar(
                  //   SnackBar(
                  //     content: Text(
                  //       gestureName == "plus"
                  //           ? 'Starting a new drawing!'
                  //           : 'Recognized gesture: $gestureName',
                  //     ),
                  //     duration: Duration(milliseconds: 600),
                  //   ),
                  // ).closed;
                  //
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
