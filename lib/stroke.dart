import 'package:flutter/material.dart';

// Enum for StrokeType
enum StrokeType {
  normal,
  eraser,
  scroll,
  line,
  rectangle,
  circle;

  static StrokeType fromString(String value) {
    switch (value) {
      case 'normal':
        return StrokeType.normal;
      case 'eraser':
        return StrokeType.eraser;
      case 'scroll':
        return StrokeType.scroll;
      case 'line':
        return StrokeType.line;
      case 'circle':
        return StrokeType.circle;
      case 'rectangle':
        return StrokeType.rectangle;
      default:
        return StrokeType.normal;
    }
  }

  @override
  String toString() {
    switch (this) {
      case StrokeType.normal:
        return 'normal';
      case StrokeType.eraser:
        return 'eraser';
      case StrokeType.scroll:
        return 'scroll';
      case StrokeType.line:
        return 'line';
      case StrokeType.circle:
        return 'circle';
      case StrokeType.rectangle:
        return 'rectangle';
    }
  }
}

// Abstract class for strokes
abstract class Stroke {
  List<Offset> points;
  final Color color;
  final double size;
  final double opacity;
  final StrokeType strokeType;

  Stroke({
    required this.points,
    this.color = Colors.black,
    this.size = 1,
    this.opacity = 1,
    this.strokeType = StrokeType.normal,
  });

  Stroke copyWith({
    List<Offset>? points,
    Color? color,
    double? size,
    double? opacity,
  });

  bool get isEraser => strokeType == StrokeType.eraser;
  bool get isNormal => strokeType == StrokeType.normal;
  bool get isLine => strokeType == StrokeType.line;
  bool get isCircle => strokeType == StrokeType.circle;
  bool get isRectangle => strokeType == StrokeType.rectangle;

  Map<String, dynamic> toJson() {
    return {
      'color': color.value, // Save color as an integer (ARGB value)
      'size': size,
      'opacity': opacity,
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'strokeType': strokeType.toString(), // Save strokeType as a string
    };
  }

  // Factory to deserialize Stroke based on strokeType
  factory Stroke.fromJson(Map<String, dynamic> json) {
    List<Offset> points = (json['points'] as List)
        .map((point) => Offset(point['x'], point['y']))
        .toList();
    Color color = Color(json['color']);
    double size = json['size'];
    double opacity = json['opacity'];
    StrokeType strokeType = StrokeType.fromString(json['strokeType']);

    switch (strokeType) {
      case StrokeType.eraser:
        return EraserStroke(
          points: points,
          color: color,
          size: size,
          opacity: opacity,
        );
      case StrokeType.line:
        return LineStroke(
          points: points,
          color: color,
          size: size,
          opacity: opacity,
        );
      case StrokeType.rectangle:
        return RectangleStroke(
          points: points,
          color: color,
          size: size,
          opacity: opacity,
        );
      case StrokeType.circle:
        return CircleStroke(
          points: points,
          color: color,
          size: size,
          opacity: opacity,
        );
      default:
        return NormalStroke(
          points: points,
          color: color,
          size: size,
          opacity: opacity,
        );
    }
  }
}

// NormalStroke class for normal strokes
class NormalStroke extends Stroke {
  NormalStroke({
    required super.points,
    super.color,
    super.size,
    super.opacity,
  }) : super(strokeType: StrokeType.normal);

  @override
  NormalStroke copyWith({
    List<Offset>? points,
    Color? color,
    double? size,
    double? opacity,
  }) {
    return NormalStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
    );
  }
}

// EraserStroke class
class EraserStroke extends Stroke {
  EraserStroke({
    required super.points,
    super.color,
    super.size,
    super.opacity,
  }) : super(strokeType: StrokeType.eraser);

  @override
  EraserStroke copyWith({
    List<Offset>? points,
    Color? color,
    double? size,
    double? opacity,
  }) {
    return EraserStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
    );
  }
}

// LineStroke class
class LineStroke extends Stroke {
  LineStroke({
    required super.points,
    super.color,
    super.size,
    super.opacity,
  }) : super(strokeType: StrokeType.line);

  @override
  LineStroke copyWith({
    List<Offset>? points,
    Color? color,
    double? size,
    double? opacity,
  }) {
    return LineStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
    );
  }
}

// RectangleStroke class
class RectangleStroke extends Stroke {
  RectangleStroke({
    required super.points,
    super.color,
    super.size,
    super.opacity,
  }) : super(strokeType: StrokeType.rectangle);

  @override
  RectangleStroke copyWith({
    List<Offset>? points,
    Color? color,
    double? size,
    double? opacity,
  }) {
    return RectangleStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
    );
  }
}

// CircleStroke class
class CircleStroke extends Stroke {
  CircleStroke({
    required super.points,
    super.color,
    super.size,
    super.opacity,
  }) : super(strokeType: StrokeType.circle);

  @override
  CircleStroke copyWith({
    List<Offset>? points,
    Color? color,
    double? size,
    double? opacity,
  }) {
    return CircleStroke(
      points: points ?? this.points,
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
    );
  }
}