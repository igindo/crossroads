import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

import 'package:crossroads/src/world/motion/easing.dart' as easing;
import 'package:crossroads/src/world/point.dart';
import 'package:crossroads/src/world/vector.dart';

abstract class ReactiveMixin {
  StreamController<Vector> _onVector = new StreamController<Vector>();
  BehaviorSubject<Iterable<Vector>> _onLinearModifiers =
      new BehaviorSubject<Iterable<Vector>>(seedValue: const []);
  BehaviorSubject<Iterable<Timestamped<Vector>>> _onVectorTimes =
      new BehaviorSubject<Iterable<Timestamped<Vector>>>(seedValue: const []);

  StreamSubscription<Iterable<Timestamped<Vector>>> _vectorTimesSubscription;
  StreamSubscription<Point> _positionSubscription;

  Sink<Vector> get onVector => _onVector.sink;
  Sink<Iterable<Vector>> get onLinearModifiers => _onLinearModifiers.sink;

  final Point _p0 = const Point(.0, .0);
  Point _p1 = const Point(.0, .0);

  void setPoint(Point value) => _p1 = value;

  void cleanUp() {
    _vectorTimesSubscription?.cancel();
    _positionSubscription?.cancel();

    _onVector.close();
    _onVectorTimes.close();
    _onLinearModifiers.close();
  }

  Observable<Point> sampledPosition(final Stream sampler) {
    _vectorTimesSubscription = Observable(_onVector.stream)
        .timestamp()
        .map((vectorTime) => List<Timestamped<Vector>>.unmodifiable(
            List<Timestamped<Vector>>.from(_onVectorTimes.value)
              ..add(vectorTime)))
        .listen(_onVectorTimes.add);

    _positionSubscription = Observable(sampler)
        .timestamp()
        .bufferCount(2, 1)
        .map(_pairTimeDeltaMs)
        .switchMap((durationMs) =>
            _onLinearModifiers.take(1).map((list) => Tuple2(durationMs, list)))
        .map((tuple) => _p1.add(tuple.item2.fold(
            _p0,
            (Point prev, Vector current) =>
                prev.add(_applyEasing(tuple.item1, current)))))
        .listen(setPoint);

    return _onVectorTimes
        .sample(sampler)
        .map(_splitTimeFrame())
        .doOnData((tuple) => setPoint(_p1.add(tuple.item2)))
        .map((tuple) => tuple.item1)
        .doOnData(_onVectorTimes.add)
        .map((vectorTimes) => vectorTimes.fold(_p1, _acc))
        .map((point) => point.normalize());
  }

  Point _linear(int durationMs, Vector vector) =>
      easing.linear(durationMs, vector, vector.duration.inMilliseconds);

  Point _sine(int durationMs, Vector vector) =>
      easing.easeOut(durationMs, vector, vector.duration.inMilliseconds);

  Point _applyEasing(int durationMs, Vector vector) =>
      vector.easing == Easing.sine
          ? _sine(durationMs, vector)
          : _linear(durationMs, vector);

  Point _applyCompletedEasing(Vector vector) =>
      _applyEasing(vector.duration.inMilliseconds, vector);

  Point _acc(Point prev, Timestamped<Vector> vectorTime) =>
      prev.add(_applyEasing(_vectorDeltaMs(vectorTime), vectorTime.value));

  int _pairTimeDeltaMs(List<Timestamped> pair) =>
      pair.last.timestamp.millisecondsSinceEpoch -
      pair.first.timestamp.millisecondsSinceEpoch;

  int _vectorDeltaMs(Timestamped<Vector> vectorTime) =>
      DateTime.now().millisecondsSinceEpoch -
      vectorTime.timestamp.millisecondsSinceEpoch;

  Tuple2<Iterable<Timestamped<Vector>>, Point> Function(
          Iterable<Timestamped<Vector>>)
      _splitTimeFrame() => (final Iterable<Timestamped<Vector>> list) {
            final openVectorTimes = <Timestamped<Vector>>[];
            final currentTime = DateTime.now();
            var point = _p0;

            for (var i = 0, len = list.length; i < len; i++) {
              final vectorTime = list.elementAt(i);
              final vector = vectorTime.value;
              final ty = vectorTime.timestamp.add(vector.duration);
              final isPlaying = ty.isAfter(currentTime);

              if (isPlaying)
                openVectorTimes.add(vectorTime);
              else
                point = point.add(_applyCompletedEasing(vector));
            }

            return Tuple2(openVectorTimes, point);
          };
}
