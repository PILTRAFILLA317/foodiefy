import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiefy/models/recipe.dart';
import 'package:foodiefy/recovery/legacy_recovery.dart';
import 'package:foodiefy/repositories/cloud_gateway.dart';
import 'package:foodiefy/repositories/library_repository.dart';
import 'package:foodiefy/repositories/local_cache.dart';
import 'package:foodiefy/repositories/recipe_codec.dart';
import 'package:foodiefy/repositories/session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestSession extends SessionRepository {
  TestSession(this.owner) : super(null);
  String? owner;
  @override
  String? get ownerId => owner;
  void change(String? value) {
    owner = value;
    notifyListeners();
  }
}

class TestGateway implements CloudGateway {
  final Map<String, Map<String, dynamic>> data = {};
  final Map<String, Map<String, dynamic>> receipts = {};
  bool disconnected = false;
  bool loseResponse = false;
  int writes = 0;
  int uploads = 0;
  Completer<void>? snapshotGate;
  Map<String, dynamic> library(String owner) => data.putIfAbsent(
    owner,
    () => {
      'owner_id': owner,
      'recipes': <dynamic>[],
      'collections': <dynamic>[],
      'images': <String, dynamic>{},
    },
  );
  @override
  Future<Map<String, dynamic>> snapshot(String owner) async {
    final value =
        jsonDecode(jsonEncode(library(owner))) as Map<String, dynamic>;
    await snapshotGate?.future;
    if (disconnected) throw const SocketException('offline');
    return value;
  }

  @override
  Future<Map<String, dynamic>> mutate(
    String owner,
    String op,
    String kind,
    Map<String, dynamic> p,
  ) async {
    if (disconnected) throw const SocketException('offline');
    final key = '$owner/$op';
    if (receipts.containsKey(key)) return receipts[key]!;
    writes++;
    final state = library(owner);
    final recipes = state['recipes'] as List;
    final collections = state['collections'] as List;
    Map<String, dynamic> result = {'id': p['id']};
    if (kind == 'save_recipe') {
      final old = recipes.where((r) => r['id'] == p['id']).firstOrNull;
      if (old != null && old['revision'] != p['revision']) {
        throw const CloudFailure('revision conflict');
      }
      result = {
        ...Map<String, dynamic>.from(p['draft']),
        'id': p['id'],
        'owner_id': owner,
        'revision': (p['revision'] as int? ?? 0) + 1,
        'created_at': '2026-09-08T10:00:00Z',
        'updated_at': '2026-09-08T10:00:00Z',
        'deleted_at': null,
      };
      recipes.removeWhere((r) => r['id'] == p['id']);
      recipes.add(result);
    } else if (kind == 'save_collection') {
      result = {
        'id': p['id'],
        'name': p['name'],
        'revision': 1,
        'owner_id': owner,
        'recipe_ids': <String>[],
        'created_at': '2026-09-08T10:00:00Z',
        'updated_at': '2026-09-08T10:00:00Z',
      };
      collections.add(result);
    } else if (kind == 'set_collections') {
      for (final c in collections) {
        (c['recipe_ids'] as List).remove(p['id']);
        if ((p['collection_ids'] as List).contains(c['id'])) {
          (c['recipe_ids'] as List).add(p['id']);
        }
      }
    } else if (kind == 'delete_recipe') {
      recipes.removeWhere((r) => r['id'] == p['id']);
    }
    receipts[key] = result;
    if (loseResponse) {
      loseResponse = false;
      throw const SocketException('response lost after commit');
    }
    return result;
  }

  @override
  Future<void> upload(
    String owner,
    String path,
    Uint8List bytes,
    String mime,
  ) async {
    if (disconnected) throw const SocketException('offline');
    uploads++;
  }

  @override
  Future<String> imageUrl(String owner, String path) async =>
      'https://example.invalid/private';
}

Recipe recipe(String id, {String title = 'Recipe'}) => Recipe(
  id: id,
  title: title,
  ingredients: ['1.5 kg de tomate'],
  steps: ['Mezclar'],
  createdAt: DateTime.utc(2020),
);
Map<String, dynamic> clone(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)));
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestSession session;
  late TestGateway remote;
  late LocalCache cache;
  late LibraryRepository library;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session = TestSession('A');
    remote = TestGateway();
    cache = LocalCache(NativeDatabase.memory());
    library = LibraryRepository(session, cache, remote);
    await library.initialize();
  });
  tearDown(() async {
    library.dispose();
    session.dispose();
    await cache.close();
  });
  test('offline retains confirmed cache and never confirms a write', () async {
    await library.saveRecipe(recipe('one'));
    remote.disconnected = true;
    await library.refresh();
    expect(library.recipes.single.id, 'one');
    expect(library.offline, isTrue);
    await expectLater(
      library.saveRecipe(recipe('two')),
      throwsA(isA<CloudFailure>()),
    );
    expect(library.recipes.map((r) => r.id), ['one']);
    expect((await cache.read('A', 'library'))!['recipes'], hasLength(1));
  });
  test('response lost after commit retries the same operation', () async {
    remote.loseResponse = true;
    await expectLater(
      library.saveRecipe(recipe('one')),
      throwsA(isA<CloudFailure>()),
    );
    await library.saveRecipe(recipe('one'));
    expect(remote.writes, 1);
    expect(library.recipes, hasLength(1));
  });
  test('A to B and logout clear state cache and late requests', () async {
    await library.saveRecipe(recipe('private-A'));
    remote.snapshotGate = Completer<void>();
    final request = library.refresh();
    session.change('B');
    expect(library.recipes, isEmpty);
    remote.snapshotGate!.complete();
    await request;
    await library.readRecipes();
    expect(library.recipes, isEmpty);
    expect(await cache.read('A', 'library'), isNull);
    await library.saveRecipe(recipe('private-B'));
    session.change(null);
    expect(library.recipes, isEmpty);
    await library.readRecipes();
    expect(await cache.read('B', 'library'), isNull);
    expect(() => library.requireOwner(), throwsA(isA<CloudFailure>()));
  });
  test('cache reopen reads only the session owner while offline', () async {
    await library.saveRecipe(recipe('cached-A'));
    library.dispose();
    remote.disconnected = true;
    library = LibraryRepository(session, cache, remote);
    await library.initialize();
    expect(library.recipes.single.id, 'cached-A');
    expect(library.offline, isTrue);
  });
  test(
    'codec preserves unknowns and structured decimal ingredients on edit',
    () {
      final draft = RecipeCodec.draft(recipe('one'));
      expect(draft['source']['url'], isNull);
      expect(draft['source']['platform'], isNull);
      expect(draft['nutrition'], isNull);
      draft['ingredients'][0]['quantity'] = '1.500000';
      draft['ingredients'][0]['unit'] = 'kg';
      final record = {
        ...draft,
        'id': 'one',
        'owner_id': 'A',
        'revision': 2,
        'created_at': '2026-09-08T00:00:00Z',
        'updated_at': '2026-09-08T00:00:00Z',
        'deleted_at': null,
      };
      expect(
        RecipeCodec.draft(RecipeCodec.record(record))['ingredients'],
        draft['ingredients'],
      );
    },
  );
  test(
    'legacy collisions ambiguous relation missing image preserve all occurrences and resume twice',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'foodiefy-legacy-test-',
      );
      final rawRecipes = [
        jsonEncode({
          ...recipe('').toJson(),
          'imagePath': '${directory.path}/missing.jpg',
        }),
        jsonEncode(recipe('duplicate').toJson()),
        jsonEncode({
          ...recipe('duplicate').toJson(),
          'unknown_field': {'keep': true},
        }),
      ];
      final raw = jsonEncode({
        'format': 'foodiefy-legacy-v1',
        'recipes': rawRecipes,
        'collections': [
          jsonEncode({
            'id': 'old-c',
            'name': 'Old',
            'recipeIds': ['duplicate'],
            'isMaster': false,
          }),
        ],
      });
      var rescue = LegacyRecovery(directory);
      try {
        await rescue.prepare(rawExport: raw);
        expect(rescue.entries, hasLength(3));
        expect(rescue.entries.map((r) => r['id']).toSet(), hasLength(3));
        expect(rescue.entries.first['image_status'], 'missing');
        expect(rescue.relations.single['resolved'], isFalse);
        expect(await File('${directory.path}/raw.json').readAsString(), raw);
        expect(
          await File('${directory.path}/raw.backup.json').readAsString(),
          raw,
        );
        await expectLater(
          rescue.importTo(library, confirmedOwner: 'A'),
          throwsA(isA<CloudFailure>()),
        );
        expect(remote.writes, 0);
        await rescue.resolve(0, 2);
        remote.loseResponse = true;
        await expectLater(
          rescue.importTo(library, confirmedOwner: 'A'),
          throwsA(isA<CloudFailure>()),
        );
        final ids = rescue.entries.map((r) => r['id']).toList();
        rescue.dispose();
        rescue = LegacyRecovery(directory);
        await rescue.prepare();
        expect(rescue.entries.map((r) => r['id']), ids);
        await rescue.importTo(library, confirmedOwner: 'A');
        final writes = remote.writes;
        await rescue.importTo(library, confirmedOwner: 'A');
        expect(remote.writes, writes);
        expect(library.recipes, hasLength(3));
        expect(
          library.recipes.fold<int>(0, (n, r) => n + r.ingredients.length),
          3,
        );
        expect(library.collections.single.recipeIds, [ids[2]]);
        expect(rescue.plan!['complete'], isTrue);
        session.change('B');
        await library.readRecipes();
        await expectLater(
          rescue.importTo(library, confirmedOwner: 'B'),
          throwsA(isA<CloudFailure>()),
        );
        expect(rescue.plan!['owner_id'], 'A');
        await rescue.verifyBackup();
      } finally {
        rescue.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'unparseable raw is quarantined and checksum tampering blocks import',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'foodiefy-raw-test-',
      );
      final rescue = LegacyRecovery(directory);
      try {
        await rescue.prepare(
          rawExport: jsonEncode({
            'recipes': ['{invalid', jsonEncode(recipe('').toJson())],
            'collections': [],
          }),
        );
        expect(rescue.entries, hasLength(2));
        expect(rescue.entries.first['issue'], isNotNull);
        await rescue.correctRecipe(0, jsonEncode(recipe('corrected').toJson()));
        await File(
          '${directory.path}/raw.backup.json',
        ).writeAsString('tampered');
        await expectLater(
          rescue.importTo(library, confirmedOwner: 'A'),
          throwsA(isA<CloudFailure>()),
        );
        expect(remote.writes, 0);
      } finally {
        rescue.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'only selected legacy images upload and their durable copies survive source removal',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'foodiefy-image-test-',
      );
      final source = File('${directory.path}/picked.png');
      await source.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aE1sAAAAASUVORK5CYII=',
        ),
      );
      final recovery = LegacyRecovery(Directory('${directory.path}/backup'));
      try {
        final rawRecipe = jsonEncode({
          ...recipe('old').toJson(),
          'imagePath': source.path,
        });
        await recovery.prepare(
          rawExport: jsonEncode({
            'recipes': [rawRecipe, rawRecipe],
            'collections': [],
          }),
        );
        expect(recovery.entries.map((r) => r['image_status']), [
          'copied',
          'copied',
        ]);
        await source.delete();
        await recovery.selectImage(1, true);
        await recovery.importTo(library, confirmedOwner: 'A');
        expect(remote.uploads, 1);
        expect(library.recipes.length, 2);
        await recovery.verifyBackup();
      } finally {
        recovery.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test('pending import link survives a new session repository', () async {
    await session.savePendingImport('https://example.invalid/recipe');
    final second = SessionRepository(null);
    expect(await second.pendingImport(), 'https://example.invalid/recipe');
    second.dispose();
  });
}
