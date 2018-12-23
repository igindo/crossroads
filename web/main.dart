import 'dart:html';
import 'dart:math' as math;

import 'package:crossroads/crossroads.dart';

import '../example/mortsel.dart';

void main() {
  final CanvasElement canvas = querySelector('#canvas');

  const colors = ['red', 'green', 'blue', 'purple', 'pink'];
  final colorPoints = Set<Point>();

  supervisor.snapshot.listen((snapshot) {
    final CanvasRenderingContext2D context = canvas.getContext('2d');

    context.clearRect(0, 0, 800, 665);

    network.connections.forEach((connection) {
      context.beginPath();
      context.moveTo(connection.start.x, connection.start.y);
      context.lineTo(connection.end.x, connection.end.y);
      context.closePath();
      context.strokeStyle = connection.congestionStateSync.isCongested
          ? 'red'
          : connection.congestionStateSync.isActorLeaving ? 'orange' : 'black';
      context.stroke();

      connection.accepts.forEach((incoming, signs) {
        final lights =
            signs.where((sign) => sign is Stoplight).toList(growable: false);

        lights.forEach((stoplight) =>
            stoplight.canDriveBy.first.then((canDriveBy) {
              context.beginPath();
              context.arc(incoming.end.x, incoming.end.y, 4, 0, 2 * math.pi);
              context.fillStyle =
                  canDriveBy ? 'rgba(0, 255, 0, 0.5)' : 'rgba(255, 0, 0, 0.5)';
              context.fill();
              context.lineWidth = 1;
              context.strokeStyle = 'black';
              context.stroke();
            }));
      });
    });

    snapshot.forEach((actor, point) {
      colorPoints.add(actor.end);

      context.beginPath();
      context.arc(point.x, point.y, 4, 0, 2 * math.pi);
      context.fillStyle =
          colors[colorPoints.toList(growable: false).indexOf(actor.end)];
      context.fill();
      context.lineWidth = 1;
      context.strokeStyle = 'white';
      context.stroke();
    });
  });
}

Stream<num> animationStream() async* {
  yield await window.animationFrame;

  yield* animationStream();
}
