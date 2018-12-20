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
  final Point entryPoint;
  final List<Point> exitPoints;
  final StreamController<bool> _onClose = new StreamController<bool>();

  Observable<Actor> _next;
  Observable<Actor> get next =>
      _next ??= Observable(randInterval())
          .takeUntil(_onClose.stream)
          .map(nextActor);

  ActorSpawner(this.network, this.forType, this.entryPoint, this.exitPoints);

  Actor nextActor(final _) {
    final random = new math.Random();
    final exitPoint = exitPoints[random.nextInt(exitPoints.length)];

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

  Stream<bool> randInterval() async* {
    yield await Future.delayed(Duration(milliseconds: math.Random().nextInt(1500) + 500), () => true);
    yield* randInterval();
  }
}
