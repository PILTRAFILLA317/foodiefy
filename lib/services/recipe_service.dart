// lib/services/recipe_service.dart
import '../models/recipe.dart';
import 'storage_service.dart';
import 'collection_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
// import 'api_service.dart';

class RecipeService {
  static Future<List<Recipe>> getAllRecipes() async {
    return await StorageService.getRecipes();
  }
  
  static Future<void> createRecipe(Recipe recipe) async {
    await StorageService.saveRecipe(recipe);
    // Añade la receta a la colección "Todas las recetas" (id: "0")
    await CollectionService().addRecipeToCollection("0", recipe.id);
    // Also try to persist the saved relation in Supabase for the current user
    try {
      await saveRecipeForCurrentUser(recipeId: recipe.id);
    } catch (e) {
      debugPrint('[recipe_service] saveRecipeForCurrentUser error: $e');
    }
  }
  
  static Future<void> updateRecipe(Recipe recipe) async {
    await StorageService.updateRecipe(recipe);
  }
  
  static Future<void> deleteRecipe(String id) async {
    await StorageService.deleteRecipe(id);
  }

  /// Save (or upsert) the relation user -> recipe in Supabase `user_recipes`.
  /// If there's no authenticated user this function is a no-op.
  static Future<void> saveRecipeForCurrentUser({
    required String recipeId,
  }) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      // No authenticated user — nothing to do server-side.
      return;
    }

    final payload = {
      'user_id': user.id,
      'recipe_id': recipeId,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      // Use upsert on the composite key (user_id, recipe_id) to avoid duplicates.
      await supabase
          .from('user_recipes')
          .upsert(payload, onConflict: 'user_id,recipe_id')
          .select()
          .maybeSingle();
    } catch (e) {
      debugPrint('[recipe_service] saveRecipeForCurrentUser supabase error: $e');
      // Don't rethrow — keep local flow resilient when network/backend fail.
    }
  }
}