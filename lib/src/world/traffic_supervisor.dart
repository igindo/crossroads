import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

import 'package:crossroads/src/world/actor.dart';
import 'package:crossroads/src/world/actor_spawner.dart';
import 'package:crossroads/src/world/point.dart';

class TrafficSupervisor {
  final BehaviorSubject<Map<Actor, Point>> _onSnapshot =
      BehaviorSubject<Map<Actor, Point>>(seedValue: const <Actor, Point>{});
  final StreamController<List<ActorSpawner>> _onSpawners =
      StreamController<List<ActorSpawner>>();
  final Stream<void> sampler =
      Stream.periodic(const Duration(milliseconds: 30), (_) => null)
          .asBroadcastStream();

  Sink<List<ActorSpawner>> get onSpawners => _onSpawners.sink;

  Observable<Map<Actor, Point>> get snapshot => _onSnapshot.stream;

  TrafficSupervisor() {
    _init();
  }

  void _init() {
    final maybeSwitchConnection = (Actor actor) => (Point point) async* {
          final state = await actor.state.first,
              connection = state.connection,
              direction = state.direction;

          if (connection.resolveIsAtEnd(point, direction)) {
            await actor.nextConnection(connection.resolveEnd(direction));
          }

          yield point;
        };
    final toPointAndState = (Actor actor) =>
        (Point point) => actor.state.map((state) => Tuple2(point, state));
    final toMappedActor = (Actor actor) => (Tuple2<Point, ActorState> tuple) =>
        MappedActor(actor, tuple.item1, tuple.item2);
    final onDestroy = (Actor actor) =>
        actor.destroy.take(1).map((_) => MappedActor.asDeletion(actor));
    final combiner = (Map<Actor, Point> snapshot, MappedActor mappedActor) {
      final transformed = Map<Actor, Point>.from(snapshot);
      final isDeletion = mappedActor.point == null;

      if (isDeletion) {
        transformed.remove(mappedActor.actor);
      } else {
        transformed[mappedActor.actor] = mappedActor.point;
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
                  .switchMap(toPointAndState(actor))
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
  final ActorState state;

  MappedActor(this.actor, this.point, this.state);

  factory MappedActor.asDeletion(Actor actor) => MappedActor(actor, null, null);
}
