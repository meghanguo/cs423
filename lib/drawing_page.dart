import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:painting_app_423/stroke.dart';

import 'canvas_side_bar.dart';
import 'current_stroke_value_notifier.dart';
import 'drawing_canvas.dart';
import 'drawing_canvas_options.dart';
import 'drawing_tool.dart';

class DrawingPage extends StatefulWidget {
  const DrawingPage({super.key});

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  void _drawingMode() {
    setState(() {
      _isLocked = !_isLocked;
      _canDraw = !_isLocked;

      // Show message based on the current mode
      final snackBar = SnackBar(
        content: Text(_isLocked ? 'No Drawing Mode On' : 'Drawing Mode On'),
        duration: Duration(seconds: 2),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      drawer: Drawer(
        child: _canDraw ? CanvasSideBar(
          drawingTool: drawingTool,
          selectedColor: selectedColor,
          strokeSize: strokeSize,
          eraserSize: eraserSize,
          currentSketch: currentStroke,
          allSketches: allStrokes,
          canvasGlobalKey: canvasGlobalKey,
        ) : null, // Disable drawer interaction when locked
      ),
      backgroundColor: Color(0xfff2f3f7),
      body: Stack(
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
    );
  }
}