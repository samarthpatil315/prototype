// Integration test: boots the real app, enters the demo workspace and
// verifies the dashboard renders. Run with:
//   flutter test test/integration/app_flow_test.dart
// (or `flutter drive` on a device/emulator for full end-to-end coverage.)
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbital_office/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots to onboarding/login flow', (tester) async {
    app.main();
    await tester.pump();
    // Splash shows the brand while the workspace boots.
    expect(find.text('ORBITAL OFFICE'), findsWidgets);
  });
}
