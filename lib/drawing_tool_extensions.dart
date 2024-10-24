import 'package:painting_app_423/stroke.dart';
import 'drawing_tool.dart';

extension DrawingToolExtensions on DrawingTool {
  StrokeType get strokeType {
    switch (this) {
      case DrawingTool.pencil:
        return StrokeType.normal;
      case DrawingTool.eraser:
        return StrokeType.eraser;
      case DrawingTool.scroll:
        return StrokeType.scroll;
    }
  }
}
