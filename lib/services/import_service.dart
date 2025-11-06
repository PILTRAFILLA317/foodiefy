import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/recipe.dart';

// import 'package:uuid/uuid.dart';

class ImportRecipeService {
  // ImportRecipeService({http.Client? client}) : _client = client ?? http.Client();

  // final http.Client _client;

  Future<Recipe> importRecipeFromUrl(String url) async {
    final uri = Uri.parse('http://127.0.0.1:8000/api/analyze-recipe');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'url': url}),
    );

    if (response.statusCode != 200) {
      throw ImportRecipeException(
        'Error ${response.statusCode} al contactar la API',
      );
    }
    print('ImportRecipeService response: ${response.body}');
    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;
    final recipeData = body['recipe'];

    if (body['success'] != true || recipeData is! Map<String, dynamic>) {
      throw ImportRecipeException('La API no devolvió una receta válida');
    }

    return _mapRecipeFromApi(recipeData, sourceUrl: url);
  }

  Recipe _mapRecipeFromApi(Map<String, dynamic> recipe, {String? sourceUrl}) {
    final id = recipe['id'] as String? ?? '';
    final title = recipe['titulo'] as String? ?? 'Receta importada';
    final description = recipe['descripcion'] as String?;
    final ingredients = _stringListFromDynamic(recipe['ingredientes']);
    final steps = _stringListFromDynamic(recipe['pasos']);
    final prepTimeText = recipe['tiempo_preparacion'] as String?;
    final prepTime = _parsePrepTime(prepTimeText);
    final imageUrl = recipe['imagen'] as String?;
    final originalUrl = recipe['url'] as String?;
    final uploader = recipe['uploader'] as String?;
    final platform = recipe['platform'] as String?;
    final thumbnail = recipe['thumbnail'] as String?;
    final finalQuantity =
        recipe['cantidad_final'] as String? ?? 'No especificado';
    final macronutrients =
        _parseMacronutrients(
          recipe['macronutrientes'] as Map<String, dynamic>?,
        ) ??
        const RecipeMacronutrients(
          totalKcal: 3500,
          carbsGrams: 400,
          proteinGrams: 50,
          fatGrams: 200,
          carbsPercentage: 46,
          proteinPercentage: 6,
          fatPercentage: 48,
        );

    return Recipe(
      id: id,
      title: title,
      description: description,
      ingredients: ingredients,
      steps: steps,
      imagePath: imageUrl ?? thumbnail,
      originalVideoUrl: originalUrl,
      sourceUrl: sourceUrl ?? originalUrl,
      isImported: true,
      isPublic: false,
      prepTimeMinutes: prepTime,
      prepTimeText: prepTimeText,
      uploader: uploader,
      platform: platform,
      thumbnailUrl: thumbnail,
      finalQuantity: finalQuantity,
      macronutrients: macronutrients,
      createdAt: DateTime.now(),
    );
  }

  List<String> _stringListFromDynamic(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return const [];
  }

  int? _parsePrepTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final match = RegExp(r'(\d{1,3})').firstMatch(value);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  RecipeMacronutrients? _parseMacronutrients(Map<String, dynamic>? data) {
    if (data == null) return null;
    try {
      return RecipeMacronutrients.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}

class ImportRecipeException implements Exception {
  ImportRecipeException(this.message);

  final String message;

  @override
  String toString() => 'ImportRecipeException: $message';
}
