import '../models/recipe.dart';

/// UI adapter for the API-owned v1 snapshot. Structured fields survive edits.
class RecipeCodec {
  static String? text(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
  static String? httpUrl(String? value) {
    final uri = Uri.tryParse(value ?? '');
    return uri != null &&
            ['http', 'https'].contains(uri.scheme) &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty
        ? value
        : null;
  }

  static Map<String, dynamic> draft(Recipe recipe, {bool legacy = false}) {
    final base = recipe.cloudDraft;
    final oldIngredients = (base?['ingredients'] as List?) ?? [];
    final oldSteps = (base?['steps'] as List?) ?? [];
    final macros = recipe.macronutrients;
    // Legacy macro basis/provenance was not recorded; retain raw backup instead of guessing.
    final nutrition = legacy || (recipe.isImported && base == null)
        ? null
        : macros == null
        ? null
        : {
            'basis': 'whole_recipe',
            'kcal': macros.totalKcal,
            'protein_g': macros.proteinGrams,
            'carbs_g': macros.carbsGrams,
            'fat_g': macros.fatGrams,
            'method': 'manual',
            'assumptions': <String>[],
            'status': 'partial',
            'known_mass_g': null,
          };
    return {
      'schema_version': '1.0',
      'title': recipe.title.trim(),
      'description': text(recipe.description),
      'source':
          base?['source'] ??
          {
            'url': httpUrl(recipe.sourceUrl ?? recipe.originalVideoUrl),
            'canonical_url': null,
            'platform': text(recipe.platform),
            'creator': text(recipe.uploader),
            'source_kind':
                recipe.isImported &&
                    httpUrl(recipe.sourceUrl ?? recipe.originalVideoUrl) != null
                ? 'web_page'
                : 'manual',
          },
      'ingredients': [
        for (var i = 0; i < recipe.ingredients.length; i++)
          if (i < oldIngredients.length &&
              oldIngredients[i]['raw_text'] == recipe.ingredients[i])
            oldIngredients[i]
          else
            {
              'position': i + 1,
              'raw_text': recipe.ingredients[i],
              'name': recipe.ingredients[i],
              'quantity': null,
              'quantity_max': null,
              'unit': null,
              'preparation': null,
              'group': null,
              'evidence_source': legacy ? 'source_text' : 'manual',
              'is_estimated': false,
            },
      ],
      'steps': [
        for (var i = 0; i < recipe.steps.length; i++)
          if (i < oldSteps.length && oldSteps[i]['text'] == recipe.steps[i])
            oldSteps[i]
          else
            {
              'position': i + 1,
              'text': recipe.steps[i],
              'duration_seconds': null,
              'temperature_c': null,
              'source_timestamp_seconds': null,
            },
      ],
      'prep_minutes': recipe.prepTimeMinutes,
      'cook_minutes': base?['cook_minutes'],
      'total_minutes': base?['total_minutes'],
      'servings': base?['servings'],
      'yield_text': text(recipe.finalQuantity),
      'nutrition': base != null && _sameMacros(macros, base['nutrition'])
          ? base['nutrition']
          : nutrition,
      'warnings': [
        if (base != null) ...(base['warnings'] as List),
        if (legacy)
          'Legacy raw conservado en backup; revisar campos sin procedencia.',
      ],
    };
  }

  static bool _sameMacros(RecipeMacronutrients? m, dynamic n) => n == null
      ? m == null
      : m?.totalKcal == _number(n['kcal']) &&
            m?.proteinGrams == _number(n['protein_g']) &&
            m?.carbsGrams == _number(n['carbs_g']) &&
            m?.fatGrams == _number(n['fat_g']);
  static double? _number(dynamic n) =>
      n == null ? null : double.tryParse(n.toString());
  static Recipe record(Map<String, dynamic> record, {String? imagePath}) {
    final source = record['source'] as Map;
    final nutrition = record['nutrition'] as Map?;
    final draft = Map<String, dynamic>.from(record)
      ..removeWhere(
        (key, _) => [
          'id',
          'owner_id',
          'revision',
          'created_at',
          'updated_at',
          'deleted_at',
        ].contains(key),
      );
    return Recipe(
      id: record['id'],
      title: record['title'],
      description: record['description'],
      ingredients: [
        for (final item in record['ingredients']) item['raw_text'] as String,
      ],
      steps: [for (final item in record['steps']) item['text'] as String],
      imagePath: imagePath,
      sourceUrl: source['url'],
      platform: source['platform'],
      uploader: source['creator'],
      isImported: source['source_kind'] != 'manual',
      prepTimeMinutes: record['prep_minutes'],
      finalQuantity: record['yield_text'],
      createdAt: DateTime.parse(record['created_at']),
      ownerId: record['owner_id'],
      revision: record['revision'],
      cloudDraft: draft,
      macronutrients: nutrition == null
          ? null
          : RecipeMacronutrients(
              totalKcal: _number(nutrition['kcal']),
              proteinGrams: _number(nutrition['protein_g']),
              carbsGrams: _number(nutrition['carbs_g']),
              fatGrams: _number(nutrition['fat_g']),
            ),
    );
  }
}
