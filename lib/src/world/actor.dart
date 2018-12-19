import 'dart:async';
import 'dart:math' as math;

import 'package:rxdart/rxdart.dart';

import 'package:crossroads/src/world/connection.dart';
import 'package:crossroads/src/world/point.dart';
import 'package:crossroads/src/world/vector.dart';
import 'package:crossroads/src/world/traffic_sign.dart';
import 'package:crossroads/src/world/motion/reactive_mixin.dart';

enum ActorType { car, bike, pedestrian }

class Actor extends Object with ReactiveMixin {
  final BehaviorSubject<ActorState> _onState = BehaviorSubject<ActorState>();
  final BehaviorSubject<Map<Actor, Point>> _onSnapshot =
      BehaviorSubject<Map<Actor, Point>>(seedValue: const <Actor, Point>{});
  final StreamController<bool> _onDestroy = StreamController<bool>.broadcast();
  static const duration = const Duration(seconds: 1);

  StreamSubscription<void> _onSnapshotSubscription;

  Sink<Map<Actor, Point>> get onSnapshot => _onSnapshot.sink;

  Stream<bool> get destroy => _onDestroy.stream;

  Observable<ActorState> get state => _onState.stream;

  ActorState get stateSync => _onState.value;

  final ActorType type;
  final Iterable<Connection> path;
  final Point start, end;

  bool isDestroyed = false;
  int _currentPathIndex = 0;

  ActorState get nextState {
    if (_currentPathIndex < path.length) {
      final connection = path.elementAt(_currentPathIndex);
      final isConnectionInverted =
          _onState.value.connection.resolveEnd(_onState.value.direction) ==
              connection.end;
      final direction = isConnectionInverted
          ? Direction.end_to_start
          : Direction.start_to_end;

      return ActorState(connection, direction);
    }

    return null;
  }

  Actor(this.type, this.path, this.start, this.end) {
    nextConnection(start);

    final localize = (Map<Actor, Point> snapshot) {
      final localMap = <Actor, Point>{};

      snapshot.forEach((actor, point) {
        if (actor._onState.value.isSameState(_onState.value)) {
          localMap[actor] = point;
        }
      });

      return localMap;
    };

    _onSnapshotSubscription =
        _onSnapshot.stream.map(localize).asyncMap(_maybeSlowDown).listen(null);
  }

  void _destroy() {
    isDestroyed = true;

    _onDestroy.add(true);

    _onState.close();
    _onSnapshot.close();
    _onDestroy.close();

    _onSnapshotSubscription?.cancel();
  }

  Future<dynamic> nextConnection(Point entryPoint) async {
    if (_currentPathIndex == path.length) {
      onLinearModifiers.add(const <Vector>[]);

      return _destroy();
    }

    if (_currentPathIndex > 0) {
      await _canSwitchConnection(entryPoint, (bool value) => value);
    }

    final connection = path.elementAt(_currentPathIndex++);
    final isConnectionInverted = entryPoint == connection.end;
    final direction =
        isConnectionInverted ? Direction.end_to_start : Direction.start_to_end;
    final exitPoint = isConnectionInverted ? connection.start : connection.end;

    setPoint(entryPoint);

    onLinearModifiers.add([
      Vector(exitPoint.x - entryPoint.x, exitPoint.y - entryPoint.y, duration)
    ]);

    _onState.add(ActorState(connection, direction));
  }

  Future<bool> _canSwitchConnection(Point entryPoint, bool test(bool value)) {
    //todo: based on rules, change connection when allowed
    //todo: connection saturation should be a dynamic traffic sign
    final nextConnection = path.elementAt(_currentPathIndex);
    final isConnectionInverted = entryPoint == nextConnection.end;
    final direction =
        isConnectionInverted ? Direction.end_to_start : Direction.start_to_end;
    List<TrafficSign> signs;

    for (var i = 0, len = nextConnection.configs.length; i < len; i++) {
      final config = nextConnection.configs[i];

      if (config.direction == direction) {
        for (var j = 0, len2 = config.lanes.length; j < len2; j++) {
          final lane = config.lanes[j];

          if (true || lane.adjacentConnections.contains(nextConnection)) {
            signs = lane.signs;

            break;
          }
        }

        if (signs != null) break;
      }
    }

    if (signs != null && signs.isNotEmpty) {
      final streams = signs.map((sign) => sign.canDriveBy).toList()
        ..add(_congestion(nextConnection, direction));

      return Observable.combineLatest(
              streams,
              (List<bool> values) =>
                  values.fold(true, (bool prev, value) => prev && value))
          .where(test)
          .first;
    }

    return Future.value(true);
  }

  Observable<bool> _congestion(Connection connection, Direction direction) {
    final dy = connection.totalDistance(direction);
    final startPoint = connection.resolveStart(direction);

    final localizeOnNext = (Map<Actor, Point> snapshot) {
      final localMap = <Actor, Point>{};

      if (nextState != null) {
        snapshot.forEach((actor, point) {
          if (actor.stateSync.isSameState(nextState)) {
            localMap[actor] = point;
          }
        });
      }

      return localMap;
    };

    return _onSnapshot.stream
        .map(localizeOnNext)
        .map((snapshot) => snapshot.values.fold(dy, (double prev, next) {
              final d = startPoint.distanceTo(next);

              if (d < prev) return d;

              return prev;
            }))
        .map((dist) => dist >= 10);
  }

  Future<void> _maybeSlowDown(Map<Actor, Point> snapshot) async {
    if (!snapshot.containsKey(this)) return;

    final state = _onState.value;
    final point = snapshot[this];
    final endPoint = state.connection.resolveEnd(state.direction);
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

    if (obstruction == null && _currentPathIndex < path.length) {
      final canDriveBy = await _canSwitchConnection(endPoint, (_) => true);

      if (!canDriveBy) {
        obstruction = endPoint;
        dist = dy;
      }
    }

    void applyStop() => onLinearModifiers.add(const <Vector>[]);

    void applyDeceleration() {
      final startPoint = state.connection.resolveStart(state.direction);
      final dx = state.connection.end.x == state.connection.start.x
              ? endPoint.x - startPoint.x
              : obstruction.x - point.x,
          dy = state.connection.end.y == state.connection.start.y
              ? endPoint.y - startPoint.y
              : obstruction.y - point.y;

      onLinearModifiers.add([Vector(dx, dy, duration)]);
    }

    void applyNormal() {
      final startPoint = state.connection.resolveStart(state.direction);

      onLinearModifiers.add([
        Vector(endPoint.x - startPoint.x, endPoint.y - startPoint.y, duration)
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
    } else if (state.connection != path.last) {
      applyNormal();
    }
  }
}

class ActorState {
  final Connection connection;
  final Direction direction;

  ActorState(this.connection, this.direction);

  bool isSameState(ActorState other) =>
      connection == other.connection && direction == other.direction;
}
