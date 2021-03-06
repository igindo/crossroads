import 'package:crossroads/src/world/connection.dart';
import 'package:crossroads/src/world/point.dart';

class Network {
  final List<Connection> connections;
  final Map<Point, List<Connection>> pointMapped;

  Network(this.connections) : pointMapped = _toPointMapped(connections);

  static Map<Point, List<Connection>> _toPointMapped(
      final List<Connection> connections) {
    final map = <Point, List<Connection>>{};

    for (int i = 0, len = connections.length; i < len; i++) {
      final connection = connections[i];

      map.putIfAbsent(connection.start, () => <Connection>[]);
      map.putIfAbsent(connection.end, () => <Connection>[]);

      map[connection.start].add(connection);
      map[connection.end].add(connection);
    }

    return map;
  }

  Iterable<Connection> possibleConnections(final Point start) =>
      pointMapped[start].where((connector) => connector.start == start);
}
