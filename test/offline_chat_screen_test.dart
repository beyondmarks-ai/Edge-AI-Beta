import 'dart:async';
import 'dart:io';

import 'package:edge_alpha/src/screens/offline_chat_screen.dart';
import 'package:edge_alpha/src/app.dart';
import 'package:edge_alpha/src/config/edge_ai_config.dart';
import 'package:edge_alpha/src/services/auth_service.dart';
import 'package:edge_alpha/src/services/offline_chat_runtime.dart';
import 'package:edge_alpha/src/services/offline_model_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class InstalledStore extends OfflineModelStore {
  InstalledStore() : super(directory: () async => Directory.systemTemp);
  @override
  Future<bool> isInstalled() async => true;
  @override
  Future<int> downloadedBytes() async => 0;
  @override
  Future<bool> verify(File model) async => true;
}

class FakeRuntime implements OfflineChatRuntime {
  final tokens = StreamController<String>();
  String? question;
  bool loaded = false;
  bool disposed = false;
  bool resetCalled = false;
  @override
  Future<void> load(String path) async {
    loaded = true;
  }

  @override
  Stream<String> reply(String question) {
    this.question = question;
    return tokens.stream;
  }

  @override
  void stop() {
    if (!tokens.isClosed) unawaited(tokens.close());
  }

  @override
  void reset() {
    resetCalled = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    stop();
  }
}

void main() {
  testWidgets(
    'offline entry remains accessible while authentication is pending',
    (tester) async {
      final auth = PendingAuth();
      await tester.pumpWidget(
        EdgeAiApp(config: EdgeAiConfig.empty, auth: auth),
      );
      await tester.pump();
      expect(find.text('Open offline chat'), findsOneWidget);
      await tester.tap(find.text('Open offline chat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(OfflineChatScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      auth.signedIn.complete(false);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed generation restores the question for retry', (
    tester,
  ) async {
    final runtime = FakeRuntime();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineChatScreen(store: InstalledStore(), runtime: runtime),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.tap(find.byTooltip('Send offline'));
    await tester.pumpAndSettle();
    runtime.tokens.addError(StateError('Inference failed'));
    await tester.pumpAndSettle();
    expect(find.text('No response. Please try again.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Hello',
    );
    expect(find.byTooltip('Send offline'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'installed model streams offline and stops without cloud access',
    (tester) async {
      final runtime = FakeRuntime();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineChatScreen(store: InstalledStore(), runtime: runtime),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Explain gravity');
      await tester.tap(find.byTooltip('Send offline'));
      await tester.pumpAndSettle();
      expect(runtime.loaded, isTrue);
      expect(runtime.question, 'Explain gravity');
      runtime.tokens.add('Gravity attracts objects.');
      await tester.pumpAndSettle();
      expect(find.text('Gravity attracts objects.'), findsOneWidget);
      await tester.tap(find.byTooltip('Stop response'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Send offline'), findsOneWidget);
      await tester.tap(find.byTooltip('New offline chat'));
      await tester.pumpAndSettle();
      expect(runtime.resetCalled, isTrue);
      expect(find.text('Gravity attracts objects.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(runtime.disposed, isTrue);
    },
  );

  testWidgets(
    'leaving during model load waits before disposing native runtime',
    (tester) async {
      final runtime = SlowRuntime();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineChatScreen(store: InstalledStore(), runtime: runtime),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byTooltip('Send offline'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      expect(runtime.disposed, isFalse);
      runtime.loadComplete.complete();
      await tester.pumpAndSettle();
      expect(runtime.disposed, isTrue);
      expect(runtime.question, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}

class SlowRuntime extends FakeRuntime {
  final loadComplete = Completer<void>();
  @override
  Future<void> load(String path) => loadComplete.future;
}

class PendingAuth extends AuthService {
  PendingAuth() : super(EdgeAiConfig.empty);
  final signedIn = Completer<bool>();
  @override
  Future<bool> isSignedIn() => signedIn.future;
}
