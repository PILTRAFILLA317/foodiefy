import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:foodiefy/models/recipe.dart';
import 'package:foodiefy/repositories/recipe_codec.dart';
import 'package:foodiefy/widgets/honest_nutrition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiefy/repositories/local_cache.dart';
import 'package:foodiefy/shopping/quantities.dart';
import 'package:foodiefy/shopping/shopping_repository.dart';
import 'cloud_persistence_test.dart' show TestSession;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('servings 2 to 4, fractions, unknown and per100g without mass', () {
    expect(scaleFactor(base: 2, desired: 4), 2);
    expect(knownNumber('1/2'), .5);
    expect(knownNumber('1/0'), null);
    expect(
      scaledIngredient({
        'name': 'harina',
        'raw_text': '1/2 g',
        'quantity': .5,
      }, 2)['quantity'],
      1,
    );
    expect(
      scaledIngredient({'name': 'sal', 'raw_text': 'al gusto'}, 2)['quantity'],
      null,
    );
    expect(() => scaleFactor(desired: 4), throwsArgumentError);
    expect(scaleFactor(multiplier: 1.5), 1.5);
    expect(
      nutritionFactor({'basis': 'per_100g'}, 'per_serving', servings: 2),
      null,
    );
    expect(
      nutritionFactor({'basis': 'whole_recipe'}, 'per_serving', servings: 2),
      .5,
    );
    expect(humanQuantity(.125), '0.125');
  });
  test(
    'offline add check restart replay response loss delete and A B isolation',
    () async {
      final dir = await Directory.systemTemp.createTemp('shopping-test-');
      final file = File('${dir.path}/cache.sqlite');
      final session = TestSession('A');
      var online = false, lose = false, writes = 0;
      final receipts = <String, Map<String, dynamic>>{};
      final server = <String, Map<String, dynamic>>{};
      Future<Map<String, dynamic>> call(
        String owner,
        String? op,
        String? kind,
        Map<String, dynamic> p,
      ) async {
        if (!online) throw const SocketException('offline');
        if (op == null) {
          return {
            'items': server.values
                .where((e) => e['owner_id'] == owner)
                .toList(),
          };
        }
        if (receipts.containsKey(op)) return receipts[op]!;
        final result = <String, dynamic>{
          ...?server[p['id']],
          ...p,
          'owner_id': owner,
          'checked': kind == 'add'
              ? false
              : p['checked'] ?? server[p['id']]?['checked'],
          'revision': (server[p['id']]?['revision'] as int? ?? 0) + 1,
          if (kind == 'delete') 'deleted_at': 'server tombstone',
        };
        server[p['id']] = result;
        receipts[op] = result;
        writes++;
        if (lose) {
          lose = false;
          throw const SocketException('response lost');
        }
        return result;
      }

      var cache = LocalCache(NativeDatabase(file));
      var repo = ShoppingRepository(session, cache, call);
      await repo.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await repo.enqueue('add', {
        'id': 'manual',
        'name': 'papel de cocina',
        'raw_text': 'papel de cocina',
      });
      await repo.enqueue('checked', {
        'id': 'manual',
        'revision': 0,
        'checked': true,
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.queue.length, 2);
      expect(repo.items.single['checked'], true);
      repo.dispose();
      await cache.close();
      cache = LocalCache(NativeDatabase(file));
      repo = ShoppingRepository(session, cache, call);
      await repo.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.queue.length, 2);
      online = true;
      lose = true;
      await repo.sync();
      expect(repo.queue.length, 2);
      expect(writes, 1);
      await repo.sync();
      expect(repo.queue, isEmpty);
      expect(writes, 2);
      expect(repo.items.single['checked'], true);
      online = false;
      await repo.enqueue('delete', {'id': 'manual', 'revision': 2});
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.items.single['deleted_at'], isNotNull);
      session.change('B');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.items, isEmpty);
      expect(repo.queue, isEmpty);
      online = true;
      await repo.sync();
      expect(writes, 2);
      session.change('A');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await repo.sync();
      expect(writes, 3);
      expect(repo.queue, isEmpty);
      expect(repo.items.single['deleted_at'], isNotNull);
      repo.dispose();
      await cache.close();
      session.dispose();
      await dir.delete(recursive: true);
    },
  );
  test('library cleanup cannot remove shopping outbox', () async {
    final cache = LocalCache(NativeDatabase.memory());
    await cache.writeShopping('A', {
      'queue': [
        {'operation_id': 'stable'},
      ],
    });
    await cache.clearOwner('A');
    await cache.retainOnly('B');
    expect((await cache.readShopping('A'))!['queue'], isNotEmpty);
    await cache.close();
  });
  test('logout guard retains session with pending work', () async {
    final session = TestSession('A');
    session.beforeSignOut = () async => throw StateError('pending');
    await expectLater(session.signOut(), throwsStateError);
    expect(session.ownerId, 'A');
    session.dispose();
  });
  test('merged identity retargets checked edit delete dependencies', () async {
    final session = TestSession('A'),
        cache = LocalCache(NativeDatabase.memory());
    var online = false;
    var revision = 1;
    Map<String, dynamic> row = {
      'id': 'merged',
      'owner_id': 'A',
      'name': 'arroz',
      'raw_text': 'arroz',
      'quantity': 500,
      'unit': 'g',
      'revision': revision,
      'checked': false,
    };
    final repo = ShoppingRepository(session, cache, (owner, op, kind, p) async {
      if (!online) throw const SocketException('offline');
      if (op == null) {
        return {
          'items': [row],
        };
      }
      if (kind != 'add') {
        expect(p['id'], 'merged');
        expect(p['revision'], revision);
      }
      row = {
        ...row,
        ...p,
        'id': 'merged',
        'owner_id': 'A',
        'revision': ++revision,
        if (kind == 'delete') 'deleted_at': 'deleted',
      };
      return row;
    });
    await repo.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await repo.enqueueBatch([
      (
        'add',
        {
          'id': 'local',
          'name': 'arroz',
          'raw_text': 'arroz',
          'quantity': 500,
          'unit': 'g',
        },
      ),
      ('checked', {'id': 'local', 'revision': 0, 'checked': true}),
      (
        'edit',
        {
          'id': 'local',
          'revision': 0,
          'name': 'arroz',
          'quantity': 1200,
          'unit': 'g',
        },
      ),
      ('delete', {'id': 'local', 'revision': 0}),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    online = true;
    await repo.sync();
    expect(repo.queue, isEmpty);
    expect(row['deleted_at'], 'deleted');
    repo.dispose();
    await cache.close();
    session.dispose();
  });
  test(
    'quantity conflict survives restart and needs explicit reviewed revision',
    () async {
      final session = TestSession('A'),
          cache = LocalCache(NativeDatabase.memory());
      var row = <String, dynamic>{
        'id': 'item',
        'owner_id': 'A',
        'name': 'arroz',
        'raw_text': 'arroz',
        'quantity': 600,
        'revision': 2,
        'checked': false,
      };
      Future<Map<String, dynamic>> call(
        String owner,
        String? op,
        String? kind,
        Map<String, dynamic> p,
      ) async {
        if (op == null) {
          return {
            'items': [row],
          };
        }
        if (p['revision'] != row['revision']) {
          throw const PostgrestException(
            message: 'shopping_revision_conflict',
            code: '40001',
          );
        }
        row = {...row, ...p, 'revision': 3};
        return row;
      }

      var repo = ShoppingRepository(session, cache, call);
      await repo.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repo.enqueue('edit', {
        'id': 'item',
        'name': 'arroz',
        'quantity': 900,
        'revision': 1,
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repo.queue.single['conflict'], true);
      expect(row['quantity'], 600);
      repo.dispose();
      repo = ShoppingRepository(session, cache, call);
      await repo.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repo.queue.single['payload']['quantity'], 900);
      final current = await repo.conflictVersion();
      await repo.resolveConflict(current!);
      expect(row['quantity'], 900);
      expect(repo.queue, isEmpty);
      repo.dispose();
      await cache.close();
      session.dispose();
    },
  );
  test('bounded batch is all or nothing offline', () async {
    final session = TestSession('A'),
        cache = LocalCache(NativeDatabase.memory());
    final repo = ShoppingRepository(
      session,
      cache,
      (a, b, c, d) async => throw const SocketException('offline'),
    );
    await repo.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await expectLater(
      repo.enqueueBatch(
        List.generate(
          201,
          (i) => (
            'add',
            <String, dynamic>{'name': 'manual $i', 'raw_text': 'manual $i'},
          ),
        ),
      ),
      throwsStateError,
    );
    expect(repo.queue, isEmpty);
    expect(repo.items, isEmpty);
    repo.dispose();
    await cache.close();
    session.dispose();
  });
  test(
    'ingredient edit invalidates old estimate, explicit label input survives',
    () {
      final fixtures = jsonDecode(
        File('contracts/shopping.v1.fixtures.json').readAsStringSync(),
      );
      final base = Map<String, dynamic>.from(fixtures['base_recipe']);
      base['nutrition'] = {
        'basis': 'whole_recipe',
        'method': 'ai_estimate',
        'kcal': 100,
        'protein_g': null,
        'carbs_g': null,
        'fat_g': null,
        'assumptions': ['Estimación sintética'],
        'status': 'partial',
        'known_mass_g': null,
      };
      Recipe recipe(String? method) => Recipe(
        id: 'test',
        title: base['title'],
        ingredients: ['Cambiar ingrediente'],
        steps: ['Mezclar'],
        createdAt: DateTime(2026),
        cloudDraft: base,
        nutritionInputMethod: method,
        macronutrients: const RecipeMacronutrients(totalKcal: 100),
      );
      expect(RecipeCodec.draft(recipe(null))['nutrition'], null);
      final label = RecipeCodec.draft(recipe('source_label'))['nutrition'];
      expect(label['method'], 'source_label');
      expect(label['protein_g'], null);
      expect(label['basis'], 'whole_recipe');
    },
  );
  testWidgets(
    'nutrition unknown stays unavailable and basis conversion is arithmetic',
    (tester) async {
      final recipe = Recipe(
        id: 'test',
        title: 'Revisada',
        ingredients: ['arroz'],
        steps: ['Cocer'],
        createdAt: DateTime(2026),
        cloudDraft: {
          'servings': 2,
          'nutrition': {
            'basis': 'whole_recipe',
            'method': 'ai_estimate',
            'status': 'partial',
            'kcal': 100,
            'protein_g': null,
            'carbs_g': null,
            'fat_g': null,
            'assumptions': ['Prueba revisada'],
            'known_mass_g': null,
          },
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: HonestNutrition(recipe: recipe)),
          ),
        ),
      );
      expect(find.text('Estimación'), findsOneWidget);
      expect(find.text('Proteínas (g): —'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Por ración').last);
      await tester.pumpAndSettle();
      expect(find.text('Energía (kcal): 50'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Por 100 g').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Conversión no disponible: faltan raciones o masa conocida.'),
        findsOneWidget,
      );
    },
  );
}
