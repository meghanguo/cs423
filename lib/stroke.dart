import 'package:flutter/material.dart';

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

    // Create a NormalStroke or EraserStroke based on strokeType
    if (strokeType == StrokeType.eraser) {
      return EraserStroke(
        points: points,
        color: color,
        size: size,
        opacity: opacity,
      );
    } else {
      return NormalStroke(
        points: points,
        color: color,
        size: size,
        opacity: opacity,
      );
    }
  }
}

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

enum StrokeType {
  normal,
  eraser;

  static StrokeType fromString(String value) {
    switch (value) {
      case 'normal':
        return StrokeType.normal;
      case 'eraser':
        return StrokeType.eraser;
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
    }
  }
}