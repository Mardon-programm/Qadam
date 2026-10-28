import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qadam_passenger/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Secure storage has no platform implementation inside widget tests, so the
  // router guard would wait forever on the token read. Answer with "no token".
  const storageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (_) async => null);
  });

  testWidgets('passenger app boots to language selection', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: QadamPassengerApp()));
    await tester.pumpAndSettle();
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('Кыргызча'), findsOneWidget);
  });
}
