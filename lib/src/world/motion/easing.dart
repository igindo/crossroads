import 'dart:math' as math;

import 'package:crossroads/src/world/point.dart';
import 'package:crossroads/src/world/vector.dart';

const double pi_2 = math.pi / 2;

Point easeOut(int timeMs, final Vector change, final int durationMs) {
  final normalizedTime = timeMs > durationMs ? durationMs : timeMs;
  final offset = math.sin(normalizedTime / durationMs * pi_2);

  return Point(change.x * offset, change.y * offset);
}

Point easeIn(int timeMs, final Vector change, final int durationMs) {
  final normalizedTime = timeMs > durationMs ? durationMs : timeMs;
  final offset = math.cos(normalizedTime / durationMs * pi_2);

  return Point(-change.x * offset + change.x, -change.y * offset + change.y);
}

Point linear(int timeMs, final Vector change, final int durationMs) {
  final normalizedTime = timeMs > durationMs ? durationMs : timeMs;
  final offset = normalizedTime / durationMs;

  return Point(change.x * offset, change.y * offset);
}
