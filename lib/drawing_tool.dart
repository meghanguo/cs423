enum DrawingTool {
  pencil,
  eraser,
  scroll,
  line,
  rectangle,
  circle;

  bool get isEraser => this == DrawingTool.eraser;
  bool get isPencil => this == DrawingTool.pencil;
  bool get isScroll => this == DrawingTool.scroll;
  bool get isLine => this == DrawingTool.line;
  bool get isCircle => this == DrawingTool.circle;
  bool get isRectangle => this == DrawingTool.rectangle;
}