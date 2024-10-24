import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:painting_app_423/stroke.dart';

import 'current_stroke_value_notifier.dart';
import 'drawing_canvas.dart';
import 'drawing_canvas_options.dart';
import 'drawing_tool.dart';
import 'package:flutter/services.dart'; // For loading assets
import 'dart:convert';
import 'color_palette.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';


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

class _IconBox extends StatelessWidget {
  final IconData iconData;
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;

  const _IconBox({
    required this.iconData,
    required this.selected,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? Colors.blue : Colors.grey),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Tooltip(
          message: tooltip,
          child: Icon(iconData, color: selected ? Colors.blue : Colors.black),
        ),
      ),
    );
  }
}

class DrawingPage extends StatefulWidget {
  final Function(String, List<Stroke>) onSave;
  final List<Stroke>? strokes; // Accept saved strokes
  final String? existingDrawingName;

  const DrawingPage({super.key, required this.onSave, this.strokes, this.existingDrawingName});

  @override
  _DrawingPageState createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController animationController;
  final ValueNotifier<Color> selectedColor = ValueNotifier(Colors.black);
  final ValueNotifier<double> strokeSize = ValueNotifier(10.0);
  final ValueNotifier<double> eraserSize = ValueNotifier(10.0);
  final ValueNotifier<DrawingTool> drawingTool = ValueNotifier(DrawingTool.pencil);
  final GlobalKey canvasGlobalKey = GlobalKey();
  final CurrentStrokeValueNotifier currentStroke = CurrentStrokeValueNotifier();
  final ValueNotifier<List<Stroke>> allStrokes = ValueNotifier([]);

  List<Point> _points = []; // Store the drawn points for gesture recognition

  List<Stroke> strokes = [];
  String recognizedGesture = '';
  Offset? _currentPointerPosition;
  late JavascriptRuntime jsRuntime;
  String jsCode = ' ';

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    if (widget.strokes != null) {
      allStrokes.value = widget.strokes!;
    }
    loadJs();
    jsRuntime = getJavascriptRuntime();
  }

  Future<void> loadJs() async {
    jsCode = await rootBundle.loadString('assets/pdollar.js');
    jsRuntime.evaluate(jsCode);
    jsRuntime.evaluate('var recognizer = new PDollarRecognizer();');
    print('Recognizer initialized successfully');

    String fileContent = await rootBundle.loadString('assets/drawing_page_gestures.txt');
    final result = jsRuntime.evaluate('recognizer.ProcessGesturesFile(`$fileContent`);');
  }

  String pDollarRecognizer(List<Point> points) {
    String pointsAsJson = jsonEncode(points);

    // Call the Recognize function and pass the points array
    final result = jsRuntime.evaluate('recognizer.Recognize($pointsAsJson);');
    return result.stringResult;
  }

  void onPanUpdate(DragUpdateDetails details) {
      setState(() {
        _points.add(Point(details.localPosition.dx, details.localPosition.dy, 0));
        _currentPointerPosition = Offset(details.localPosition.dx, details.localPosition.dy);
      });
  }

  List<String> savedDrawingPaths = [];

  Future<void> _saveDrawing([String? name]) async {
    String drawingName = widget.existingDrawingName?.replaceAll(".png", "") ?? '';
    final temp = allStrokes.value.last;
    allStrokes.value.removeLast();

    if (drawingName.isEmpty) {
      final nameController = TextEditingController();
      final name = await showDialog<String>(context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Save Drawing"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Enter drawing name'),
          ),
          actions: <Widget>[
            TextButton(onPressed:() {Navigator.of(context).pop(null);}, child: const Text('Cancel')),
            TextButton(onPressed:() {if(nameController.text.isNotEmpty) {Navigator.of(context).pop(nameController.text);};}, child: const Text("Save"),
            )],
        );
          });

      if (name != null) {
        drawingName = name;
      } else {
        allStrokes.value.add(temp);
        return;
      }
    } else {
      final result = await showDialog<bool>(context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Save Drawing"),
              content: Text('Save current drawing as "$drawingName"'),
              actions: <Widget>[
                TextButton(onPressed:() {Navigator.of(context).pop(false);}, child: const Text('Cancel')),
                TextButton(onPressed:() {Navigator.of(context).pop(true);}, child: const Text("Save"),
                )],
            );
          });

      if (result == false) {
        allStrokes.value.add(temp);
        return;
      }
    }

      RenderRepaintBoundary boundary = canvasGlobalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/${drawingName}.png';
      final file = File(filePath);
      await file.writeAsBytes(buffer);

      final strokePath = '${directory.path}/${drawingName}.json';
      final strokesJson = jsonEncode(allStrokes.value.map((stroke) => stroke.toJson()).toList());
      await File(strokePath).writeAsString(strokesJson);

      return showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return AlertDialog(
                title: const Text('Drawing Saved'),
                content: const Text('Your drawing has been successfully saved.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                    Navigator.of(context).pop(); // Return to main page
                  },
                  child: const Text('OK'),
                ),
              ],
            );}
      );
  }

  Future<bool?> showSaveDialog() async {
    final nameController = TextEditingController();

    return showDialog<bool>(
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
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  Navigator.of(context).pop(true);
                  _saveDrawing(nameController.text);
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
      body: Column(
        children: [Container(
          color: Theme.of(context).colorScheme.inversePrimary,
          padding: EdgeInsets.fromLTRB(0, 0, 0, 10.0),
          height: 120,
          child: Row(
                children: [
                SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                    children:[
                      const SizedBox(height: 60),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ColorPalette(selectedColorListenable: selectedColor),
                          SizedBox(width: 15),
                          ValueListenableBuilder<DrawingTool>(
                            valueListenable: drawingTool,
                            builder: (context, tool, child) {
                              return _IconBox(
                                iconData: FontAwesomeIcons.pencil,
                                selected: tool == DrawingTool.pencil,
                                onTap: () {
                                  drawingTool.value = DrawingTool.pencil;
                                  // Optionally force a rebuild for the sliders if needed
                                  setState(() {});
                                },
                                tooltip: 'Pencil',
                              );
                            },
                          ),
                          ValueListenableBuilder<DrawingTool>(
                            valueListenable: drawingTool,
                            builder: (context, tool, child) {
                              return _IconBox(
                                iconData: FontAwesomeIcons.eraser,
                                selected: tool == DrawingTool.eraser,
                                onTap: () {
                                  drawingTool.value = DrawingTool.eraser;
                                  // Optionally force a rebuild for the sliders if needed
                                  setState(() {});
                                },
                                tooltip: 'Eraser',
                              );
                            },
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 20.0),
                              child: AnimatedSwitcher(
                                duration: Duration(milliseconds: 300),
                                child: drawingTool.value == DrawingTool.pencil
                                    ? Row(
                                  key: ValueKey('pencilSlider'),
                                  children: [
                                    const Text(
                                      'Stroke Size: ',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: strokeSize.value,
                                        min: 0,
                                        max: 50,
                                        onChanged: (val) {
                                          setState(() {
                                            strokeSize.value = val;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                )
                                    : Row(
                                  key: ValueKey('eraserSlider'),
                                  children: [
                                    const Text(
                                      'Eraser Size: ',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: eraserSize.value,
                                        min: 0,
                                        max: 50,
                                        onChanged: (val) {
                                          setState(() {
                                            eraserSize.value = val;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],)]))]),),
          Expanded(
            child: Stack(
              children: [SizedBox(
                  height: MediaQuery.of(context).size.height,
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
                        ]),
                        builder: (context, _) {
                          return DrawingCanvas(
                            options: DrawingCanvasOptions(
                              currentTool: drawingTool.value,
                              size: drawingTool.value == DrawingTool.eraser ? eraserSize.value : strokeSize.value,
                              strokeColor: selectedColor.value,
                              backgroundColor: Colors.white,
                            ),
                            canvasKey: canvasGlobalKey,
                            currentStrokeListenable: currentStroke,
                            strokesListenable: allStrokes,
                          );
                        },
                      ),
                      if (_currentPointerPosition != null) // Draw only if the position is set
                        Positioned(
                          left: _currentPointerPosition!.dx - 17, // Center the dot
                          top: _currentPointerPosition!.dy - 17,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black, width: 2), // Black hollow circle
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onDoubleTap: () {
                      final strokeCount = allStrokes.value.length;
                      allStrokes.value.removeRange(strokeCount - 2, strokeCount);
                      if (strokeCount - 2 >= 1) {
                        final lastStroke = allStrokes.value.last.points;
                        List<Point> lastPoints = lastStroke.map((offset) => Point(offset.dx, offset.dy, 0)).toList();

                        String recognizedShape = pDollarRecognizer(lastPoints);
                        String shapeName = pDollarRecognizer(_points);

                        if (shapeName == "checkmark") {
                          showDialog<void>(
                              context: context,
                              barrierDismissible: true,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('check recognized'),
                                  content: const Text('Your drawing has been successfully saved.'),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).pop(); // Close the dialog
                                      },
                                      child: const Text('OK'),
                                    ),
                                  ],
                                );}
                          );
                        }
                      }
                  },
                  onPanStart: (details) {
                    _points.clear();
                    _points.add(Point(details.localPosition.dx, details.localPosition.dy, 0));

                    setState(() {
                      _currentPointerPosition = details.localPosition;
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _points.add(Point(details.localPosition.dx, details.localPosition.dy, 0));
                      _currentPointerPosition = details.localPosition;
                    });

                  },
                  onPanEnd: (details) async {
                    if (drawingTool.value != DrawingTool.eraser && _points.isNotEmpty) {
                      String gestureName = pDollarRecognizer(_points);
                      if (gestureName   == "checkmark" || gestureName == "s") {
                        print("gesture name:" + gestureName);
                        await _saveDrawing();
                      }
                    }

                    _currentPointerPosition = null;

                    setState(() {
                    });
                  },
                ),
              ]
            )
          )
        ]
      ),
    );}
}