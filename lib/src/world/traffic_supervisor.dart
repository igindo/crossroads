import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

import 'package:crossroads/src/world/actor.dart';
import 'package:crossroads/src/world/actor_spawner.dart';
import 'package:crossroads/src/world/connection.dart';
import 'package:crossroads/src/world/point.dart';

class TrafficSupervisor {
  final BehaviorSubject<Map<Actor, Point>> _onSnapshot =
      BehaviorSubject<Map<Actor, Point>>(seedValue: const <Actor, Point>{});
  final StreamController<List<ActorSpawner>> _onSpawners =
      StreamController<List<ActorSpawner>>();
  final Stream<void> sampler =
      Stream.periodic(const Duration(milliseconds: 60)).asBroadcastStream();

  Sink<List<ActorSpawner>> get onSpawners => _onSpawners.sink;

  Observable<Map<Actor, Point>> get snapshot => _onSnapshot.stream;

  TrafficSupervisor() {
    _init();
  }

  void _init() {
    final maybeSwitchConnection = (Actor actor) => (ConnectionPoint cp) async* {
          if (cp.connection.resolveIsAtEnd(cp.point)) {
            await actor.nextConnection(cp.connection.end);
          }

          yield cp;
        };
    final toConnectionPoint = (Actor actor) => (Point point) => actor.connection
        .take(1)
        .map((connection) => ConnectionPoint(point, connection));
    final toMappedActor =
        (Actor actor) => (ConnectionPoint cp) => MappedActor(actor, cp);
    final combiner = (Map<Actor, Point> snapshot, MappedActor mappedActor) {
      final transformed = Map<Actor, Point>.from(snapshot);
      final isDeletion = mappedActor.cp == null;

      if (isDeletion) {
        transformed.remove(mappedActor.actor);
      } else {
        final isCongested =
            mappedActor.cp.connection.start.distanceTo(mappedActor.cp.point) <
                10;
        transformed[mappedActor.actor] = mappedActor.cp.point;

        mappedActor.cp.connection.onCongested.add(isCongested
            ? CongestionState(mappedActor.actor, true)
            : const CongestionState(null, false));
      }

      return Tuple2(isDeletion ? null : mappedActor.actor, transformed);
    };
    final handleSnapshot = (Tuple2<Actor, Map<Actor, Point>> tuple) {
      _onSnapshot.add(tuple.item2);

      tuple.item1?.onSnapshot?.add(tuple.item2);
    };
    final onNext = Observable(_onSpawners.stream)
        .expand((spawners) => spawners)
        .flatMap((spawner) => spawner.next);
    final onPosition = (Actor actor) => actor
        .sampledPosition(sampler)
        .exhaustMap(toConnectionPoint(actor))
        .exhaustMap(maybeSwitchConnection(actor))
        .map(toMappedActor(actor))
        .takeUntil(actor.onDestroy.stream);
    final onDestroy = (Actor actor) => actor.onDestroy.stream
        .take(1)
        .map((_) => MappedActor.asDeletion(actor));
    final onActorEvents = (Actor actor) =>
        Observable.merge([onPosition(actor), onDestroy(actor)]);

    Observable.zip2(_onSnapshot.stream, onNext.flatMap(onActorEvents), combiner)
        .listen(handleSnapshot);
  }
}

class ConnectionPoint {
  final Point point;
  final Connection connection;

  ConnectionPoint(this.point, this.connection);
}

class MappedActor {
  final Actor actor;
  final ConnectionPoint cp;

  MappedActor(this.actor, this.cp);

  factory MappedActor.asDeletion(Actor actor) => MappedActor(actor, null);
}
