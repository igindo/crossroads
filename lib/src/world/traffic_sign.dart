import 'package:rxdart/rxdart.dart';

abstract class TrafficSign {
  Observable<bool> get canDriveBy;
}

class Stoplight implements TrafficSign {
  final StoplightScheduler scheduler;
  final bool Function(int) onSchedule;

  final BehaviorSubject<bool> _onCanDriveBy = BehaviorSubject<bool>();

  Observable<bool> _canDriveBy;
  @override
  Observable<bool> get canDriveBy {
    if (_canDriveBy == null) {
      scheduler.interval.map(onSchedule).listen(_onCanDriveBy.add);

      _canDriveBy = _onCanDriveBy.stream;
    }

    return _canDriveBy;
  }

  Stoplight(this.scheduler, this.onSchedule);
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
      yield i;print(i);

      await Future.delayed(intervals[i]);
    }

    yield* _asStream();
  }
}
