import 'dart:html';
import 'dart:math' as math;

import 'package:crossroads/crossroads.dart';

void main() {
  final CanvasElement canvas = querySelector('#canvas');

  Connection createConnection(Point p1, Point p2, Direction direction) =>
      Connection(p1, p2, [
        ConnectionConfig(
            ActorType.car,
            direction,
            [
              ConnectionLane(null, [Stoplight()])
            ],
            Speed.undivided)
      ]);

  final network = Network([
    createConnection(
        const Point(0, 0), const Point(100, 0), Direction.start_to_end),
    createConnection(
        const Point(100, 0), const Point(0, 0), Direction.start_to_end),
    createConnection(
        const Point(100, 0), const Point(200, 0), Direction.start_to_end),
    createConnection(
        const Point(200, 0), const Point(100, 0), Direction.start_to_end),
    createConnection(
        const Point(200, 0), const Point(300, 0), Direction.start_to_end),
    createConnection(
        const Point(300, 0), const Point(200, 0), Direction.start_to_end),
    createConnection(
        const Point(300, 0), const Point(400, 0), Direction.start_to_end),
    createConnection(
        const Point(400, 0), const Point(300, 0), Direction.start_to_end),
    createConnection(
        const Point(0, 0), const Point(0, 100), Direction.start_to_end),
    createConnection(
        const Point(100, 0), const Point(100, 100), Direction.start_to_end),
    createConnection(
        const Point(200, 0), const Point(200, 100), Direction.start_to_end),
    createConnection(
        const Point(300, 0), const Point(300, 100), Direction.start_to_end),
    createConnection(
        const Point(400, 0), const Point(400, 100), Direction.start_to_end),
  ]);

  final spawner = new ActorSpawner(network, ActorType.car, const [
    Point(0, 0),
    Point(100, 0),
    Point(200, 0),
    Point(300, 0),
    Point(400, 0)
  ], const [
    Point(0, 100),
    Point(100, 100),
    Point(200, 100),
    Point(300, 100),
    Point(400, 100)
  ]);

  final supervisor = new TrafficSupervisor()..onSpawner.add(spawner);

  supervisor.snapshot.listen((snapshot) {
    final CanvasRenderingContext2D context = canvas.getContext('2d');

    context.clearRect(0, 0, 800, 600);

    snapshot.forEach((actor, point) {
      context.beginPath();
      context.arc(10 + point.x, 10 + point.y, 4, 0, 2 * math.pi);
      context.stroke();
    });
  });
}
