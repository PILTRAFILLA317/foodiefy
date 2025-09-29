// lib/services/recipe_service.dart
import '../models/recipe.dart';
import 'storage_service.dart';
import 'collection_service.dart';
// import 'api_service.dart';

class RecipeService {
  static Future<List<Recipe>> getAllRecipes() async {
    return await StorageService.getRecipes();
  }
  
  static Future<void> createRecipe(Recipe recipe) async {
    await StorageService.saveRecipe(recipe);
    // Añade la receta a la colección "Todas las recetas" (id: "0")
    await CollectionService().addRecipeToCollection("0", recipe.id);
  }
  // static Future<Recipe> importRecipeFromUrl(String url) async {
  //   final recipe = await ApiService.extractRecipeFromUrl(url);
  //   await StorageService.saveRecipe(recipe);
  //   return recipe;
  // }
  
  static Future<void> updateRecipe(Recipe recipe) async {
    await StorageService.updateRecipe(recipe);
  }
  
  static Future<void> deleteRecipe(String id) async {
    await StorageService.deleteRecipe(id);
  }
}