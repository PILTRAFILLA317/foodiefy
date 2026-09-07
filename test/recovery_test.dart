import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiefy/config/app_config.dart';
import 'package:foodiefy/main.dart' as app;
import 'package:foodiefy/models/recipe.dart';
import 'package:foodiefy/screens/create_recipe_screen.dart';
import 'package:foodiefy/screens/import_recipe_screen.dart';
import 'package:foodiefy/screens/recipe_detail_screen.dart';
import 'package:foodiefy/screens/user_screen.dart';
import 'package:foodiefy/services/import_service.dart';
import 'package:foodiefy/services/storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppConfig testConfig() => AppConfig.fromValues({
  'APP_ENV': 'local',
  'LOCAL_RESCUE': 'false',
  'API_BASE_URL': 'http://127.0.0.1:8000',
  'SUPABASE_URL': 'https://example.invalid',
  'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_test_fixture',
});

Map<String, dynamic> payload({String? id}) => {
  'success': true,
  'recipe': {
    'if_unused': null,
    if (id != null) 'id': id,
    'titulo': 'Receta de prueba',
    'ingredientes': ['Un ingrediente'],
    'pasos': ['Cocinar'],
  },
};

Recipe legacyRecipe(String id) => Recipe(
  id: id,
  title: 'Receta local',
  ingredients: ['Ingrediente'],
  steps: ['Paso'],
  createdAt: DateTime(2025),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppConfig.current = AppConfig.fromValues({});
  });

  for (final id in [null, '', ' ', 'provider-id']) {
    test('new imports use distinct UUIDs for provider id $id', () async {
      final service = ImportRecipeService(
        config: testConfig(),
        client: MockClient((request) async {
          expect(request.url.path, '/api/analyze-recipe');
          expect(
            jsonDecode(request.body)['url'],
            'https://example.invalid/video',
          );
          return http.Response(jsonEncode(payload(id: id)), 200);
        }),
      );
      addTearDown(service.close);
      final first = await service.importRecipeFromUrl(
        'https://example.invalid/video',
      );
      final second = await service.importRecipeFromUrl(
        'https://example.invalid/video',
      );
      expect(
        first.id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(first.id, isNot(second.id));
      expect(first.macronutrients, isNull);
      await StorageService.saveRecipe(first);
      await StorageService.saveRecipe(second);
      expect((await StorageService.getRecipes()).length, 2);
    });
  }

  for (final value in [
    null,
    -1,
    'bad',
    'NaN',
    'Infinity',
    double.infinity,
    double.nan,
    '-2.5',
  ]) {
    test('invalid nutrition is unavailable: $value', () {
      expect(
        RecipeMacronutrients.fromJson({'kcal_totales': value}).totalKcal,
        isNull,
      );
    });
  }
  test('nutrition preserves decimals, comma input and explicit zero', () {
    final macros = RecipeMacronutrients.fromJson({
      'kcal_totales': 12.75,
      'proteinas_gramos': '1,25',
      'grasas_gramos': 0,
    });
    expect(macros.totalKcal, 12.75);
    expect(macros.proteinGrams, 1.25);
    expect(macros.fatGrams, 0);
    expect(macros.carbsGrams, isNull);
    expect(RecipeMacronutrients.fromJson(macros.toJson()).totalKcal, 12.75);
  });

  final cases = [
    (503, '{}', 'unavailable'),
    (401, '{}', 'unauthorized'),
    (429, '{}', 'rate_limited'),
    (500, '{}', 'http_error'),
    (200, '{bad', 'invalid_json'),
    (200, '[]', 'invalid_payload'),
    (200, '{"success":false}', 'remote_failure'),
    (200, '{"success":true}', 'invalid_payload'),
    (200, '{"success":true,"recipe":{"titulo":"Title"}}', 'invalid_payload'),
  ];
  for (final (status, body, code) in cases) {
    test('import maps $status/$code', () async {
      final service = ImportRecipeService(
        config: testConfig(),
        client: MockClient((_) async => http.Response(body, status)),
      );
      addTearDown(service.close);
      await expectLater(
        service.importRecipeFromUrl('https://example.invalid/video'),
        throwsA(
          isA<ImportRecipeException>().having((e) => e.code, 'code', code),
        ),
      );
    });
  }
  test('request timeout is a domain error', () async {
    final service = ImportRecipeService(
      config: testConfig(),
      requestTimeout: const Duration(milliseconds: 5),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(service.close);
    await expectLater(
      service.importRecipeFromUrl('https://example.invalid/video'),
      throwsA(
        isA<ImportRecipeException>().having((e) => e.code, 'code', 'timeout'),
      ),
    );
  });
  test('rescue never sends HTTP', () async {
    final service = ImportRecipeService(
      client: MockClient((_) => throw StateError('network forbidden')),
    );
    addTearDown(service.close);
    await expectLater(
      service.importRecipeFromUrl('https://example.invalid/video'),
      throwsA(
        isA<ImportRecipeException>().having((e) => e.code, 'code', 'disabled'),
      ),
    );
  });
  test(
    'legacy read and export retain exact raw strings including collisions',
    () async {
      final raw = [
        jsonEncode(legacyRecipe('').toJson()),
        jsonEncode(legacyRecipe('old').toJson()),
        jsonEncode({...legacyRecipe('old').toJson(), 'unknown': 'preserved'}),
        '{unreadable',
      ];
      SharedPreferences.setMockInitialValues({
        'recipes': raw,
        'collections': ['{legacy-collection'],
      });
      final recipes = await StorageService.getRecipes();
      expect(recipes.map((r) => r.id), ['', 'old', 'old']);
      expect(
        jsonDecode(await StorageService.exportLegacyJson())['recipes'],
        raw,
      );
      await StorageService.saveRecipe(legacyRecipe('new'));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('recipes')!.take(4), raw);
      await expectLater(
        StorageService.updateRecipe(legacyRecipe('old')),
        throwsStateError,
      );
      await expectLater(StorageService.deleteRecipe('old'), throwsStateError);
      expect((await StorageService.getRecipes()).length, 4);
    },
  );
  test(
    'create rejects empty/duplicate IDs and concurrent saves retain both',
    () async {
      await expectLater(
        StorageService.saveRecipe(legacyRecipe('')),
        throwsStateError,
      );
      await Future.wait([
        StorageService.saveRecipe(legacyRecipe('a')),
        StorageService.saveRecipe(legacyRecipe('b')),
      ]);
      await expectLater(
        StorageService.saveRecipe(legacyRecipe('a')),
        throwsStateError,
      );
      await StorageService.updateRecipe(legacyRecipe('a'));
      expect((await StorageService.getRecipes()).length, 2);
    },
  );
  test('config enforces public keys and HTTPS outside local', () {
    expect(AppConfig.fromValues({}).rescueMode, isTrue);
    for (final values in [
      {'APP_ENV': 'typo'},
      {'LOCAL_RESCUE': 'typo'},
      {'APP_ENV': 'production'},
      {'LOCAL_RESCUE': 'false'},
      {'SUPABASE_PUBLISHABLE_KEY': 'sb_secret_never_mobile'},
      {'API_BASE_URL': 'http://public.example'},
      {
        'APP_ENV': 'production',
        'LOCAL_RESCUE': 'false',
        'API_BASE_URL': 'http://localhost:8000',
      },
    ]) {
      expect(
        () => AppConfig.fromValues(values),
        throwsA(isA<ConfigurationException>()),
      );
    }
    expect(
      () => AppConfig.fromValues({}, release: true),
      throwsA(isA<ConfigurationException>()),
    );
    for (final host in ['127.0.0.1', '10.0.2.2', '192.168.1.10']) {
      expect(
        AppConfig.fromValues({
          'API_BASE_URL': 'http://$host:8000',
        }).apiBaseUrl!.host,
        host,
      );
    }
  });
  testWidgets('actual main opens without dotenv or cloud', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.text('Foodiefy'), findsOneWidget);
    expect(tester.widget<Banner>(find.byType(Banner)).message, 'RESCATE LOCAL');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      const MaterialApp(home: UserScreen(savedRecipes: 0)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Exportar datos legacy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('legacy recipe shows nutrition unavailable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: RecipeDetailScreen(recipe: legacyRecipe('old'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nutrición no disponible'), findsOneWidget);
    expect(find.text('3500'), findsNothing);
  });
  testWidgets('editing a saved template does not add a duplicate', (
    tester,
  ) async {
    final recipe = legacyRecipe('old');
    SharedPreferences.setMockInitialValues({
      'recipes': [jsonEncode(recipe.toJson())],
    });
    await tester.pumpWidget(
      MaterialApp(home: CreateRecipeScreen(template: recipe, isEditing: true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    final saved = await tester.runAsync(StorageService.getRecipes);
    expect(saved!.map((r) => r.id), ['old']);
    expect(saved.single.createdAt, recipe.createdAt);
  });
  testWidgets('cancelled import can finish without setState after dispose', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    final service = ImportRecipeService(
      config: testConfig(),
      client: MockClient((_) => response.future),
    );
    addTearDown(service.close);
    await tester.pumpWidget(
      MaterialApp(
        home: ImportLoadingScreen(
          url: 'https://example.invalid/video',
          service: service,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    response.complete(http.Response(jsonEncode(payload()), 200));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('remote error screen presents a readable failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ImportErrorScreen(
          message: 'La API no pudo importar la receta (HTTP 503).',
        ),
      ),
    );
    await tester.pump();
    expect(
      find.text('La API no pudo importar la receta (HTTP 503).'),
      findsOneWidget,
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
  });
}
