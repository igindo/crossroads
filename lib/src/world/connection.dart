import 'package:crossroads/src/world/actor.dart';
import 'package:crossroads/src/world/point.dart';
import 'package:crossroads/src/world/traffic_sign.dart';

enum Direction { start_to_end, end_to_start }
enum Speed { freeway, divided, undivided, residential }

class Connection {
  final Point start, end;
  final List<ConnectionConfig> configs;

  const Connection(this.start, this.end, this.configs);

  bool resolveAccess(final ActorType type, final Point entry) {
    for (int i = 0, len = configs.length; i < len; i++) {
      final lane = configs[i];

      if (lane.type == type) {
        switch (lane.direction) {
          case Direction.start_to_end:
            return entry == start;
          case Direction.end_to_start:
            return entry == end;
        }
      }
    }

    return false;
  }

  Point resolveStart(Direction direction) =>
      direction == Direction.start_to_end ? start : end;

  Point resolveEnd(Direction direction) =>
      direction == Direction.start_to_end ? end : start;

  bool resolveIsAtStart(Point point, Direction direction) =>
      direction == Direction.start_to_end ? point == start : point == end;

  bool resolveIsAtEnd(Point point, Direction direction) =>
      (direction == Direction.start_to_end ? point == end : point == start) ||
      resolveStart(direction).distanceTo(point) > totalDistance(direction);

  double totalDistance(Direction direction) =>
      direction == Direction.start_to_end
          ? start.distanceTo(end)
          : end.distanceTo(start);
}

class ConnectionConfig {
  final ActorType type;
  final Direction direction;
  final List<ConnectionLane> lanes;
  final Speed speed;

  const ConnectionConfig(this.type, this.direction, this.lanes, this.speed);
}

class ConnectionLane {
  final List<Connection> adjacentConnections;
  final List<TrafficSign> signs;

  const ConnectionLane(this.adjacentConnections, this.signs);
}
