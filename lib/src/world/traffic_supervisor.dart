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
      Stream.periodic(const Duration(milliseconds: 60), (_) => null)
          .asBroadcastStream();

  Sink<List<ActorSpawner>> get onSpawners => _onSpawners.sink;

  Observable<Map<Actor, Point>> get snapshot => _onSnapshot.stream;

  TrafficSupervisor() {
    _init();
  }

  void _init() {
    final maybeSwitchConnection = (Actor actor) => (Point point) async* {
          final state = await actor.state.first, connection = state;

          if (connection.resolveIsAtEnd(point)) {
            await actor.nextConnection(connection.end);
          }

          yield point;
        };
    final toMappedActor =
        (Actor actor) => (Point point) => MappedActor(actor, point);
    final onDestroy = (Actor actor) =>
        actor.destroy.take(1).map((_) => MappedActor.asDeletion(actor));
    final combiner = (Map<Actor, Point> snapshot, MappedActor mappedActor) {
      final transformed = Map<Actor, Point>.from(snapshot);
      final isDeletion = mappedActor.point == null;

      if (isDeletion) {
        transformed.remove(mappedActor.actor);
      } else {
        final isCongested =
            mappedActor.actor.stateSync.start.distanceTo(mappedActor.point) <
                10;
        transformed[mappedActor.actor] = mappedActor.point;

        mappedActor.actor.stateSync.onCongested.add(isCongested
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
        .flatMap((spawner) => spawner.next)
        .asBroadcastStream();

    Observable.zip2(
            _onSnapshot.stream,
            Observable.merge([
              onNext.flatMap((actor) => actor
                  .sampledPosition(sampler)
                  .exhaustMap(maybeSwitchConnection(actor))
                  .map(toMappedActor(actor))
                  .takeUntil(actor.destroy)),
              onNext.flatMap(onDestroy)
            ]),
            combiner)
        .listen(handleSnapshot);
  }
}

class MappedActor {
  final Actor actor;
  final Point point;

  MappedActor(this.actor, this.point);

  factory MappedActor.asDeletion(Actor actor) => MappedActor(actor, null);
}
