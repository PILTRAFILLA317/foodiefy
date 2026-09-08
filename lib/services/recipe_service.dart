import '../models/recipe.dart';
import '../repositories/app_repositories.dart';
import 'storage_service.dart';

/// Compatibility facade: persistence is owned by the injected repositories.
class RecipeService {
  static Future<List<Recipe>> getAllRecipes() => StorageService.getRecipes();
  static Future<void> createRecipe(Recipe recipe, {String? collectionId}) =>
      AppRepositories.writable.saveRecipe(
        recipe,
        initialCollectionId: collectionId,
      );
  static Future<void> updateRecipe(Recipe recipe) =>
      AppRepositories.writable.saveRecipe(recipe, editing: true);
  static Future<void> deleteRecipe(String id) =>
      AppRepositories.writable.deleteRecipe(id);
}
