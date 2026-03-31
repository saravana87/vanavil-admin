import 'package:flutter_test/flutter_test.dart';

import 'package:child_app/src/app/child_app.dart';

void main() {
  testWidgets('child app shows profile selection first', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VanavilChildApp());
    await tester.pumpAndSettle();

    expect(find.text('Choose your profile'), findsOneWidget);
    expect(
      find.text('Pick your picture and enter your 4-digit PIN to continue.'),
      findsOneWidget,
    );
  });
}
