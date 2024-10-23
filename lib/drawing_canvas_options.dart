import 'dart:ui';

import 'package:flutter/material.dart';

import 'drawing_tool.dart';

class DrawingCanvasOptions{
  final Color strokeColor;
  final double size;
  final double opacity;
  final DrawingTool currentTool;
  final Color backgroundColor;

  const DrawingCanvasOptions({
    this.strokeColor = const Color(0xff303337),
    this.size = 10,
    this.opacity = 1,
    this.currentTool = DrawingTool.pencil,
    this.backgroundColor = Colors.white,
  });

  DrawingCanvasOptions copyWith({
    Color? strokeColor,
    double? size,
    double? opacity,
    DrawingTool? currentTool,
    Color? backgroundColor,
  }) {
    return DrawingCanvasOptions(
      strokeColor: strokeColor ?? this.strokeColor,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      currentTool: currentTool ?? this.currentTool,
      backgroundColor: Colors.white,
    );
  }
}