import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:painting_app_423/current_stroke_value_notifier.dart';
import 'package:painting_app_423/drawing_tool.dart';
import 'package:painting_app_423/drawing_tool_extensions.dart';
import 'package:painting_app_423/offset_extension.dart';
import 'package:painting_app_423/stroke.dart';
import 'drawing_canvas_options.dart';

class DrawingCanvas extends StatefulWidget{
  final ValueNotifier<List<Stroke>> strokesListenable;
  final CurrentStrokeValueNotifier currentStrokeListenable;
  final DrawingCanvasOptions options;
  final Function(Stroke?)? onDrawingStrokeChanged;
  final GlobalKey canvasKey;
  final ValueNotifier<ui.Image?>? backgroundImageListenable;

  const DrawingCanvas({
    super.key,
    required this.strokesListenable,
    required this.currentStrokeListenable,
    required this.options,
    this.onDrawingStrokeChanged,
    required this.canvasKey,
    this.backgroundImageListenable,
  });

  @override
  State<StatefulWidget> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas>{
  Color get strokeColor => widget.options.strokeColor;
  double get size => widget.options.size;
  double get opacity => widget.options.opacity;
  DrawingTool get currentTool => widget.options.currentTool;
  ValueNotifier<List<Stroke>> get _strokes => widget.strokesListenable;
  CurrentStrokeValueNotifier get _currentStroke => widget.currentStrokeListenable;

  void _onPointerDown(PointerDownEvent event) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.globalToLocal(event.position);

    final standardOffset = offset.scaleToStandard(box.size);
    _currentStroke.startStroke(
      standardOffset,
      color: strokeColor,
      size: size,
      opacity: opacity,
      type: currentTool.strokeType,
    );
    widget.onDrawingStrokeChanged?.call(_currentStroke.value);
  }

  void _onPointerMove(PointerMoveEvent event) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.globalToLocal(event.position);

    final standardOffset = offset.scaleToStandard(box.size);
    _currentStroke.addPoint(standardOffset);
    widget.onDrawingStrokeChanged?.call(_currentStroke.value);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!_currentStroke.hasStroke) return;
    _strokes.value = List<Stroke>.from(_strokes.value)
      ..add(_currentStroke.value!);
    _currentStroke.clear();
    widget.onDrawingStrokeChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerUp: _onPointerUp,
      onPointerMove: _onPointerMove,
      onPointerDown: _onPointerDown,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              key: widget.canvasKey,
              child: CustomPaint(
                isComplex: true,
                painter: _DrawingCanvasPainter(
                  strokesListenable: _strokes,
                  backgroundColor: widget.options.backgroundColor,
                )
              ),
            ),
          ),

          Positioned.fill(child: RepaintBoundary(
              child: CustomPaint(
                isComplex: true,
                painter: _DrawingCanvasPainter(
                  strokeListenable: _currentStroke,
                  backgroundColor: widget.options.backgroundColor,
                  backgroundImageListenable: widget.backgroundImageListenable,
                )
              )
            ))
        ],
      ),
    );
  }
}

class _DrawingCanvasPainter extends CustomPainter {
  final ValueNotifier<List<Stroke>>? strokesListenable;
  final CurrentStrokeValueNotifier? strokeListenable;
  final Color backgroundColor;
  final ValueNotifier<ui.Image?>? backgroundImageListenable;

  _DrawingCanvasPainter({
    this.strokesListenable,
    this.strokeListenable,
    this.backgroundColor = Colors.white,
    this.backgroundImageListenable,
  }) : super(
    repaint: Listenable.merge([strokesListenable, strokeListenable, backgroundImageListenable]),
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (backgroundImageListenable != null) {
      final backgroundImage = backgroundImageListenable!.value;

      if (backgroundImage != null) {
        canvas.drawImageRect(backgroundImage, Rect.fromLTWH(0, 0, backgroundImage.width.toDouble(), backgroundImage.height.toDouble(),), Rect.fromLTWH(0, 0, size.width, size.height), Paint(),);
      }
    }
    final strokes = List<Stroke>.from(strokesListenable?.value ?? []);

    if (strokeListenable?.hasStroke ?? false) {
      strokes.add(strokeListenable!.value!);
    }

    for (final stroke in strokes) {
      final points = stroke.points;
      if (points.isEmpty) continue;

      final strokeSize = max(stroke.size, 1.0);
      final paint = Paint()
      ..color = stroke.color.withOpacity(stroke.opacity)
      ..strokeWidth = strokeSize
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

      if (stroke is NormalStroke) {
        final path = _getStrokePath(stroke, size);

        if (stroke.points.length == 1) {
          final center = stroke.points.first.scaleFromStandard(size);
          final radius = strokeSize / 2;
          canvas.drawCircle(center, radius, paint..style = PaintingStyle.fill);
          continue;
        }
        canvas.drawPath(path, paint);
        continue;
      }

      if (stroke is EraserStroke) {
        final path = _getStrokePath(stroke, size);
        canvas.drawPath(path, paint..color = backgroundColor);
        continue;
      }
    }
  }

  Path _getStrokePath(Stroke stroke, Size size) {
    final path = Path();
    final points = stroke.points;
    if (points.isNotEmpty) {
      final firstPoint = points.first.scaleFromStandard(size);
      path.moveTo(firstPoint.dx, firstPoint.dy);
      for (int i = 1; i < points.length - 1; ++i) {
        final p0 = points[i].scaleFromStandard(size);
        final p1 = points[i + 1].scaleFromStandard(size);

        // use quadratic bezier to draw smooth curves through the points
        path.quadraticBezierTo(
          p0.dx,
          p0.dy,
          (p0.dx + p1.dx) / 2,
          (p0.dy + p1.dy) / 2,
        );
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}