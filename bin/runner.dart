import '../example/mortsel.dart';

void main() {
  supervisor.snapshot.throttle(const Duration(seconds: 1)).listen((snapshot) {
    print('${snapshot.keys.length} actors');
  });
}
