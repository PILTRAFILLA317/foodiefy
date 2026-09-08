import '../config/cloud_runtime.dart';
import '../repositories/app_repositories.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';

class StorageService {
  static const String _recipesKey = 'recipes';

  static Future<List<Recipe>> getRecipes() async {
    if (CloudRuntime.enabled) {
      return await AppRepositories.library?.readRecipes() ?? [];
    }
    return getLegacyRecipes();
  }

  static Future<List<Recipe>> getLegacyRecipes() async {
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

  // Retained compatibility entry points fail explicitly; legacy storage is read-only.
  static Future<void> saveRecipe(Recipe recipe) async =>
      throw StateError('Legacy es de solo lectura. Usa el repositorio cloud.');
  static Future<void> updateRecipe(Recipe recipe) async =>
      throw StateError('Legacy es de solo lectura. Usa el rescate revisado.');
  static Future<void> deleteRecipe(String id) async =>
      throw StateError('No se eliminan datos legacy.');
}
