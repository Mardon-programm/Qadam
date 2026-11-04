import 'package:flutter_test/flutter_test.dart';
import 'package:qadam_passenger/features/city/presentation/tariff_selector.dart';

void main() {
  test('tariff surge mapping should cover main ride classes', () {
    expect(tariffSurgeForId('economy'), 1.0);
    expect(tariffSurgeForId('comfort'), 1.25);
    expect(tariffSurgeForId('business'), 1.55);
    expect(tariffSurgeForId('vip'), 2.3);
    expect(tariffSurgeForId('free'), 1.0);
    expect(tariffSurgeForId('free_plus'), 1.0);
  });
}
