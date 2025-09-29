// lib/services/storage_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';

class StorageService {
  static const String _recipesKey = 'recipes';
  
  static Future<List<Recipe>> getRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final recipesJson = prefs.getStringList(_recipesKey) ?? [];
    
    return recipesJson
        .map((json) => Recipe.fromJson(jsonDecode(json)))
        .toList();
  }
  
  static Future<void> saveRecipe(Recipe recipe) async {
    final recipes = await getRecipes();
    recipes.add(recipe);
    await _saveRecipes(recipes);
  }
  
  static Future<void> updateRecipe(Recipe recipe) async {
    final recipes = await getRecipes();
    final index = recipes.indexWhere((r) => r.id == recipe.id);
    if (index != -1) {
      recipes[index] = recipe;
      await _saveRecipes(recipes);
    }
  }
  
  static Future<void> deleteRecipe(String id) async {
    final recipes = await getRecipes();
    recipes.removeWhere((r) => r.id == id);
    await _saveRecipes(recipes);
  }
  
  static Future<void> _saveRecipes(List<Recipe> recipes) async {
    final prefs = await SharedPreferences.getInstance();
    final recipesJson = recipes
        .map((recipe) => jsonEncode(recipe.toJson()))
        .toList();
    await prefs.setStringList(_recipesKey, recipesJson);
  }
}