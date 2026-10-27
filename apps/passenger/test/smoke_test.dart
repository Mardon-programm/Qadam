import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qadam_passenger/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('passenger app boots to language selection', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: QadamPassengerApp()));
    await tester.pumpAndSettle();
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('Кыргызча'), findsOneWidget);
  });
}
