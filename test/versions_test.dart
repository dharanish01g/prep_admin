import 'package:flutter_test/flutter_test.dart';
import 'package:prep_admin/utils/versions.dart';

void main() {
  test('compares dotted versions numerically', () {
    expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
    expect(isNewerVersion('1.10.0', '1.9.2'), isTrue);
    expect(isNewerVersion('2', '1.9.9'), isTrue);
    expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
    expect(isNewerVersion('1.0', '1.0.0'), isFalse);
    expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
    expect(isNewerVersion('1.0.0+5', '1.0.0+1'), isFalse);
  });
}
