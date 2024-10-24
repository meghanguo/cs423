enum DrawingTool {
  pencil,
  eraser,
  scroll;

  bool get isEraser => this == DrawingTool.eraser;
  bool get isPencil => this == DrawingTool.pencil;
  bool get isScroll => this == DrawingTool.scroll;
}