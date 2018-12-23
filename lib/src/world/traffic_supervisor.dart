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
  final Stream<void> sampler;
  Map<Connection, CongestionState> activeCongestion =
      <Connection, CongestionState>{};

  Sink<List<ActorSpawner>> get onSpawners => _onSpawners.sink;

  Observable<Map<Actor, Point>> get snapshot => _onSnapshot.stream;

  TrafficSupervisor(this.sampler) {
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
        final d0 = mappedActor.cp.connection.start
                .distanceTo(mappedActor.cp.point),
            d1 = mappedActor.cp.connection.end.distanceTo(mappedActor.cp.point);
        final isCongested = d0 < 10, isActorLeaving = d1 < 40;
        final oldCs = mappedActor.cp.connection.congestionStateSync ??
            const CongestionState.none();
        final cs =
            oldCs.updateWith(mappedActor.actor, isCongested, isActorLeaving);

        transformed[mappedActor.actor] = mappedActor.cp.point;

        mappedActor.cp.connection.onCongested.add(cs);
        activeCongestion[mappedActor.cp.connection] = cs;

        activeCongestion.forEach((connection, cs) {
          var transformed = cs;

          if (transformed.congestionActor != null &&
              connection != transformed.congestionActor.connectionSync) {
            transformed = transformed.updateWith(
                transformed.congestionActor, false, false);
          }

          if (transformed.leavingActor != null &&
              connection != transformed.leavingActor.connectionSync) {
            transformed =
                transformed.updateWith(transformed.leavingActor, false, false);
          }

          connection.onCongested.add(transformed);
        });
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
        .sampledPosition(sampler) // move forward in time
        .exhaustMap(toConnectionPoint(actor)) // get the position
        .exhaustMap(
            maybeSwitchConnection(actor)) // maybe switch to another vector
        .map(toMappedActor(actor)) // actor, position value-pair
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
