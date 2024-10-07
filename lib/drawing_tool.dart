enum DrawingTool {
  pencil,
  eraser;

  bool get isEraser => this == DrawingTool.eraser;
  bool get isPencil => this == DrawingTool.pencil;
}