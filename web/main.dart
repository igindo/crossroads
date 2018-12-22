import 'dart:html';
import 'dart:math' as math;

import 'package:crossroads/crossroads.dart';

void main() {
  final CanvasElement canvas = querySelector('#canvas');

  final scheduler = StoplightScheduler([
    const Duration(seconds: 8),
    const Duration(seconds: 2),
    const Duration(seconds: 8),
    const Duration(seconds: 2)
  ]);

  Connection createConnection(Point p1, Point p2,
          {Map<Connection, List<TrafficSign>> accepts =
              const <Connection, List<TrafficSign>>{}}) =>
      Connection(p1, p2, Speed.undivided, accepts);

  const c1234 = [
    Point(380, 436),
    Point(384, 440),
    Point(399, 433),
    Point(391, 419)
  ];

  final r1 = createConnection(const Point(216, 665), c1234[1]),
      l1 = createConnection(c1234[0], const Point(201, 665)),
      r2 = createConnection(const Point(460, 516), c1234[2]),
      r2_1 = createConnection(const Point(547, 665), r2.start),
      l2 = createConnection(c1234[1], const Point(434, 503)),
      l2_1 = createConnection(l2.end, const Point(531, 665)),
      r3 = createConnection(const Point(731, 473), c1234[3]),
      l3 = createConnection(c1234[2], const Point(731, 488)),
      r4 = createConnection(c1234[3], const Point(243, 285)),
      l4 = createConnection(const Point(225, 290), const Point(279, 336)),
      r1_l3 = createConnection(r1.end, l3.start, accepts: {
    r1: [Stoplight(scheduler, (i) => i == 0)]
  }),
      r1_r4 = createConnection(r1.end, r4.start, accepts: {
    r1: [Stoplight(scheduler, (i) => i == 0)]
  }),
      r2_l1 = createConnection(r2.end, l1.start, accepts: {
    r2: [Stoplight(scheduler, (i) => i == 2)]
  }),
      r2_r4 = createConnection(r2.end, r4.start, accepts: {
    r2: [Stoplight(scheduler, (i) => i == 2)]
  }),
      r3_l1 = createConnection(r3.end, l1.start, accepts: {
    r3: [Stoplight(scheduler, (i) => i == 0)]
  }),
      r3_l2 = createConnection(r3.end, l2.start, accepts: {
    r3: [Stoplight(scheduler, (i) => i == 0)]
  }),
      r3_r4 = createConnection(r3.end, r4.start, accepts: {
    r3: [Stoplight(scheduler, (i) => i == 0)]
  }),
      r5 = createConnection(const Point(104, 405), const Point(179, 470)),
      r5_1 = createConnection(r5.end, l4.end),
      l4_1 = createConnection(l4.end, c1234[0], accepts: {
    r5_1: [
      GivePriority([l4])
    ]
  }),
      l4_l2 = createConnection(l4_1.end, l2.start, accepts: {
    l4_1: [Stoplight(scheduler, (i) => i == 2)]
  }),
      l4_l3 = createConnection(l4_1.end, l3.start, accepts: {
    l4_1: [Stoplight(scheduler, (i) => i == 1)]
  });

  final network = Network([
    r1,
    l1,
    r2,
    r2_1,
    l2,
    l2_1,
    r3,
    l3,
    r4,
    l4,
    l4_1,
    r1_l3,
    r2_l1,
    r3_l1,
    r3_l2,
    r1_r4,
    r2_r4,
    r3_r4,
    l4_l2,
    l4_l3,
    r5,
    r5_1
  ]);

  final supervisor = new TrafficSupervisor();

  supervisor.onSpawners.add([
    ActorSpawner(network, r1.start, [l2_1.end, l3.end, r4.end]),
    ActorSpawner(network, r2_1.start, [l1.end, l3.end, r4.end]),
    ActorSpawner(network, r3.start, [l1.end, l2_1.end, r4.end]),
    ActorSpawner(network, l4.start, [l1.end, l2_1.end, l3.end]),
    ActorSpawner(network, r5.start, [l1.end, l2_1.end, l3.end])
  ]);

  const colors = ['red', 'green', 'blue', 'purple', 'pink'];
  final colorPoints = Set<Point>();

  supervisor.snapshot.listen((snapshot) {
    final CanvasRenderingContext2D context = canvas.getContext('2d');

    context.clearRect(0, 0, 800, 665);

    network.connections.forEach((connection) {
      context.beginPath();
      context.moveTo(connection.start.x, connection.start.y);
      context.lineTo(connection.end.x, connection.end.y);
      context.closePath();
      context.strokeStyle = connection.congestionStateSync.isCongested
          ? 'red'
          : connection.congestionStateSync.isActorLeaving ? 'orange' : 'black';
      context.stroke();

      connection.accepts.forEach((incoming, signs) {
        final lights =
            signs.where((sign) => sign is Stoplight).toList(growable: false);

        lights.forEach((stoplight) =>
            stoplight.canDriveBy.first.then((canDriveBy) {
              context.beginPath();
              context.arc(incoming.end.x, incoming.end.y, 4, 0, 2 * math.pi);
              context.fillStyle =
                  canDriveBy ? 'rgba(0, 255, 0, 0.5)' : 'rgba(255, 0, 0, 0.5)';
              context.fill();
              context.lineWidth = 1;
              context.strokeStyle = 'black';
              context.stroke();
            }));
      });
    });

    snapshot.forEach((actor, point) {
      colorPoints.add(actor.end);

      context.beginPath();
      context.arc(point.x, point.y, 4, 0, 2 * math.pi);
      context.fillStyle =
          colors[colorPoints.toList(growable: false).indexOf(actor.end)];
      context.fill();
      context.lineWidth = 1;
      context.strokeStyle = 'white';
      context.stroke();
    });
  });
}
