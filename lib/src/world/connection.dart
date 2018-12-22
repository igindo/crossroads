import 'package:rxdart/rxdart.dart';

import 'package:crossroads/src/world/actor.dart';
import 'package:crossroads/src/world/point.dart';
import 'package:crossroads/src/world/traffic_sign.dart';

enum Speed { freeway, divided, undivided, residential }

class Connection {
  final Point start, end;
  final Map<Connection, List<TrafficSign>> accepts;
  final Speed speed;
  final BehaviorSubject<CongestionState> _onCongested =
      BehaviorSubject<CongestionState>(seedValue: const CongestionState.none());
  double _totalDistance;

  // todo: for debug only
  CongestionState get congestionStateSync => _onCongested.value;

  Sink<CongestionState> get onCongested => _onCongested.sink;

  Observable<CongestionState> _congested;
  Observable<CongestionState> get congested =>
      _congested ??= _onCongested.stream.distinct((sA, sB) =>
          sA.isCongested == sB.isCongested &&
          sA.isActorLeaving == sB.isActorLeaving);

  Connection(this.start, this.end, this.speed, this.accepts);

  bool resolveAccess(final Point entry) => entry == start;

  bool resolveIsAtStart(Point point) {
    final floored = point.floored();

    return floored == start || end.distanceTo(floored) > totalDistance();
  }

  bool resolveIsAtEnd(Point point) {
    final ceiled = point.ceiled();

    return ceiled == end || start.distanceTo(ceiled) > totalDistance();
  }

  double totalDistance() => _totalDistance ??= start.distanceTo(end);
}

class CongestionState {
  final Actor congestionActor, leavingActor;
  final bool isCongested;
  final bool isActorLeaving;

  const CongestionState(this.congestionActor, this.leavingActor,
      this.isCongested, this.isActorLeaving);

  const CongestionState.none()
      : this.congestionActor = null,
        this.leavingActor = null,
        this.isCongested = false,
        this.isActorLeaving = false;

  CongestionState updateWith(Actor actor, bool congestion, bool leaving) {
    final sameCongestion = actor == congestionActor,
        sameLeaving = actor == leavingActor;

    return CongestionState(
        congestion ? actor : (sameCongestion ? null : congestionActor),
        leaving ? actor : (sameLeaving ? null : leavingActor),
        congestion ? true : (sameCongestion ? false : isCongested),
        leaving ? true : (sameLeaving ? false : isActorLeaving));
  }
}
