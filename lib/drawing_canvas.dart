import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:painting_app_423/current_stroke_value_notifier.dart';
import 'package:painting_app_423/drawing_tool.dart';
import 'package:painting_app_423/drawing_tool_extensions.dart';
import 'package:painting_app_423/offset_extension.dart';
import 'package:painting_app_423/stroke.dart';
import 'drawing_canvas_options.dart';

class DrawingCanvas extends StatefulWidget {
  final ValueNotifier<List<Stroke>> strokesListenable;
  final CurrentStrokeValueNotifier currentStrokeListenable;
  final DrawingCanvasOptions options;
  final Function(Stroke?)? onDrawingStrokeChanged;
  final GlobalKey canvasKey;
  final bool canDraw;

  const DrawingCanvas({
    super.key,
    required this.strokesListenable,
    required this.currentStrokeListenable,
    required this.options,
    this.onDrawingStrokeChanged,
    required this.canvasKey,
    this.canDraw = true,
  });

  @override
  State<StatefulWidget> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  Color get strokeColor => widget.options.strokeColor;
  double get size => widget.options.size;
  double get opacity => widget.options.opacity;
  DrawingTool get currentTool => widget.options.currentTool;
  ValueNotifier<List<Stroke>> get _strokes => widget.strokesListenable;
  CurrentStrokeValueNotifier get _currentStroke => widget.currentStrokeListenable;

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.canDraw) return;

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
    print('Pointer Down: ${standardOffset}');
    widget.onDrawingStrokeChanged?.call(_currentStroke.value);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.canDraw) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.globalToLocal(event.position);

    final standardOffset = offset.scaleToStandard(box.size);
    _currentStroke.addPoint(standardOffset);
    print('Pointer Move: ${standardOffset}');
    widget.onDrawingStrokeChanged?.call(_currentStroke.value);
  }


  void _onPointerUp(PointerUpEvent event) {
    if (!widget.canDraw) return;

    if (!_currentStroke.hasStroke) return;
    _strokes.value = List<Stroke>.from(_strokes.value)..add(_currentStroke.value!);
    widget.strokesListenable.value = List<Stroke>.from(_strokes.value);

    print('Pointer Up: Added stroke with ${_currentStroke.value}');
    _currentStroke.clear();
    widget.onDrawingStrokeChanged?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerUp: _onPointerUp,
      onPointerMove: _onPointerMove,
      onPointerDown: _onPointerDown,
      child: RepaintBoundary(
        key: widget.canvasKey,
        child: CustomPaint(
          painter: _DrawingCanvasPainter(
            strokesListenable: _strokes,
            currentStrokeListenable: _currentStroke,
            backgroundColor: Colors.white,
          ),
          child: SizedBox.expand(), // Ensure the CustomPaint fills the available space
        ),
      ),
    );
  }
}

class _DrawingCanvasPainter extends CustomPainter {
  final ValueNotifier<List<Stroke>>? strokesListenable;
  final CurrentStrokeValueNotifier? currentStrokeListenable;
  final Color backgroundColor;

  _DrawingCanvasPainter({
    this.strokesListenable,
    this.currentStrokeListenable,
    this.backgroundColor = Colors.white,
  }) : super(
    repaint: Listenable.merge([strokesListenable, currentStrokeListenable]),
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = backgroundColor,
    );

    final strokes = List<Stroke>.from(strokesListenable?.value ?? []);

    if (currentStrokeListenable?.hasStroke ?? false) {
      strokes.add(currentStrokeListenable!.value!);
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
      }else if (stroke is LineStroke) {
        // scale the points to the standard size
        final firstPoint = points.first.scaleFromStandard(size);
        final lastPoint = points.last.scaleFromStandard(size);
        canvas.drawLine(firstPoint, lastPoint, paint);
        continue;
      } else if (stroke is CircleStroke) {
        // scale the points to the standard size
        final firstPoint = points.first.scaleFromStandard(size);
        final lastPoint = points.last.scaleFromStandard(size);
        final rect = Rect.fromPoints(firstPoint, lastPoint);

        canvas.drawOval(rect, paint);
        continue;
      } else if (stroke is RectangleStroke) {
        // scale the points to the standard size
        final firstPoint = points.first.scaleFromStandard(size);
        final lastPoint = points.last.scaleFromStandard(size);
        final rect = Rect.fromPoints(firstPoint, lastPoint);

        canvas.drawRect(rect, paint);
        continue;
      }

      else if (stroke is EraserStroke) {
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

        // Use quadratic bezier to draw smooth curves through the points
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // Always repaint
}
