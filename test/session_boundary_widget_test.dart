import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiefy/main.dart';
import 'package:foodiefy/repositories/app_repositories.dart';
import 'package:foodiefy/repositories/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_persistence_test.dart' show TestSession;

void main() {
  testWidgets('account switch removes all private navigation routes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final previous = AppRepositories.session;
    final session = TestSession('A');
    AppRepositories.session = session;
    try {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Text('A private detail and draft')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('A private detail and draft'), findsOneWidget);
      session.change('B');
      await tester.pumpAndSettle();
      expect(find.text('A private detail and draft'), findsNothing);
      expect(find.text('Foodiefy'), findsOneWidget);
      session.change(null);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      AppRepositories.session = previous;
      session.dispose();
    }
  });
  test('session without a client has no implicit anonymous user', () {
    final session = SessionRepository(null);
    expect(session.ownerId, isNull);
    expect(session.configured, isFalse);
    session.dispose();
  });
}
