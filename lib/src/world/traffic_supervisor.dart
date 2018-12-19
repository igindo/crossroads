import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

import 'package:crossroads/src/world/actor.dart';
import 'package:crossroads/src/world/actor_spawner.dart';
import 'package:crossroads/src/world/point.dart';

class TrafficSupervisor {
  final BehaviorSubject<Map<Actor, Point>> _onSnapshot =
      BehaviorSubject<Map<Actor, Point>>(seedValue: const <Actor, Point>{});
  final StreamController<ActorSpawner> _onSpawner =
      StreamController<ActorSpawner>();
  final Stream<void> sampler =
      Stream.periodic(const Duration(milliseconds: 20), (_) => null)
          .asBroadcastStream();

  Sink<ActorSpawner> get onSpawner => _onSpawner.sink;

  Observable<Map<Actor, Point>> get snapshot => _onSnapshot.stream;

  TrafficSupervisor() {
    _init();
  }

  void _init() {
    final maybeSwitchConnection = (Actor actor) => (Point point) async {
          final state = await actor.state.first,
              connection = state.connection,
              direction = state.direction;

          if (connection.resolveIsAtEnd(point, direction)) {
            await actor.nextConnection(connection.resolveEnd(direction));
          }

          return point;
        };
    final toPointAndState = (Actor actor) =>
        (Point point) => actor.state.map((state) => Tuple2(point, state));
    final toMappedActor = (Actor actor) => (Tuple2<Point, ActorState> tuple) =>
        MappedActor(actor, tuple.item1, tuple.item2);
    final combiner = (Map<Actor, Point> snapshot, MappedActor mappedActor) =>
        Tuple2(
            mappedActor.actor,
            Map<Actor, Point>.from(snapshot)
              ..[mappedActor.actor] = mappedActor.point);
    final handleSnapshot = (Tuple2<Actor, Map<Actor, Point>> tuple) {
      final actorMap = <Actor, Point>{}, nextActorMap = <Actor, Point>{};
      final nextState = tuple.item1.nextState;

      tuple.item2.forEach((actor, point) {
        if (actor.stateSync.isSameState(tuple.item1.stateSync)) {
          actorMap[actor] = point;
        } else if (nextState != null &&
            actor.stateSync.isSameState(nextState)) {
          nextActorMap[actor] = point;
        }
      });

      _onSnapshot.add(tuple.item2);

      tuple.item1.onSnapshot.add(actorMap);
      tuple.item1.onNextSnapshot.add(nextActorMap);
    };

    Observable.zip2(
            _onSnapshot.stream,
            Observable(_onSpawner.stream)
                .flatMap((spawner) => spawner.next)
                .flatMap((actor) => actor
                    .sampledPosition(sampler)
                    .asyncMap(maybeSwitchConnection(actor))
                    .switchMap(toPointAndState(actor))
                    .map(toMappedActor(actor))),
            combiner)
        .listen(handleSnapshot);
  }
}

class MappedActor {
  final Actor actor;
  final Point point;
  final ActorState state;

  MappedActor(this.actor, this.point, this.state);
}
