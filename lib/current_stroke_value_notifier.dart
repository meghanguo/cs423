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
    value = () {
      if (type == StrokeType.eraser) {
        return EraserStroke(
          points: [point],
          color: const Color(0xfff2f3f7),
          size: size,
          opacity: 1,
        );
      }

      return NormalStroke(
        points: [point],
        color: color,
        size: size,
        opacity: opacity,
      );
    }();
  }

  void addPoint(Offset point) {
    final points = List<Offset>.from(value?.points ?? [])..add(point);
    value = value?.copyWith(points: points);
  }

  void clear() {
    value = null;
  }
}