import 'package:crossroads/crossroads.dart';

void main() {
  Network network;
  TrafficSupervisor supervisor;
  final scheduler = StoplightScheduler([
    const Duration(seconds: 8),
    const Duration(seconds: 2),
    const Duration(seconds: 8),
    const Duration(seconds: 2)
  ]);

  Connection createConnection(Point p1, Point p2, Direction direction,
          {Map<Connection, List<TrafficSign>> accepts =
              const <Connection, List<TrafficSign>>{}}) =>
      Connection(p1, p2, [
        ConnectionConfig(ActorType.car, direction, accepts, Speed.undivided)
      ]);

  const c1234 = [
    Point(380, 436),
    Point(384, 440),
    Point(399, 433),
    Point(391, 419)
  ];

  final r1 = createConnection(
          const Point(216, 665), c1234[1], Direction.start_to_end),
      l1 = createConnection(
          c1234[0], const Point(201, 665), Direction.start_to_end),
      r2 = createConnection(
          const Point(460, 516), c1234[2], Direction.start_to_end),
      r2_1 = createConnection(
          const Point(547, 665), r2.start, Direction.start_to_end),
      l2 = createConnection(
          c1234[1], const Point(434, 503), Direction.start_to_end),
      l2_1 = createConnection(
          l2.end, const Point(531, 665), Direction.start_to_end),
      r3 = createConnection(
          const Point(731, 473), c1234[3], Direction.start_to_end),
      l3 = createConnection(
          c1234[2], const Point(731, 488), Direction.start_to_end),
      r4 = createConnection(
          c1234[3], const Point(243, 285), Direction.start_to_end),
      l4 = createConnection(
          const Point(225, 290), c1234[0], Direction.start_to_end),
      r1_l3 =
          createConnection(r1.end, l3.start, Direction.start_to_end, accepts: {
    r1: [Stoplight(scheduler, (i) => i == 0)]
  }),
      r1_r4 =
          createConnection(r1.end, r4.start, Direction.start_to_end, accepts: {
    r1: [Stoplight(scheduler, (i) => i == 0)]
  }),
      r2_l1 =
          createConnection(r2.end, l1.start, Direction.start_to_end, accepts: {
    r2: [Stoplight(scheduler, (i) => i == 2)]
  }),
      r2_r4 =
          createConnection(r2.end, r4.start, Direction.start_to_end, accepts: {
    r2: [Stoplight(scheduler, (i) => i == 2)]
  }),
      r3_l1 =
          createConnection(r3.end, l1.start, Direction.start_to_end, accepts: {
    r3: [Stoplight(scheduler, (i) => i == 0)]
  }),
      r3_l2 =
          createConnection(r3.end, l2.start, Direction.start_to_end, accepts: {
    r3: [Stoplight(scheduler, (i) => i == 0)]
  }),
      r3_r4 =
          createConnection(r3.end, r4.start, Direction.start_to_end, accepts: {
    r3: [Stoplight(scheduler, (i) => i == 0)]
  }),
      l4_l2 =
          createConnection(l4.end, l2.start, Direction.start_to_end, accepts: {
    l4: [Stoplight(scheduler, (i) => i == 2)]
  }),
      l4_l3 =
          createConnection(l4.end, l3.start, Direction.start_to_end, accepts: {
    l4: [Stoplight(scheduler, (i) => i == 2)]
  });

  network = Network([
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
    r1_l3,
    r2_l1,
    r3_l1,
    r3_l2,
    r1_r4,
    r2_r4,
    r3_r4,
    l4_l2,
    l4_l3
  ]);

  supervisor = new TrafficSupervisor();

  supervisor.onSpawners.add([
    ActorSpawner(network, ActorType.car, r1.start, [l2_1.end, l3.end, r4.end]),
    ActorSpawner(network, ActorType.car, r2_1.start, [l1.end, l3.end, r4.end]),
    ActorSpawner(network, ActorType.car, r3.start, [l1.end, l2_1.end, r4.end]),
    ActorSpawner(network, ActorType.car, l4.start, [l1.end, l2_1.end, l3.end])
  ]);

  supervisor.snapshot.throttle(const Duration(seconds: 1)).listen((snapshot) {
    print('${snapshot.keys.length} actors');
  });
}
