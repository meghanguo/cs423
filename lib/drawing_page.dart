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
import 'color_palette.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


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

  List<Gesture> gestureTemplates = [];
  List<Offset> _points = []; // Store the drawn points for gesture recognition

  List<Stroke> strokes = [];
  String recognizedGesture = '';
  List<Offset?> _currentStroke = [];

  Offset? _currentPointerPosition;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    if (widget.strokes != null) {
      strokes = widget.strokes!;
    }
  }

  void onPanUpdate(DragUpdateDetails details) {
      RenderBox renderBox = context.findRenderObject() as RenderBox;
      Offset point = renderBox.globalToLocal(details.globalPosition);
      setState(() {
        _points.add(point);
        _currentPointerPosition = point;
      });
  }

  void onPanEnd(DragEndDetails details) {
      recognizeGesture();
  }

  void recognizeGesture() {
    // Normalize points for recognition
    List<Point> normalizedPoints = _points
        .map((offset) => Point(offset.dx, offset.dy))
        .toList();

  }

  void showSnackBar() {
    final snackBar = SnackBar(content: Text('Check mark recognized!'));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            expandedHeight: 230.0,  // Adjust the height based on your needs
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(40.0, 10.0, 10.0, 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 60),  // Adjust spacing to look good inside AppBar
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
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
                                      max: 80,
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
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Colors',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    ColorPalette(
                      selectedColorListenable: selectedColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // You can add more slivers below if needed or an empty SliverFillRemaining for the rest of the body
          SliverFillRemaining(
            child: Center(
              child: GestureDetector(
                onPanUpdate: onPanUpdate,
                onPanEnd: (details) {
                  setState(() {
                    _currentPointerPosition = null; // Hide the dot when finished
                  });
                  onPanEnd(details);
                },
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 230,
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
                          );
                        },
                      ),
                      if (_currentPointerPosition != null) // Draw only if the position is set
                        Positioned(
                          left: _currentPointerPosition!.dx - 20, // Center the dot
                          top: _currentPointerPosition!.dy - 20,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}