import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';

class StorageService {
  static const String _recipesKey = 'recipes';
  static Future<void>? _pending;

  static Future<List<Recipe>> getRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recipesKey) ?? [];
    final recipes = <Recipe>[];
    var unreadable = 0;
    for (final entry in raw) {
      try {
        recipes.add(Recipe.fromJson(jsonDecode(entry)));
      } catch (_) {
        unreadable++;
      }
    }
    final ids = <String>{};
    var collisions = 0;
    var empty = 0;
    for (final recipe in recipes) {
      if (recipe.id.trim().isEmpty) empty++;
      if (!ids.add(recipe.id)) collisions++;
    }
    if (unreadable + collisions + empty > 0) {
      debugPrint(
        '[legacy] unreadable=$unreadable duplicate_ids=$collisions empty_ids=$empty; raw data preserved',
      );
    }
    return recipes;
  }

  /// Raw strings preserve unknown fields, collisions and even unreadable records.
  static Future<String> exportLegacyJson() async {
    final prefs = await SharedPreferences.getInstance();
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'foodiefy-legacy-v1',
      'recipes': prefs.getStringList(_recipesKey) ?? [],
      'collections': prefs.getStringList('collections') ?? [],
    });
  }

  static Future<void> _mutate(void Function(List<String>) change) {
    final next = (_pending ?? Future<void>.value()).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final raw = List<String>.from(prefs.getStringList(_recipesKey) ?? []);
      change(raw);
      if (!await prefs.setStringList(_recipesKey, raw)) {
        throw StateError('No se pudo guardar la receta local.');
      }
    });
    final barrier = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending = barrier;
    return next.whenComplete(() {
      if (identical(_pending, barrier)) _pending = null;
    });
  }

  static String? _id(String raw) {
    try {
      final data = jsonDecode(raw);
      return data is Map ? data['id'] as String? : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveRecipe(Recipe recipe) => _mutate((raw) {
    if (recipe.id.trim().isEmpty || raw.any((r) => _id(r) == recipe.id)) {
      throw StateError('La receta nueva requiere un ID único y no vacío.');
    }
    raw.add(jsonEncode(recipe.toJson()));
  });

  static Future<void> updateRecipe(Recipe recipe) => _mutate((raw) {
    final matches = [
      for (var i = 0; i < raw.length; i++)
        if (_id(raw[i]) == recipe.id) i,
    ];
    if (recipe.id.trim().isEmpty || matches.length != 1) {
      throw StateError(
        'No se puede editar un ID legacy ausente o ambiguo. Exporta una copia primero.',
      );
    }
    raw[matches.single] = jsonEncode({
      ...Map<String, dynamic>.from(jsonDecode(raw[matches.single])),
      ...recipe.toJson(),
    });
  });

  static Future<void> deleteRecipe(String id) => _mutate((raw) {
    final matches = raw.where((r) => _id(r) == id).length;
    if (id.trim().isEmpty || matches != 1) {
      throw StateError('No se puede eliminar un ID legacy ausente o ambiguo.');
    }
    raw.removeWhere((r) => _id(r) == id);
  });
}
