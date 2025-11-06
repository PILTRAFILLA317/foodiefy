import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foodiefy/models/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

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
    debugPrint('Adding recipe $recipeId to collection $collectionId');
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

    // Try to mirror in Supabase if we have a logged in user
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        // upsert collection_recipes row
        await Supabase.instance.client.from('collection_recipes').insert({
          'collection_id': collectionId,
          'recipe_id': recipeId,
          'user_id': userId,
        }).select();
      }
    } catch (e) {
      debugPrint('[collection_service] addRecipeToCollection supabase error: $e');
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

    // mirror removal in Supabase
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client
            .from('collection_recipes')
            .delete()
            .match({
          'collection_id': collectionId,
          'recipe_id': recipeId,
          'user_id': userId,
        }).select();
      }
    } catch (e) {
      debugPrint('[collection_service] removeRecipeFromCollection supabase error: $e');
    }
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

    // delete in Supabase as well (will cascade to collection_recipes)
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
    await Supabase.instance.client
      .from('collections')
      .delete()
      .match({'id': collection.id, 'user_id': userId}).select();
      }
    } catch (e) {
      debugPrint('[collection_service] deleteCollection supabase error: $e');
    }
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

    // create collection in Supabase (if logged in)
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        debugPrint('Creating collection in Supabase for user $userId');
        // let the DB generate a UUID id to keep types consistent
        final res = await Supabase.instance.client.from('collections').insert({
          'user_id': userId,
          'name': newCollection.name,
          // 'description': newCollection.description,
          // 'cover_image_path': newCollection.coverImagePath,
        }).select();

        if (res is List && res.isNotEmpty) {
          try {
            final returned = res[0];
            if (returned is Map<String, dynamic>) {
              final returnedId = returned['id'] as String?;
              if (returnedId != null) {
                // update local collection id to the DB-generated uuid
                final updated = RecipeCollection(
                  id: returnedId,
                  name: newCollection.name,
                  // description: newCollection.description,
                  // coverImagePath: newCollection.coverImagePath,
                  recipeIds: newCollection.recipeIds,
                  createdAt: newCollection.createdAt,
                  updatedAt: newCollection.updatedAt,
                  isMaster: newCollection.isMaster,
                );

                // replace the temporary collection in local storage
                final idx = collections.indexWhere((c) => c.id == newCollection.id);
                if (idx != -1) {
                  collections[idx] = updated;
                  final updatedJson = collections.map((c) => jsonEncode(c.toJson())).toList();
                  await prefs.setStringList('collections', updatedJson);
                }
              }
            }
          } catch (_) {
            debugPrint('Failed to parse supabase collection creation response');
            // ignore parsing errors
          }
        }
      }
      else {
        debugPrint('No logged in user, skipping Supabase collection creation');
      }
    } catch (e) {
      debugPrint('[collection_service] saveCollection supabase error: $e');
    }
  }
}