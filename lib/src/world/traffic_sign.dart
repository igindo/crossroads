import 'package:rxdart/rxdart.dart';

abstract class TrafficSign {
  Observable<bool> get canDriveBy;
}

class Stoplight implements TrafficSign {
  final BehaviorSubject<bool> _onCanDriveBy =
      BehaviorSubject<bool>(seedValue: true);

  @override
  Observable<bool> get canDriveBy => _onCanDriveBy.stream;

  Stoplight() {
    Stream.periodic(const Duration(seconds: 6))
        .listen((_) => _onCanDriveBy.add(!_onCanDriveBy.value));
  }
}
