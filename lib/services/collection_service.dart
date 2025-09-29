import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foodiefy/models/collection.dart';

// import 'api_service.dart';

class CollectionService {
  // static Future<List<Recipe>> getAllRecipes() async {
  //   return await StorageService.getRecipes();
  // }
  
  // static Future<void> createRecipe(Recipe recipe) async {
  //   await StorageService.saveRecipe(recipe);
  // }
  
  // // static Future<Recipe> importRecipeFromUrl(String url) async {
  // //   final recipe = await ApiService.extractRecipeFromUrl(url);
  // //   await StorageService.saveRecipe(recipe);
  // //   return recipe;
  // // }
  
  // static Future<void> updateRecipe(Recipe recipe) async {
  //   await StorageService.updateRecipe(recipe);
  // }
  
  // static Future<void> deleteRecipe(String id) async {
  //   await StorageService.deleteRecipe(id);
  // }

  Future<void> addRecipeToCollection(String collectionId, String recipeId) async {
    final prefs = await SharedPreferences.getInstance();
    final collections = await getCollections();

    final index = collections.indexWhere((c) => c.id == collectionId);
    if (index == -1) return;

    final collection = collections[index];
    if (!collection.recipeIds.contains(recipeId)) {
      collection.recipeIds.add(recipeId);
      // collection.updatedAt = DateTime.now();
      collections[index] = collection;

      final collectionsJson = collections
          .map((c) => jsonEncode(c.toJson()))
          .toList();

      await prefs.setStringList('collections', collectionsJson);
    }
  }

  Future<List<RecipeCollection>> getCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final collectionsJson = prefs.getStringList('collections') ?? [];
    return collectionsJson
        .map((json) => RecipeCollection.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> removeRecipeFromCollection(String collectionId, String recipeId) async {
    final prefs = await SharedPreferences.getInstance();
    final collections = await getCollections();

    final index = collections.indexWhere((c) => c.id == collectionId);
    if (index == -1) return;

    final target = collections[index];
    if (!target.recipeIds.contains(recipeId)) return;

    final updatedIds = List<String>.from(target.recipeIds)..remove(recipeId);

    collections[index] = RecipeCollection(
      id: target.id,
      name: target.name,
      description: target.description,
      coverImagePath: target.coverImagePath,
      recipeIds: updatedIds,
      createdAt: target.createdAt,
      updatedAt: DateTime.now(),
      isMaster: target.isMaster,
    );

    final collectionsJson = collections
        .map((collection) => jsonEncode(collection.toJson()))
        .toList();

    await prefs.setStringList('collections', collectionsJson);
  }

  // Future<RecipeCollection> getCollectionById(String id) async {
  //   final collections = await getCollections();

  // }

  Future<void> deleteCollection(RecipeCollection collection) async {
    final prefs = await SharedPreferences.getInstance();
    final collections = await getCollections();
    
    collections.removeWhere((c) => c.id == collection.id);
    
    final collectionsJson = collections
        .map((c) => jsonEncode(c.toJson()))
        .toList();
    
    await prefs.setStringList('collections', collectionsJson);
  }

  Future<void> saveCollection(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final collections = await getCollections();
    
    final newCollection = RecipeCollection(
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      recipeIds: [],
      isMaster: false,
    );
    
    collections.add(newCollection);
    
    final collectionsJson = collections
        .map((collection) => jsonEncode(collection.toJson()))
        .toList();
    
    await prefs.setStringList('collections', collectionsJson);
  }
}