// point_cloud_recognizer.dart
import 'dart:math';

class Point {
  final double x;
  final double y;

  Point(this.x, this.y);
}

class Gesture {
  final String name;
  final List<Point> points;

  Gesture(this.name, this.points);
}

class PointCloudRecognizer {
  static String classify(Gesture candidate, List<Gesture> trainingSet) {
    double minDistance = double.infinity;
    String gestureClass = '';

    for (var template in trainingSet) {
      double dist = greedyCloudMatch(candidate.points, template.points);
      if (dist < minDistance) {
        minDistance = dist;
        gestureClass = template.name;
      }
    }
    return gestureClass;
  }

  static double greedyCloudMatch(List<Point> points1, List<Point> points2) {
    int n = points1.length; // The two clouds should have the same number of points by now
    double eps = 0.5;       // Controls the number of greedy search trials
    int step = pow(n, 1 - eps).floor(); // Fixed the exponentiation here
    double minDistance = double.infinity;

    for (int i = 0; i < n; i += step) {
      double dist1 = cloudDistance(points1, points2, i);   // Match points1 --> points2
      double dist2 = cloudDistance(points2, points1, i);   // Match points2 --> points1
      minDistance = min(minDistance, min(dist1, dist2));
    }
    return minDistance;
  }

  static double cloudDistance(List<Point> points1, List<Point> points2, int startIndex) {
    int n = points1.length;       // The two clouds should have the same number of points by now
    List<bool> matched = List.filled(n, false); // Matched points in points2
    double sum = 0;
    int i = startIndex;

    do {
      int index = -1;
      double minDistance = double.infinity;

      for (int j = 0; j < n; j++) {
        if (!matched[j]) {
          double dist = sqrEuclideanDistance(points1[i], points2[j]);
          if (dist < minDistance) {
            minDistance = dist;
            index = j;
          }
        }
      }
      matched[index] = true; // Mark point as matched
      double weight = 1.0 - ((i - startIndex + n) % n) / n;
      sum += weight * minDistance; // Weighted distance
      i = (i + 1) % n;
    } while (i != startIndex);

    return sum;
  }

  static double sqrEuclideanDistance(Point p1, Point p2) {
    return (p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y);
  }
}