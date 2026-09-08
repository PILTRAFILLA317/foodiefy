import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../config/cloud_runtime.dart';
import '../models/collection.dart';
import '../repositories/app_repositories.dart';
import 'storage_service.dart';

class CollectionService {
  Future<List<RecipeCollection>> getCollections() async {
    if (CloudRuntime.enabled) {
      return await AppRepositories.library?.readCollections() ?? [];
    }
    final prefs = await SharedPreferences.getInstance();
    final recipes = await StorageService.getLegacyRecipes();
    final counts = <String, int>{};
    for (final r in recipes) {
      counts[r.id] = (counts[r.id] ?? 0) + 1;
    }
    final result = <RecipeCollection>[];
    for (final raw in prefs.getStringList('collections') ?? <String>[]) {
      try {
        final c = RecipeCollection.fromJson(jsonDecode(raw));
        // Ambiguous legacy IDs are never interpreted as associations.
        c.recipeIds.removeWhere((id) => counts[id] != 1);
        result.add(c);
      } catch (_) {
        /* Exact raw remains in quarantine export. */
      }
    }
    return result;
  }

  Future<void> saveCollection(String name, {String? id}) =>
      AppRepositories.writable.saveCollection(id ?? const Uuid().v4(), name);
  Future<void> renameCollection(RecipeCollection c, String name) =>
      AppRepositories.writable.saveCollection(c.id, name, revision: c.revision);
  Future<void> deleteCollection(RecipeCollection c) =>
      AppRepositories.writable.deleteCollection(c);
  Future<void> setRecipeCollections(String recipeId, List<String> ids) =>
      AppRepositories.writable.setCollections(recipeId, ids);
  Future<void> addRecipeToCollection(
    String collectionId,
    String recipeId,
  ) async {
    final library = AppRepositories.writable;
    final ids = [
      for (final c in library.collections)
        if (c.recipeIds.contains(recipeId)) c.id,
    ];
    await library.setCollections(recipeId, [...ids, collectionId]);
  }

  Future<void> removeRecipeFromCollection(
    String collectionId,
    String recipeId,
  ) async {
    final library = AppRepositories.writable;
    await library.setCollections(recipeId, [
      for (final c in library.collections)
        if (c.id != collectionId && c.recipeIds.contains(recipeId)) c.id,
    ]);
  }
}
