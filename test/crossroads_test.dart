import 'package:crossroads/crossroads.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    Network network;
    TrafficSupervisor supervisor;
    ActorSpawner spawner;

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

    setUp(() {
      network = Network([
        createConnection(
            const Point(0, 0), const Point(10, 0), Direction.start_to_end),
        createConnection(
            const Point(10, 0), const Point(20, 0), Direction.start_to_end),
        createConnection(
            const Point(20, 0), const Point(30, 0), Direction.start_to_end),
        createConnection(
            const Point(30, 0), const Point(40, 0), Direction.start_to_end),
        createConnection(
            const Point(0, 0), const Point(0, 10), Direction.start_to_end),
        createConnection(
            const Point(10, 0), const Point(10, 10), Direction.start_to_end),
        createConnection(
            const Point(20, 0), const Point(20, 10), Direction.start_to_end),
        createConnection(
            const Point(30, 0), const Point(30, 10), Direction.start_to_end),
        createConnection(
            const Point(40, 0), const Point(40, 10), Direction.start_to_end),
      ]);

      spawner = new ActorSpawner(
          network, ActorType.car, const Point(10, 0), const [Point(40, 10)]);

      supervisor = new TrafficSupervisor()..onSpawner.add(spawner);
    });

    test('empty grid is inaccessible', () async {
      print(resolveConnection(
              network, const Point(10, 0), const Point(40, 10), ActorType.car)
          .map((connection) =>
              'from: (x: ${connection.start.x}, y: ${connection.start.y}), to: (x: ${connection.end.x}, y: ${connection.end.y})'));

      supervisor.snapshot.listen((data) => print(data));

      await expectLater(
          supervisor.snapshot
              .doOnData((data) => print(data))
              .where((data) => data == null),
          emitsDone);
    });
  });
}
