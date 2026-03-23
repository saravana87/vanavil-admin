import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanavil_firebase/vanavil_firebase.dart';

import 'package:admin_web/src/features/auth/admin_login_screen.dart';

void main() {
  testWidgets('renders admin login screen', (WidgetTester tester) async {
    final binding = tester.binding;
    await binding.setSurfaceSize(const Size(1440, 960));

    await tester.pumpWidget(
      const MaterialApp(
        home: AdminLoginScreen(
          bootstrap: VanavilFirebaseBootstrap(isConfigured: true),
        ),
      ),
    );

    expect(find.text('Admin sign in'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create first admin account'), findsOneWidget);

    await binding.setSurfaceSize(null);
  });
}
