import 'dart:collection';
import 'dart:math';

import 'package:crossroads/src/world/connection.dart';
import 'package:crossroads/src/world/network.dart';
import 'package:crossroads/src/world/point.dart';

List<Connection> resolveConnection(final Network network, final Point start,
    final Point end) {
  final points = _resolvePoints(network, start, end);

  List<Connection> toConnections(final List<Point> points) {
    final len = points.length;

    if (len == 0) return const <Connection>[];

    final connections = List<Connection>(len - 1);

    bool Function(Connection) isConnection(final Point p1, final Point p2) =>
        (Connection connection) =>
            connection.start == p1 && connection.end == p2;

    for (var i = 1; i < len; i++) {
      final p1 = points[i - 1], p2 = points[i];

      connections[i - 1] = network.pointMapped[p1].firstWhere(
          isConnection(p1, p2),
          orElse: () => network.pointMapped[p2]
              .firstWhere(isConnection(p1, p2), orElse: () => null));
    }

    return connections;
  }

  return toConnections(points);
}

List<Point> _resolvePoints(final Network network, final Point start,
    final Point end) {
  final calculations = <Point, _Calc>{};
  final open = <Point>[], closed = <Point>[];

  double heuristic(final Point curr, final Point goal) {
    var x = curr.x - goal.x, y = curr.y - goal.y;

    return sqrt(x * x + y * y);
  }

  open.add(start);

  while (open.length > 0) {
    final calc = calculations.putIfAbsent(open[0], () => _Calc());

    var bestCost = calc.f;
    var bestPointIndex = 0;

    for (var i = 1; i < open.length; i++) {
      final openCalc = calculations.putIfAbsent(open[i], () => _Calc());

      if (openCalc.f < bestCost) {
        bestCost = openCalc.f;
        bestPointIndex = i;
      }
    }

    var currentPoint = open[bestPointIndex];
    var currCalc = calculations.putIfAbsent(currentPoint, () => _Calc());

    if (currentPoint == end) {
      final path = Queue<Point>.from([end]);

      while (currCalc.parentIndex != -1) {
        currentPoint = closed[currCalc.parentIndex];
        currCalc = calculations.putIfAbsent(currentPoint, () => _Calc());

        path.addFirst(currentPoint);
      }

      return path.toList(growable: false);
    }

    open.removeAt(bestPointIndex);

    closed.add(currentPoint);

    final connections =
        network.possibleConnections(currentPoint).toList(growable: false);

    for (var i = 0, len = connections.length; i < len; i++) {
      final connection = connections[i];
      final pointTo =
          connection.start == currentPoint ? connection.end : connection.start;

      var foundInClosed = false;

      for (var i = 0; i < closed.length; i++) {
        if (closed[i] == pointTo) {
          foundInClosed = true;

          break;
        }
      }

      if (foundInClosed) {
        continue;
      }

      var foundInOpen = false;

      for (var i = 0; i < open.length; i++) {
        if (open[i] == pointTo) {
          foundInOpen = true;

          break;
        }
      }

      if (!foundInOpen) {
        final toCalc = calculations.putIfAbsent(pointTo, () => _Calc());

        toCalc.parentIndex = closed.length - 1;

        toCalc.g = currCalc.g +
            sqrt(pow(pointTo.x - currentPoint.x, 2) +
                pow(pointTo.y - currentPoint.y, 2));
        toCalc.h = heuristic(pointTo, end);
        toCalc.f = toCalc.g + toCalc.h;

        open.add(pointTo);
      }
    }
  }

  return <Point>[];
}

class _Calc {
  double g = -1.0, h = -1.0, f = -1.0;
  int parentIndex = -1;
}
