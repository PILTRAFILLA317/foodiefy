import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foodiefy/models/recipe.dart';
import 'package:foodiefy/models/collection.dart';

class CollectionService {
  static const String _collectionsKey = 'recipe_collections';
  static const String _recipesKey = 'recipes';

  // Collections methods
  Future<List<RecipeCollection>> getCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final collectionsJson = prefs.getStringList(_collectionsKey) ?? [];
    return collectionsJson
        .map((json) => RecipeCollection.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> saveCollection(RecipeCollection collection) async {
    final collections = await getCollections();
    final index = collections.indexWhere((c) => c.id == collection.id);
    
    if (index >= 0) {
      collections[index] = collection;
    } else {
      collections.add(collection);
    }
    
    await _saveCollections(collections);
  }

  Future<void> deleteCollection(String collectionId) async {
    final collections = await getCollections();
    collections.removeWhere((c) => c.id == collectionId);
    await _saveCollections(collections);
  }

  Future<void> _saveCollections(List<RecipeCollection> collections) async {
    final prefs = await SharedPreferences.getInstance();
    final collectionsJson = collections
        .map((collection) => jsonEncode(collection.toJson()))
        .toList();
    await prefs.setStringList(_collectionsKey, collectionsJson);
  }

  // Recipes methods
  Future<List<Recipe>> getRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final recipesJson = prefs.getStringList(_recipesKey) ?? [];
    return recipesJson
        .map((json) => Recipe.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<Recipe?> getRecipeById(String id) async {
    final recipes = await getRecipes();
    try {
      return recipes.firstWhere((recipe) => recipe.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<List<Recipe>> getRecipesByIds(List<String> ids) async {
    final recipes = await getRecipes();
    return recipes.where((recipe) => ids.contains(recipe.id)).toList();
  }

  Future<void> addRecipeToCollection(
      String collectionId, String recipeId) async {
    final collections = await getCollections();
    final collectionIndex =
        collections.indexWhere((c) => c.id == collectionId);

    if (collectionIndex >= 0) {
      final collection = collections[collectionIndex];
      if (!collection.recipeIds.contains(recipeId)) {
        final updatedCollection = RecipeCollection(
          id: collection.id,
          name: collection.name,
          description: collection.description,
          coverImagePath: collection.coverImagePath,
          recipeIds: [...collection.recipeIds, recipeId],
          createdAt: collection.createdAt,
          updatedAt: DateTime.now(),
        );
        await saveCollection(updatedCollection);
      }
    }
  }

  Future<void> removeRecipeFromCollection(
      String collectionId, String recipeId) async {
    final collections = await getCollections();
    final collectionIndex =
        collections.indexWhere((c) => c.id == collectionId);

    if (collectionIndex >= 0) {
      final collection = collections[collectionIndex];
      final updatedRecipeIds = collection.recipeIds
          .where((id) => id != recipeId)
          .toList();

      final updatedCollection = RecipeCollection(
        id: collection.id,
        name: collection.name,
        description: collection.description,
        coverImagePath: collection.coverImagePath,
        recipeIds: updatedRecipeIds,
        createdAt: collection.createdAt,
        updatedAt: DateTime.now(),
      );
      await saveCollection(updatedCollection);
    }
  }
}