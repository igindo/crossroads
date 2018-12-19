import 'package:crossroads/src/world/point.dart';

enum Easing { linear, sine }

class Vector {
  final double x, y;
  final Duration duration;
  final Point point;
  final Easing easing;

  const Vector(this.x, this.y, this.duration,
      {this.point = const Point(.0, .0), this.easing = Easing.linear});
}
