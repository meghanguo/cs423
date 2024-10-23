import 'package:flutter/material.dart';
import 'stroke.dart'; // Your Stroke class
import 'package:painting_app_423/drawing_page.dart';

class SavedDrawingPage extends StatelessWidget {
  final List<Stroke> strokes;
  final String drawingName;

  const SavedDrawingPage({
    Key? key,
    required this.strokes,
    required this.drawingName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(drawingName),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: DrawingPage(
        onSave: (name, strokes) {
          // Handle saving the drawing if needed
        },
        strokes: strokes, // Pass the saved strokes to DrawingPage
      ),
    );
  }
}
