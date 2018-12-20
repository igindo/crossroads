import 'dart:html';
import 'dart:math' as math;

import 'package:crossroads/crossroads.dart';

void main() {
  final CanvasElement canvas = querySelector('#canvas');

  final scheduler = StoplightScheduler(
      [const Duration(seconds: 8), const Duration(seconds: 2), const Duration(seconds: 8)]);

  Connection createConnection(Point p1, Point p2, Direction direction,
          {Map<Connection, List<TrafficSign>> accepts =
              const <Connection, List<TrafficSign>>{}}) =>
      Connection(p1, p2, [
        ConnectionConfig(ActorType.car, direction, accepts, Speed.undivided)
      ]);

  final c_1 = createConnection(
          const Point(195, 665), const Point(380, 441), Direction.start_to_end),
      c_1_i = createConnection(
          const Point(358, 440), const Point(182, 665), Direction.start_to_end),
      c_2 = createConnection(const Point(380, 441), const Point(529, 665), Direction.start_to_end,
          accepts: {
        c_1: [Stoplight(scheduler, (int index) => index == 0)]
      }),
      c_2_i = createConnection(
          const Point(546, 665), const Point(399, 433), Direction.start_to_end),
      c_2_1_j = createConnection(
          const Point(399, 433), const Point(358, 440), Direction.start_to_end,
          accepts: {
        c_2_i: [Stoplight(scheduler, (int index) => index == 0)]
      }),
      c_3 = createConnection(
          const Point(731, 472), const Point(392, 419), Direction.start_to_end,
          accepts: {
        c_1: [Stoplight(scheduler, (int index) => index == 0)]
      }),
      c_3_i = createConnection(
          const Point(399, 433), const Point(731, 490), Direction.start_to_end),
      c_3_1_j = createConnection(
          const Point(392, 419), const Point(358, 440), Direction.start_to_end,
          accepts: {
        c_3: [Stoplight(scheduler, (int index) => index == 2)]
      }),
      c_3_2_j = createConnection(
          const Point(392, 419), const Point(380, 441), Direction.start_to_end,
          accepts: {
        c_2_i: [Stoplight(scheduler, (int index) => index == 2)]
      });

  final p0_1 = createConnection(
          const Point(0, 0), const Point(100, 0), Direction.start_to_end),
      p1_0 = createConnection(
          const Point(100, 0), const Point(0, 0), Direction.start_to_end),
      p1_2 = createConnection(
          const Point(100, 0), const Point(200, 0), Direction.start_to_end),
      p2_1 = createConnection(
          const Point(200, 0), const Point(100, 0), Direction.start_to_end),
      p2_3 = createConnection(
          const Point(200, 0), const Point(300, 0), Direction.start_to_end),
      p3_2 = createConnection(
          const Point(300, 0), const Point(200, 0), Direction.start_to_end),
      p3_4 = createConnection(
          const Point(300, 0), const Point(400, 0), Direction.start_to_end),
      p4_3 = createConnection(
          const Point(400, 0), const Point(300, 0), Direction.start_to_end),
      p2_d_1 = createConnection(
          const Point(200, 0), const Point(200, 100), Direction.start_to_end,
          accepts: {
        p1_2: [Stoplight(scheduler, (int index) => index == 0)],
        p3_2: [Stoplight(scheduler, (int index) => index == 2)]
      });

  final network =
      Network([c_1, c_1_i, c_2, c_2_i, c_2_1_j, c_3_i, c_3, c_3_1_j, c_3_2_j]);

  final supervisor = new TrafficSupervisor();

  supervisor.onSpawners.add([
    ActorSpawner(network, ActorType.car, c_1.start, [c_2.end, c_3_i.end]),
    ActorSpawner(network, ActorType.car, c_2_i.start, [c_1_i.end, c_3_i.end]),
    ActorSpawner(network, ActorType.car, c_3.start, [c_1_i.end, c_2.end])
  ]);

  supervisor.snapshot.listen((snapshot) {
    final CanvasRenderingContext2D context = canvas.getContext('2d');

    context.clearRect(0, 0, 800, 665);

    snapshot.forEach((actor, point) {
      context.beginPath();
      context.arc(10 + point.x, 10 + point.y, 4, 0, 2 * math.pi);
      context.stroke();
    });
  });
}
