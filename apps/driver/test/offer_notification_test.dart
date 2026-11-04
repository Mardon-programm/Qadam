import 'package:flutter_test/flutter_test.dart';
import 'package:qadam_driver/features/offers/offer_notifications.dart';

void main() {
  test('detects only truly new incoming ride offers', () {
    final previous = [
      {'ride_order_id': 'a', 'pickup_address': 'A'},
      {'ride_order_id': 'b', 'pickup_address': 'B'},
    ];
    final next = [
      {'ride_order_id': 'a', 'pickup_address': 'A'},
      {'ride_order_id': 'b', 'pickup_address': 'B'},
      {'ride_order_id': 'c', 'pickup_address': 'C'},
      {'ride_order_id': 'd', 'pickup_address': 'D'},
    ];

    expect(findNewOfferIds(previous, next), {'c', 'd'});
    expect(findNewOfferIds(next, next), isEmpty);
  });

  test('ignores offers without explicit ride id', () {
    final previous = [
      {'id': 'old-1'},
    ];
    final next = [
      {'id': 'old-1'},
      {'note': 'no id'},
    ];

    expect(findNewOfferIds(previous, next), isEmpty);
  });
}
