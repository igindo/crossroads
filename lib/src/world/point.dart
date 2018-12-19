import 'dart:math' as math;

class Point {
  final double x, y;

  const Point(this.x, this.y);

  Point add(Point other) => Point(x + other.x, y + other.y);

  Point normalize() => Point(x < .0 ? .0 : x, y < .0 ? .0 : y);

  double distanceTo(Point other) =>
      math.sqrt(math.pow(other.x - x, 2) + math.pow(other.y - y, 2));

  @override
  bool operator ==(Object other) =>
      other is Point && this.x == other.x && this.y == other.y;

  @override
  int get hashCode => '$x:$y'.hashCode;

  @override
  String toString() => 'x: $x, y: $y';
}
