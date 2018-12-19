import 'dart:async';
import 'dart:math' as math;

import 'package:rxdart/rxdart.dart';

import 'package:crossroads/src/world/actor.dart';
import 'package:crossroads/src/world/network.dart';
import 'package:crossroads/src/world/path_finder.dart';
import 'package:crossroads/src/world/point.dart';

class ActorSpawner {
  final Network network;
  final ActorType forType;
  final List<Point> entryPoints, exitPoints;
  final StreamController<bool> _onClose = new StreamController<bool>();

  Observable<Actor> _next;
  Observable<Actor> get next =>
      _next ??= Observable.periodic(const Duration(milliseconds: 750))
          .takeUntil(_onClose.stream)
          .map(nextActor);

  ActorSpawner(this.network, this.forType, this.entryPoints, this.exitPoints);

  Actor nextActor(final _) {
    final random = new math.Random();
    final entryPoint = entryPoints[random.nextInt(entryPoints.length)],
        exitPoint = exitPoints[random.nextInt(exitPoints.length)];
    print('$entryPoint $exitPoint');
    return Actor(
        forType,
        resolveConnection(network, entryPoint, exitPoint, forType),
        entryPoint,
        exitPoint);
  }

  void close() {
    _onClose.add(true);

    _onClose.close();
  }
}
