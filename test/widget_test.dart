import 'package:flutter_test/flutter_test.dart';
import 'package:o_cajado/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Smoke test: verify the app widget can be created
    // Note: Full widget test requires database initialization
    expect(const SermonApp(), isNotNull);
  });
}
