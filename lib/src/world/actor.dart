import 'dart:async';
import 'dart:math' as math;

import 'package:rxdart/rxdart.dart';

import 'package:crossroads/src/world/connection.dart';
import 'package:crossroads/src/world/point.dart';
import 'package:crossroads/src/world/traffic_sign.dart';
import 'package:crossroads/src/world/vector.dart';
import 'package:crossroads/src/world/motion/reactive_mixin.dart';

class Actor extends Object with ReactiveMixin {
  final BehaviorSubject<Connection> _onConnection =
      BehaviorSubject<Connection>();
  final BehaviorSubject<Map<Actor, Point>> _onSnapshot =
      BehaviorSubject<Map<Actor, Point>>(seedValue: const <Actor, Point>{});
  final int _normal_speed = 4000;

  Observable<Connection> get connection => _onConnection.stream;

  Connection get connectionSync => _onConnection.value;

  StreamSubscription<void> _onSnapshotSubscription;
  StreamSubscription<bool> _onSwitchSubscription;

  Sink<Map<Actor, Point>> get onSnapshot => _onSnapshot.sink;

  final List<Connection> path;
  final Point start, end;

  bool isDestroyed = false;
  int _currentPathIndex = 0;

  Connection get nextState {
    if (_currentPathIndex < path.length) {
      final connection = path[_currentPathIndex];

      return connection;
    }

    return null;
  }

  Actor(this.path, this.start, this.end) {
    path.first.congested
        .where((state) => !state.isCongested)
        .first
        .whenComplete(() {
      nextConnection(start);

      final localize = (Map<Actor, Point> snapshot) {
        final localMap = <Actor, Point>{};

        snapshot.forEach((actor, point) {
          if (!actor.isDestroyed &&
              actor._onConnection.value == _onConnection.value) {
            localMap[actor] = point;
          }
        });

        return localMap;
      };

      _onSnapshotSubscription = _onSnapshot.stream
          .map(localize)
          .asyncMap(_maybeSlowDown)
          .listen(null);
    });
  }

  void _destroy() {
    super.cleanUp();

    isDestroyed = true;

    _onConnection.close();
    _onSnapshot.close();

    _onSnapshotSubscription?.cancel();
    _onSwitchSubscription?.cancel();
  }

  Future<dynamic> nextConnection(Point entryPoint) async {
    if (_currentPathIndex == path.length) {
      onLinearModifiers.add(const <Vector>[]);

      return _destroy();
    }

    if (_currentPathIndex > 0) {
      await _canSwitchConnection(entryPoint, (bool value) => value);
    }

    final connection = path[_currentPathIndex++];
    final exitPoint = connection.end;

    setPoint(entryPoint);

    onLinearModifiers.add([
      Vector(
          exitPoint.x - entryPoint.x,
          exitPoint.y - entryPoint.y,
          Duration(
              milliseconds:
                  (_normal_speed * connection.totalDistance() / 100).floor()))
    ]);

    _onConnection.add(connection);
  }

  Future<bool> _canSwitchConnection(Point entryPoint, bool test(bool value)) {
    //todo: based on rules, change connection when allowed
    //todo: connection saturation should be a dynamic traffic sign
    final nextConnection = path[_currentPathIndex];
    final signs = nextConnection.accepts[_onConnection.value];
    final congested = nextConnection.congested
        .distinct()
        .where((state) => state.actor != this)
        .map((state) => !state.isCongested);
    final maybeCombineStreams = (List<TrafficSign> signs) => (signs.length > 1)
        ? Observable.combineLatest(
            signs.map((sign) => sign.canDriveBy),
            (List<bool> values) =>
                values.fold(true, (prev, curr) => prev && curr))
        : signs.first.canDriveBy;
    final resolveStream =
        (List<TrafficSign> signs, Observable<bool> congested) =>
            (signs != null && signs.isNotEmpty)
                ? Observable.combineLatest2(
                    congested,
                    maybeCombineStreams(signs),
                    (bool isCongested, bool canDriveBy) =>
                        isCongested && canDriveBy)
                : congested;
    final completer = Completer<bool>();
    final doComplete = (bool value) {
      _onSwitchSubscription.cancel();
      _onSwitchSubscription = null;

      completer.complete(value);
    };

    _onSwitchSubscription = Observable.race([
      onDestroy.stream.map((_) => false),
      resolveStream(signs, congested).where(test)
    ]).take(1).listen(doComplete);

    return completer.future;
  }

  Future<void> _maybeSlowDown(Map<Actor, Point> snapshot) async {
    if (!snapshot.containsKey(this)) return;

    final connection = _onConnection.value;
    final point = snapshot[this];
    final endPoint = connection.end;
    final dy = point.distanceTo(endPoint);
    double dist = 0xffffffff;
    Point obstruction;

    snapshot.forEach((actor, p1) {
      if (actor != this) {
        if (p1.distanceTo(endPoint) < dy) {
          final d = point.distanceTo(p1);

          if (d < dist) {
            dist = d;

            obstruction = p1;
          }
        }
      }
    });

    if (nextState != null &&
        obstruction == null &&
        _currentPathIndex < path.length) {
      final canDriveBy = await _canSwitchConnection(endPoint, (_) => true);

      if (!canDriveBy) {
        obstruction = endPoint;
        dist = dy;
      }
    }

    void applyStop() => onLinearModifiers.add(const <Vector>[]);

    void applyDeceleration() {
      final startPoint = connection.start;
      final dx = connection.end.x == connection.start.x
              ? endPoint.x - startPoint.x
              : obstruction.x - point.x,
          dy = connection.end.y == connection.start.y
              ? endPoint.y - startPoint.y
              : obstruction.y - point.y;

      onLinearModifiers.add([
        Vector(dx, dy, Duration(milliseconds: _normal_speed),
            easing: Easing.sine)
      ]);
    }

    void applyNormal() {
      final startPoint = connection.start;

      onLinearModifiers.add([
        Vector(
            endPoint.x - startPoint.x,
            endPoint.y - startPoint.y,
            Duration(
                milliseconds:
                    (_normal_speed * connection.totalDistance() / 100).floor()))
      ]);
    }

    if (obstruction != null) {
      if (dist < 60) {
        if (dist < math.Random(hashCode).nextInt(5) + 12) {
          applyStop();
        } else {
          applyDeceleration();
        }
      } else {
        applyNormal();
      }
    } else if (connection != path.last) {
      applyNormal();
    }
  }
}
