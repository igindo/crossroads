import 'package:crossroads/crossroads.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    Network network;
    TrafficSupervisor supervisor;
    final scheduler = StoplightScheduler([
      const Duration(seconds: 4),
      const Duration(seconds: 1)
    ]);

    Connection createConnection(Point p1, Point p2, Direction direction) =>
        Connection(p1, p2, [
          ConnectionConfig(
              ActorType.car,
              direction,
              [
                ConnectionLane(
                    null, [Stoplight(scheduler, (int index) => index % 2 == 0)])
              ],
              Speed.undivided)
        ]);

    setUp(() {
      network = Network([
        createConnection(
            const Point(0, 0), const Point(100, 0), Direction.start_to_end),
        createConnection(
            const Point(100, 0), const Point(0, 0), Direction.start_to_end),
        createConnection(
            const Point(100, 0), const Point(200, 0), Direction.start_to_end),
        createConnection(
            const Point(200, 0), const Point(300, 0), Direction.start_to_end),
        createConnection(
            const Point(300, 0), const Point(400, 0), Direction.start_to_end),
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

      supervisor = new TrafficSupervisor();

      supervisor.onSpawners.add([
        ActorSpawner(
            network,
            ActorType.car,
            const Point(0, 0),
            const [
              Point(100, 100),
              Point(200, 100),
              Point(300, 100),
              Point(400, 100)
            ]),
        ActorSpawner(
            network,
            ActorType.car,
            const Point(400, 0),
            const [
              Point(0, 100),
              Point(100, 100),
              Point(200, 100),
              Point(300, 100)
            ])
      ]);
    });

    test('empty grid is inaccessible', () async {
      await expectLater(
          supervisor.snapshot.where((data) => data == null), emitsDone);
    });
  });
}
