import 'package:edge_alpha/src/app.dart';
import 'package:edge_alpha/src/models/edge_models.dart';
import 'package:edge_alpha/src/screens/student_home_screen.dart';
import 'package:edge_alpha/src/screens/cloud_setup_screen.dart';
import 'package:edge_alpha/src/services/edge_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('portable build requests only public cloud identifiers', (
    tester,
  ) async {
    await tester.pumpWidget(
      CloudSetupScreen(
        loading: false,
        onConfigure: (_) async {},
        onDemo: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connect Edge AI'), findsOneWidget);
    expect(find.text('Import edge-ai-connection.json'), findsOneWidget);
    expect(find.text('API base URL'), findsOneWidget);
    expect(find.text('Cognito User Pool ID'), findsOneWidget);
    expect(find.textContaining('API keys and AWS credentials'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Gemini API key'), findsNothing);
  });

  testWidgets('shows Edge AI dashboard in demo mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EdgeShell(repository: DemoEdgeRepository(), demoMode: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edge AI'), findsOneWidget);
    expect(find.text('Live classroom'), findsOneWidget);
    expect(find.text('Present'), findsOneWidget);
    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();
    expect(find.text('Vachanashree'), findsOneWidget);
  });

  testWidgets('student sees only personal attendance', (tester) async {
    final repository = DemoEdgeRepository();
    final student = (await repository.students()).first;
    await tester.pumpWidget(
      MaterialApp(
        home: StudentHomeScreen(
          repository: repository,
          profile: UserProfile(
            role: 'STUDENT',
            enrolled: true,
            student: student,
          ),
          onEnrollmentChanged: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My attendance'), findsOneWidget);
    expect(find.textContaining('Hello, Vachanashree'), findsOneWidget);
    expect(find.text('Improve my face profile'), findsOneWidget);
    expect(find.text('Students'), findsNothing);
  });
}
