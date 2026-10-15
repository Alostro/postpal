import 'package:flutter_test/flutter_test.dart';
import 'package:postpal/services/looks.dart';

void main() {
  test('every look is neutral at zero strength', () {
    const identity = [
      1.0, 0, 0, 0, 0,
      0, 1.0, 0, 0, 0,
      0, 0, 1.0, 0, 0,
      0, 0, 0, 1.0, 0,
    ];
    for (final look in looks) {
      final m = look.matrix(0);
      for (var i = 0; i < 20; i++) {
        expect(m[i], closeTo(identity[i], 1e-9), reason: '${look.name} [$i]');
      }
    }
  });
}
