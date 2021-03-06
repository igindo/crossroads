import 'dart:async';
import 'dart:math' as math;

import 'package:rxdart/rxdart.dart';

import 'package:crossroads/src/world/actor.dart';
import 'package:crossroads/src/world/connection.dart';
import 'package:crossroads/src/world/network.dart';
import 'package:crossroads/src/world/path_finder.dart';
import 'package:crossroads/src/world/point.dart';

class ActorSpawner {
  final Network network;
  final Point entryPoint;
  final List<Point> exitPoints;
  final StreamController<bool> _onClose = new StreamController<bool>();
  final List<ResolvedConnection> resolvedConnections = <ResolvedConnection>[];

  Observable<Actor> _next;
  Observable<Actor> get next => _next ??= Observable(randInterval())
      .takeUntil(_onClose.stream)
      .map(nextActor)
      .asyncMap((actor) => actor.init().then((_) => actor));

  ActorSpawner(this.network, this.entryPoint, this.exitPoints);

  Actor nextActor(final _) {
    final random = new math.Random();
    final exitPoint = exitPoints[random.nextInt(exitPoints.length)];
    final resolvedConnection = resolvedConnections.firstWhere(
        (res) => res.entryPoint == entryPoint && res.exitPoint == exitPoint,
        orElse: () => ResolvedConnection(entryPoint, exitPoint,
            resolveConnection(network, entryPoint, exitPoint)));

    if (!resolvedConnections.contains(resolvedConnection)) {
      resolvedConnections.add(resolvedConnection);
    }

    return Actor(resolvedConnection.path, entryPoint, exitPoint);
  }

  void close() {
    _onClose.add(true);

    _onClose.close();
  }

  Stream<bool> randInterval() async* {
    yield await Future.delayed(
        Duration(milliseconds: math.Random().nextInt(4000) + 4000), () => true);
    yield* randInterval();
  }
}

class ResolvedConnection {
  final Point entryPoint, exitPoint;
  final List<Connection> path;

  ResolvedConnection(this.entryPoint, this.exitPoint, this.path);
}
