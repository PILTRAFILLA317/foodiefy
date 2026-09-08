import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiefy/config/app_config.dart';
import 'package:foodiefy/imports/import_jobs.dart';
import 'package:foodiefy/imports/share_inbox.dart';
import 'package:foodiefy/repositories/app_repositories.dart';
import 'package:foodiefy/repositories/library_repository.dart';
import 'package:foodiefy/repositories/local_cache.dart';
import 'package:foodiefy/screens/import_recipe_screen.dart';
import 'package:foodiefy/services/import_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_persistence_test.dart' show TestSession, TestGateway;

const id = '00000000-0000-4000-8000-000000000001';
AppConfig config() => AppConfig.fromValues({
  'APP_ENV': 'local',
  'LOCAL_RESCUE': 'false',
  'API_BASE_URL': 'http://127.0.0.1:8000',
  'SUPABASE_URL': 'https://example.invalid',
  'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_fixture',
});
Map<String, dynamic> view(
  String? stage, {
  String status = 'running',
  Map<String, dynamic>? result,
}) => {
  'schema_version': '1.0',
  'job_id': id,
  'status': status,
  'stage': stage,
  'created_at': '2026-09-08T00:00:00Z',
  'updated_at': '2026-09-08T00:00:00Z',
  'next_attempt_at': null,
  'result': result,
  'error': null,
};
http.Response response(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);
ImportRecipeService client(
  Future<http.Response> Function(http.Request) handle, {
  Future<void> Function()? refresh,
}) => ImportRecipeService(
  client: MockClient(handle),
  config: config(),
  accessToken: () => 'test-only',
  refresh: refresh ?? () async {},
);
Map<String, dynamic> analysis() => {
  'schema_version': '1.0',
  'analysis_status': 'recipe',
  'recipe': jsonDecode(
    File(
      'contracts/fixtures/recipe-draft.valid-unknowns.json',
    ).readAsStringSync(),
  ),
  'warnings': <String>[],
  'missing_information': <String>[],
  'conflicts': <Object>[],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('v1 POST sends JWT and same key across bounded auth refresh', () async {
    var calls = 0, refreshes = 0;
    final service = client(
      (r) async {
        expect(r.url.path, '/v1/imports');
        expect(r.headers['Idempotency-Key'], 'same-logical-key');
        expect(r.headers['Authorization'], 'Bearer test-only');
        expect(r.followRedirects, isFalse);
        expect(jsonDecode(r.body), {'description': '15 g sal'});
        return ++calls == 1
            ? response({}, 401)
            : response({'schema_version': '1.0', 'job_id': id}, 202);
      },
      refresh: () async {
        refreshes++;
      },
    );
    addTearDown(service.close);
    expect(
      await service.submit({'description': '15 g sal'}, 'same-logical-key'),
      id,
    );
    expect(calls, 2);
    expect(refreshes, 1);
  });
  test('persistent unauthorized stops after one refresh', () async {
    var calls = 0, refreshes = 0;
    final service = client(
      (_) async {
        calls++;
        return response({}, 401);
      },
      refresh: () async {
        refreshes++;
      },
    );
    addTearDown(service.close);
    await expectLater(
      service.list(),
      throwsA(
        isA<ImportRecipeException>().having(
          (x) => x.code,
          'code',
          'unauthorized',
        ),
      ),
    );
    expect(calls, 2);
    expect(refreshes, 1);
  });
  test('rescue and missing auth never call network', () async {
    for (final rescue in [true, false]) {
      final service = ImportRecipeService(
        config: rescue ? AppConfig.fromValues({}) : config(),
        accessToken: () => null,
        client: MockClient((_) => throw StateError('no network')),
      );
      await expectLater(
        service.submit({'url': 'https://example.invalid'}, 'same-key'),
        throwsA(isA<ImportRecipeException>()),
      );
      service.close();
    }
  });
  test('request timeout remains retryable', () async {
    final service = ImportRecipeService(
      config: config(),
      accessToken: () => 'fixture',
      requestTimeout: const Duration(milliseconds: 5),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(service.close);
    await expectLater(
      service.list(),
      throwsA(
        isA<ImportRecipeException>().having((x) => x.code, 'code', 'timeout'),
      ),
    );
  });
  test(
    'definitive rejection can be dismissed before corrected input',
    () async {
      final session = TestSession('A');
      final jobs = ImportJobs(
        session,
        await SharedPreferences.getInstance(),
        client(
          (r) async => r.method == 'POST'
              ? response({
                  'error': {'code': 'source_unavailable'},
                }, 422)
              : response({
                  'schema_version': '1.0',
                  'items': [],
                  'next_cursor': null,
                }),
        ),
      )..initialize();
      await jobs.submit({'url': 'https://example.invalid/recipe'});
      expect(jobs.items.single.terminal, isTrue);
      expect(jobs.items.single.view, isNull);
      expect(jobs.items.single.label, contains('Solicitud no aceptada'));
      await jobs.dismiss(jobs.items.single);
      expect(jobs.visible, isEmpty);
      jobs.dispose();
      session.dispose();
    },
  );
  test('unauthorized polling stops until explicit retry', () async {
    final session = TestSession('A');
    var calls = 0;
    final jobs = ImportJobs(
      session,
      await SharedPreferences.getInstance(),
      client((_) async {
        calls++;
        return response({}, 401);
      }),
    )..initialize();
    await jobs.refresh();
    expect(calls, 2);
    await jobs.refresh(manual: false);
    expect(calls, 2);
    await jobs.refresh();
    expect(calls, 4);
    jobs.dispose();
    session.dispose();
  });
  test('response size and redirects fail closed', () async {
    for (final payload in [
      http.Response('x' * (2 * 1024 * 1024 + 1), 200),
      http.Response('', 302),
    ]) {
      final service = client((_) async => payload);
      addTearDown(service.close);
      await expectLater(service.list(), throwsA(isA<ImportRecipeException>()));
    }
  });
  test(
    'close/reopen preserves logical key; lost POST merges remote job',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final session = TestSession('A');
      final keys = <String>[];
      var submitted = false;
      final service = client((r) async {
        if (r.method == 'POST') {
          keys.add(r.headers['Idempotency-Key']!);
          submitted = true;
          throw const SocketException('lost response');
        }
        return response({
          'schema_version': '1.0',
          'items': submitted ? [view(null, status: 'queued')] : [],
          'next_cursor': null,
        });
      });
      var jobs = ImportJobs(session, prefs, service)..initialize();
      await jobs.submit({'url': 'https://example.invalid/recipe'});
      final key = jobs.items.first.key;
      expect(prefs.getString('imports.v1.A'), contains(key));
      jobs.dispose();
      final resumed = client((r) async {
        if (r.method == 'POST') {
          keys.add(r.headers['Idempotency-Key']!);
          return response({'schema_version': '1.0', 'job_id': id}, 202);
        }
        return response({
          'schema_version': '1.0',
          'items': [view(null, status: 'queued')],
          'next_cursor': null,
        });
      });
      jobs = ImportJobs(session, prefs, resumed)..initialize();
      await jobs.refresh();
      final pending = jobs.items.firstWhere((x) => x.jobId == null);
      await jobs.retry(pending);
      expect(keys, [key, key]);
      expect(jobs.items.where((x) => x.jobId == id).length, 1);
      session.change('B');
      expect(jobs.visible, isEmpty);
      session.change('A');
      expect(jobs.items.single.jobId, id);
      jobs.dispose();
      session.dispose();
    },
  );
  test(
    'polls never overlap; lifecycle pauses; late A response hidden from B',
    () async {
      final session = TestSession('A');
      final gate = Completer<http.Response>();
      final entered = Completer<void>();
      var calls = 0;
      final jobs = ImportJobs(
        session,
        await SharedPreferences.getInstance(),
        client((_) async {
          calls++;
          if (!entered.isCompleted) entered.complete();
          return gate.future;
        }),
      )..initialize();
      final pending = jobs.refresh();
      await entered.future;
      await jobs.refresh();
      expect(calls, 1);
      jobs.didChangeAppLifecycleState(AppLifecycleState.paused);
      await jobs.refresh();
      expect(calls, 1);
      session.change('B');
      gate.complete(
        response({
          'schema_version': '1.0',
          'items': [view('transcribing')],
          'next_cursor': null,
        }),
      );
      await pending;
      expect(jobs.visible, isEmpty);
      jobs.dispose();
      session.dispose();
    },
  );
  for (final stages in [
    [
      'resolving_source',
      'extracting_metadata',
      'extracting_recipe',
      'finalizing',
    ],
    ['extracting_audio', 'transcribing', 'extracting_recipe'],
    ['extracting_recipe', 'analyzing_visual_evidence', 'finalizing'],
  ]) {
    testWidgets('only backend stages rendered: $stages', (tester) async {
      final session = TestSession('A');
      var currentStage = stages.first;
      final jobs = ImportJobs(
        session,
        await SharedPreferences.getInstance(),
        client((request) async {
          return request.url.path.endsWith(id)
              ? response(view(currentStage))
              : response({
                  'schema_version': '1.0',
                  'items': [view(currentStage)],
                  'next_cursor': null,
                });
        }),
      );
      await tester
          .pump(); // Complete constructor futures before switching zones.
      jobs.initialize();
      final old = AppRepositories.imports;
      AppRepositories.imports = jobs;
      for (final stage in stages) {
        currentStage = stage;
        final update = jobs.refresh();
        await tester.pump();
        await update;
        await tester.pumpWidget(
          MaterialApp(home: ImportRecipeScreen(key: ValueKey(stage))),
        );
        await tester.pump();
        expect(find.text(stageLabels[stage]!), findsOneWidget);
        if (stage != 'transcribing') {
          expect(find.text('Transcribiendo…'), findsNothing);
        }
        if (stage != 'analyzing_visual_evidence') {
          expect(find.text('Revisando información visual…'), findsNothing);
        }
      }
      await tester.pumpWidget(const SizedBox());
      AppRepositories.imports = old;
      jobs.dispose();
      session.dispose();
    });
  }
  test(
    'share no URL, several URLs, event replay and legitimate same URL later',
    () async {
      final session = TestSession('A');
      final inbox = ShareInbox(await SharedPreferences.getInstance(), session);
      await inbox.initialize();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      expect(
        await inbox.receive({
          'id': 'one',
          'created': stamp,
          'text': 'Sin enlace',
        }),
        isTrue,
      );
      expect(inbox.urls, isEmpty);
      await inbox.clear();
      expect(
        await inbox.receive({
          'id': 'two',
          'created': stamp,
          'text': 'Mira https://example.org/a y https://example.org/b',
        }),
        isTrue,
      );
      expect(inbox.urls.length, 2);
      expect(
        await inbox.receive({
          'id': 'two',
          'created': stamp,
          'text': 'https://example.org/a',
        }),
        isFalse,
      );
      await inbox.clear();
      expect(
        await inbox.receive({
          'id': 'three',
          'created': stamp,
          'text': 'https://example.org/a',
        }),
        isTrue,
      );
      session.change(null);
      session.change('B');
      expect(inbox.pending, isNull);
      expect(
        await inbox.receive({
          'id': 'old',
          'created': stamp - 86400001,
          'text': 'https://example.org/a',
        }),
        isFalse,
      );
      expect(sharedUrls('https://user:password@example.org/'), isEmpty);
      inbox.dispose();
      session.dispose();
    },
  );
  test(
    'two cold share events remain separate until each is acknowledged',
    () async {
      final session = TestSession(null);
      final prefs = await SharedPreferences.getInstance();
      var inbox = ShareInbox(prefs, session);
      await inbox.initialize();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await inbox.receive({
        'id': 'event-a',
        'created': stamp,
        'text': 'https://example.org/a',
      });
      await inbox.receive({
        'id': 'event-b',
        'created': stamp,
        'text': 'https://example.org/b',
      });
      expect(inbox.urls, ['https://example.org/a']);
      inbox.dispose();
      inbox = ShareInbox(prefs, session);
      await inbox.initialize();
      await inbox.clear(expectedId: 'wrong');
      expect(inbox.urls, ['https://example.org/a']);
      await inbox.clear(expectedId: 'event-a');
      expect(inbox.urls, ['https://example.org/b']);
      inbox.dispose();
      session.dispose();
    },
  );
  test(
    'anonymous cold share survives init/login but never starts HTTP',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final session = TestSession(null);
      var inbox = ShareInbox(prefs, session);
      await inbox.initialize();
      await inbox.receive({
        'id': 'cold',
        'created': DateTime.now().millisecondsSinceEpoch,
        'urls': ['https://example.org/recipe'],
      });
      inbox.dispose();
      inbox = ShareInbox(prefs, session);
      await inbox.initialize();
      session.change('A');
      expect(inbox.urls, ['https://example.org/recipe']);
      expect(inbox.pending!['owner'], 'A');
      inbox.dispose();
      session.dispose();
    },
  );
  test('save replay after lost response creates exactly one recipe', () async {
    final session = TestSession('A'), remote = TestGateway();
    final cache = LocalCache(NativeDatabase.memory());
    final library = LibraryRepository(session, cache, remote);
    await library.initialize();
    final item = PendingImport(
      key: 'one',
      recipeId: id,
      payload: {},
      jobId: id,
      view: view('finalizing', status: 'succeeded', result: analysis()),
    );
    remote.loseResponse = true;
    await expectLater(
      library.saveRecipe(item.draft!, operationId: 'save-same-import'),
      throwsA(isA<CloudFailure>()),
    );
    await Future.wait([
      library.saveRecipe(item.draft!, operationId: 'save-same-import'),
      library.saveRecipe(item.draft!, operationId: 'save-same-import'),
    ]);
    expect(remote.writes, 1);
    expect(library.recipes.length, 1);
    library.dispose();
    await cache.close();
    session.dispose();
  });
  testWidgets('login confirmation does not duplicate the incoming share', (
    tester,
  ) async {
    final session = TestSession(null);
    late ShareInbox inbox;
    await tester.runAsync(() async {
      inbox = ShareInbox(await SharedPreferences.getInstance(), session);
      await inbox.initialize();
      await inbox.receive({
        'id': 'before-login',
        'created': DateTime.now().millisecondsSinceEpoch,
        'text': 'https://example.org/recipe',
      });
    });
    final previousSession = AppRepositories.session;
    final previousShares = AppRepositories.shares;
    AppRepositories.session = session;
    AppRepositories.shares = inbox;
    await tester.pumpWidget(const MaterialApp(home: ImportRecipeScreen()));
    await tester.tap(find.text('Iniciar sesión para importar'));
    await tester.pumpAndSettle();
    await tester.runAsync(inbox.clear);
    expect(inbox.pending, isNull);
    await tester.pumpWidget(const SizedBox());
    AppRepositories.session = previousSession;
    AppRepositories.shares = previousShares;
    inbox.dispose();
    session.dispose();
  });
  testWidgets(
    'partial contradictions and nutrition unavailable visible at large text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: DraftWarnings(
                  result: {
                    ...analysis(),
                    'analysis_status': 'partial',
                    'missing_information': ['ingredients.0.quantity'],
                    'conflicts': [
                      {
                        'field_path': 'ingredients.0.quantity',
                        'evidence': [
                          {'source_kind': 'description', 'quote': '15 g'},
                          {'source_kind': 'transcript', 'quote': '150 g'},
                        ],
                      },
                    ],
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Contradicción'), findsOneWidget);
      expect(find.textContaining('Nutrición no disponible'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
