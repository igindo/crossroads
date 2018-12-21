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
      BehaviorSubject<CongestionState>(
          seedValue: const CongestionState(null, false));

  Sink<CongestionState> get onCongested => _onCongested.sink;

  Observable<CongestionState> _congested;
  Observable<CongestionState> get congested =>
      _congested ??= _onCongested.stream
          .distinct((sA, sB) => sA.isCongested == sB.isCongested);

  Connection(this.start, this.end, this.speed, this.accepts);

  bool resolveAccess(final Point entry) => entry == start;

  bool resolveIsAtStart(Point point) =>
      point == start || end.distanceTo(point) > totalDistance();

  bool resolveIsAtEnd(Point point) =>
      point == end || start.distanceTo(point) > totalDistance();

  double totalDistance() => start.distanceTo(end);
}

class CongestionState {
  final Actor actor;
  final bool isCongested;

  const CongestionState(this.actor, this.isCongested);
}
