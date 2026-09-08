import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiefy/config/app_config.dart';
import 'package:foodiefy/main.dart' as app;
import 'package:foodiefy/models/recipe.dart';
import 'package:foodiefy/screens/create_recipe_screen.dart';
import 'package:foodiefy/screens/recipe_detail_screen.dart';
import 'package:foodiefy/screens/user_screen.dart';
import 'package:foodiefy/services/storage_service.dart';
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
      await expectLater(
        StorageService.saveRecipe(legacyRecipe('new')),
        throwsStateError,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('recipes')!.take(4), raw);
      await expectLater(
        StorageService.updateRecipe(legacyRecipe('old')),
        throwsStateError,
      );
      await expectLater(StorageService.deleteRecipe('old'), throwsStateError);
      expect((await StorageService.getRecipes()).length, 3);
    },
  );
  test(
    'phase04 legacy writes are read-only and never mutate originals',
    () async {
      final raw = jsonEncode(legacyRecipe('a').toJson());
      SharedPreferences.setMockInitialValues({
        'recipes': [raw],
      });
      await expectLater(
        StorageService.saveRecipe(legacyRecipe('b')),
        throwsStateError,
      );
      await expectLater(
        StorageService.updateRecipe(legacyRecipe('a')),
        throwsStateError,
      );
      await expectLater(StorageService.deleteRecipe('a'), throwsStateError);
      expect((await SharedPreferences.getInstance()).getStringList('recipes'), [
        raw,
      ]);
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
    await tester.runAsync(app.main);
    await tester.pumpAndSettle();
    expect(find.text('Foodiefy'), findsOneWidget);
    expect(tester.widget<Banner>(find.byType(Banner)).message, 'RESCATE LOCAL');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      const MaterialApp(home: UserScreen(savedRecipes: 0)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Rescatar datos antiguos / exportar backup'),
      findsOneWidget,
    );
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
  testWidgets('legacy editing is rejected and original remains intact', (
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
}
