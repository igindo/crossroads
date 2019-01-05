import 'package:rxdart/rxdart.dart';

import 'package:crossroads/src/world/connection.dart';

abstract class TrafficSign {
  Observable<bool> get canDriveBy;
}

class Stoplight implements TrafficSign {
  final StoplightScheduler scheduler;
  final bool Function(int) onSchedule;

  final BehaviorSubject<bool> _onCanDriveBy = BehaviorSubject<bool>();

  @override
  Observable<bool> get canDriveBy => _onCanDriveBy.stream;

  Stoplight(this.scheduler, this.onSchedule) {
    scheduler.interval.map(onSchedule).listen(_onCanDriveBy.add);
  }
}

class StoplightScheduler {
  final BehaviorSubject<int> _onInterval = BehaviorSubject<int>();

  Observable<int> get interval => _onInterval.stream;

  final List<Duration> intervals;

  StoplightScheduler(this.intervals) {
    _asStream().listen(_onInterval.add);
  }

  Stream<int> _asStream() async* {
    for (var i = 0, len = intervals.length; i < len; i++) {
      yield i;

      await Future.delayed(intervals[i]);
    }

    yield* _asStream();
  }
}

class GivePriority implements TrafficSign {
  final List<Connection> priorityConnections;

  final BehaviorSubject<bool> _onCanDriveBy = BehaviorSubject<bool>();

  @override
  Observable<bool> get canDriveBy => _onCanDriveBy.stream;

  GivePriority(this.priorityConnections) {
    final stream = priorityConnections.length > 1
        ? Observable.combineLatest(
            priorityConnections.map((connection) => connection.congested),
            (List<CongestionState> values) =>
                values.fold(true, (prev, curr) => prev && !curr.isActorLeaving))
        : priorityConnections.first.congested.map((cs) => !cs.isActorLeaving);

    stream
        .debounce(const Duration(milliseconds: 120))
        .listen(_onCanDriveBy.add);
  }
}
