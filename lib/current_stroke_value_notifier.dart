import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:painting_app_423/stroke.dart';

class CurrentStrokeValueNotifier extends ValueNotifier<Stroke?> {
  CurrentStrokeValueNotifier() : super(null);

  bool get hasStroke => value != null;

  void startStroke(
      Offset point, {
        Color color = Colors.blueAccent,
        double size = 10,
        double opacity = 1,
        StrokeType type = StrokeType.normal,
        int? sides,
      }) {
    if (hasStroke) return; // Prevent starting a new stroke if one is already active

    value = type == StrokeType.eraser
        ? EraserStroke(
      points: [point],
      color: const Color(0xfff2f3f7),
      size: size,
      opacity: 1,
    )
        : NormalStroke(
      points: [point],
      color: color,
      size: size,
      opacity: opacity,
    );
  }

  void addPoint(Offset point) {
    if (value == null) return; // Avoid adding points if no stroke is active

    // Clone the existing points and add the new point
    final points = List<Offset>.from(value!.points)..add(point);
    value = value!.copyWith(points: points); // Update the stroke with new points
  }

  void clear() {
    value = null; // Reset the current stroke
  }
}
