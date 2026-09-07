import 'dart:collection';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/collection.dart';
import '../models/recipe.dart';
import 'collection_service.dart';
import 'storage_service.dart';

class SyncResult {
  const SyncResult({
    required this.recipesDownloaded,
    required this.recipesUploaded,
    required this.collectionsDownloaded,
    required this.collectionsUploaded,
    required this.totalLocalRecipes,
    required this.totalLocalCollections,
  });

  final int recipesDownloaded;
  final int recipesUploaded;
  final int collectionsDownloaded;
  final int collectionsUploaded;
  final int totalLocalRecipes;
  final int totalLocalCollections;

  bool get hasChanges =>
      recipesDownloaded > 0 ||
      recipesUploaded > 0 ||
      collectionsDownloaded > 0 ||
      collectionsUploaded > 0;
}

class SyncService {
  SyncService({
    SupabaseClient? client,
    CollectionService? collectionService,
  })  : _client = client ?? Supabase.instance.client,
        _collectionService = collectionService ?? CollectionService();

  final SupabaseClient _client;
  final CollectionService _collectionService;

  static final RegExp _uuidRegExp =
    RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  Future<SyncResult> syncUserData() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Necesitas iniciar sesión para sincronizar tus datos.');
    }

    final recipes = List<Recipe>.from(await StorageService.getRecipes());
    final collections =
        List<RecipeCollection>.from(await _collectionService.getCollections());

    final recipeIndex = <String, int>{
      for (var i = 0; i < recipes.length; i++) recipes[i].id: i,
    };
    final collectionIndex = <String, int>{
      for (var i = 0; i < collections.length; i++) collections[i].id: i,
    };

    final Map<String, Map<String, dynamic>> remoteRecipes = {};
    final Set<String> remoteSavedRecipeIds = {};
    final Map<String, String> remoteSourceUrlToId = {};
    final Map<String, Map<String, dynamic>> remoteCollections = {};
    final Map<String, Set<String>> remoteCollectionMembership = {};

    await _pullRemoteRecipes(
      userId: user.id,
      remoteRecipes: remoteRecipes,
      remoteSavedRecipeIds: remoteSavedRecipeIds,
      remoteSourceUrlToId: remoteSourceUrlToId,
    );
    print('Remote saved recipe IDs: $remoteSavedRecipeIds');

    await _pullRemoteCollections(
      userId: user.id,
      remoteRecipes: remoteRecipes,
      remoteCollections: remoteCollections,
      remoteCollectionMembership: remoteCollectionMembership,
      remoteSourceUrlToId: remoteSourceUrlToId,
    );
    print('Remote saved recipe IDs after collections: $remoteSavedRecipeIds');

    final missingRecipeIds = <String>{
      ...remoteSavedRecipeIds,
      for (final ids in remoteCollectionMembership.values) ...ids,
    }..removeWhere(remoteRecipes.containsKey);

    if (missingRecipeIds.isNotEmpty) {
      await _populateMissingRemoteRecipes(missingRecipeIds, remoteRecipes,
          remoteSourceUrlToId);
    }
    print ('Missing recipe IDs populated: $missingRecipeIds');

    var recipesDownloaded = 0;
    for (final entry in remoteRecipes.entries) {
      final remoteId = entry.key;
      if (!recipeIndex.containsKey(remoteId)) {
        final parsed = _recipeFromRemote(entry.value);
        recipes.add(parsed);
        recipeIndex[remoteId] = recipes.length - 1;
        recipesDownloaded++;
      }
    }

    print ('Total recipes after download: ${recipes.length}');

    final uuid = const Uuid();
    var recipesUploaded = 0;

    for (var i = 0; i < recipes.length; i++) {
      var recipe = recipes[i];
      final localId = recipe.id;
      String? remoteId;

      if (remoteRecipes.containsKey(localId) ||
          remoteSavedRecipeIds.contains(localId)) {
        remoteId = localId;
      } else {
        final source = recipe.sourceUrl?.trim();
        if (source != null && source.isNotEmpty) {
          remoteId = remoteSourceUrlToId[source];
        }
      }
      print ('Syncing recipe localId=$localId remoteId=$remoteId');
      if (remoteId == null) {
        final chosenId = _looksLikeUuid(localId) ? localId : uuid.v4();
        final payload = _recipeToRemoteMap(recipe, chosenId);
        final inserted = await _client
            .from('recipes')
            .upsert(payload, onConflict: 'id')
            .select()
            .single();

        remoteId = inserted['id'] as String? ?? chosenId;
        remoteRecipes[remoteId] = inserted;
        final insertedSource = (inserted['source_url'] as String?)?.trim();
        if (insertedSource != null && insertedSource.isNotEmpty) {
          remoteSourceUrlToId[insertedSource] = remoteId;
        }
        recipesUploaded++;
      } else {
        remoteRecipes.putIfAbsent(
            remoteId, () => _recipeToRemoteMap(recipe, remoteId!));
      }

      if (localId != remoteId) {
        recipe = recipe.copyWith(id: remoteId);
        recipes[i] = recipe;
        recipeIndex.remove(localId);
        recipeIndex[remoteId] = i;

        for (var c = 0; c < collections.length; c++) {
          final collection = collections[c];
          if (!collection.recipeIds.contains(localId)) continue;
          final updatedIds = collection.recipeIds
              .map((id) => id == localId ? remoteId! : id)
              .toList();
          collections[c] = collection.copyWith(
            recipeIds: updatedIds,
            updatedAt: DateTime.now(),
          );
        }
      }

      if (!remoteSavedRecipeIds.contains(remoteId)) {
        await _client
            .from('user_recipes')
            .upsert({
              'user_id': user.id,
              'recipe_id': remoteId,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            }, onConflict: 'user_id,recipe_id')
            .select()
            .maybeSingle();
        remoteSavedRecipeIds.add(remoteId);
      }
    }

    var collectionsUploaded = 0;
    for (var i = 0; i < collections.length; i++) {
      var collection = collections[i];
      if (collection.isMaster || collection.id == '0') {
        continue;
      }

      var collectionId = collection.id;
      if (!remoteCollections.containsKey(collectionId)) {
        final chosenId = _looksLikeUuid(collectionId) ? collectionId : uuid.v4();
        final payload = _collectionToRemoteMap(collection, chosenId, user.id);
        final inserted = await _client
            .from('collections')
            .upsert(payload, onConflict: 'id')
            .select()
            .single();

        final remoteId = inserted['id'] as String? ?? chosenId;
        remoteCollections[remoteId] = inserted;
        remoteCollectionMembership.putIfAbsent(remoteId, () => <String>{});
        collectionsUploaded++;

        if (remoteId != collectionId) {
          collection = collection.copyWith(
            id: remoteId,
            updatedAt: DateTime.now(),
          );
          collections[i] = collection;
          collectionIndex.remove(collectionId);
          collectionIndex[remoteId] = i;
          collectionId = remoteId;
        } else {
          collectionIndex[collectionId] = i;
        }
      }

      final remoteMembers = remoteCollectionMembership.putIfAbsent(
        collectionId,
        () => <String>{},
      );

      for (final recipeId in collection.recipeIds) {
        if (!remoteMembers.contains(recipeId)) {
          await _client
              .from('collection_recipes')
              .upsert({
                'collection_id': collectionId,
                'recipe_id': recipeId,
                'user_id': user.id,
              }, onConflict: 'collection_id,recipe_id')
              .select()
              .maybeSingle();
          remoteMembers.add(recipeId);
        }
      }
    }

    var collectionsDownloaded = 0;
    remoteCollections.forEach((remoteId, row) {
      final index = collectionIndex[remoteId];
      final remoteMembers = remoteCollectionMembership[remoteId] ?? <String>{};

      if (index == null) {
        final newCollection = RecipeCollection(
          id: remoteId,
          name: row['name'] as String? ?? 'Colección',
          description: row['description'] as String?,
          coverImagePath: row['cover_image_path'] as String?,
          recipeIds: remoteMembers.toList(),
          createdAt: _parseDate(row['created_at']),
          updatedAt: _parseDate(row['updated_at']),
          isMaster: false,
        );
        collections.add(newCollection);
        collectionIndex[remoteId] = collections.length - 1;
        collectionsDownloaded++;
      } else {
        final collection = collections[index];
        final localRecipeIds = HashSet<String>.from(collection.recipeIds);
        final updatedIds = List<String>.from(collection.recipeIds);
        var changed = false;
        for (final recipeId in remoteMembers) {
          if (!localRecipeIds.contains(recipeId)) {
            updatedIds.add(recipeId);
            changed = true;
          }
        }

        if (changed) {
          collections[index] = collection.copyWith(
            recipeIds: updatedIds,
            updatedAt: DateTime.now(),
          );
        }
      }
    });

    await StorageService.setRecipes(recipes);
    await _collectionService.setCollections(collections);

    return SyncResult(
      recipesDownloaded: recipesDownloaded,
      recipesUploaded: recipesUploaded,
      collectionsDownloaded: collectionsDownloaded,
      collectionsUploaded: collectionsUploaded,
      totalLocalRecipes: recipes.length,
      totalLocalCollections: collections.length,
    );
  }

  Future<void> _pullRemoteRecipes({
    required String userId,
    required Map<String, Map<String, dynamic>> remoteRecipes,
    required Set<String> remoteSavedRecipeIds,
    required Map<String, String> remoteSourceUrlToId,
  }) async {
    final List<dynamic> response = await _client
        .from('user_recipes')
        .select('recipe_id, recipes(*)')
        .eq('user_id', userId);

    for (final row in response) {
      if (row is! Map<String, dynamic>) continue;
      final recipeId = row['recipe_id'] as String?;
      if (recipeId == null) continue;
      remoteSavedRecipeIds.add(recipeId);
      final recipeData = row['recipes'];
      if (recipeData is Map<String, dynamic>) {
        final remoteId = recipeData['id'] as String?;
        if (remoteId != null) {
          remoteRecipes[remoteId] = recipeData;
          final source = (recipeData['source_url'] as String?)?.trim();
          if (source != null && source.isNotEmpty) {
            remoteSourceUrlToId[source] = remoteId;
          }
        }
      }
    }
  }

  Future<void> _pullRemoteCollections({
    required String userId,
    required Map<String, Map<String, dynamic>> remoteRecipes,
    required Map<String, Map<String, dynamic>> remoteCollections,
    required Map<String, Set<String>> remoteCollectionMembership,
    required Map<String, String> remoteSourceUrlToId,
  }) async {
    final List<dynamic> response = await _client
        .from('collections')
        .select(
            'id, name, description, cover_image_path, created_at, updated_at, collection_recipes(recipe_id, position, recipes(*))')
        .eq('user_id', userId);

    for (final row in response) {
      if (row is! Map<String, dynamic>) continue;
      final collectionId = row['id'] as String?;
      if (collectionId == null) continue;

      remoteCollections[collectionId] = row;
      final members = remoteCollectionMembership.putIfAbsent(
        collectionId,
        () => <String>{},
      );

      final entries = row['collection_recipes'];
      if (entries is List) {
        for (final entry in entries) {
          if (entry is! Map<String, dynamic>) continue;
          final recipeId = entry['recipe_id'] as String?;
          if (recipeId == null) continue;
          members.add(recipeId);
          final nestedRecipe = entry['recipes'];
          if (nestedRecipe is Map<String, dynamic>) {
            final remoteId = nestedRecipe['id'] as String?;
            if (remoteId != null) {
              remoteRecipes.putIfAbsent(remoteId, () => nestedRecipe);
              final source = (nestedRecipe['source_url'] as String?)?.trim();
              if (source != null && source.isNotEmpty) {
                remoteSourceUrlToId[source] = remoteId;
              }
            }
          }
        }
      }
    }
  }

  Future<void> _populateMissingRemoteRecipes(
    Set<String> missingIds,
    Map<String, Map<String, dynamic>> remoteRecipes,
    Map<String, String> remoteSourceUrlToId,
  ) async {
  final quotedIds = missingIds.map((id) => '"$id"').join(',');
  final filterValue = '($quotedIds)';
  final List<dynamic> response = await _client
    .from('recipes')
    .select()
    .filter('id', 'in', filterValue);

    for (final row in response) {
      if (row is! Map<String, dynamic>) continue;
      final remoteId = row['id'] as String?;
      if (remoteId == null) continue;
      remoteRecipes.putIfAbsent(remoteId, () => row);
      final source = (row['source_url'] as String?)?.trim();
      if (source != null && source.isNotEmpty) {
        remoteSourceUrlToId.putIfAbsent(source, () => remoteId);
      }
    }
  }

  static Recipe _recipeFromRemote(Map<String, dynamic> data) {
    final macronutrientsRaw = data['macronutrients'];
    return Recipe(
      id: data['id'] as String? ?? const Uuid().v4(),
      title: data['title'] as String? ?? 'Receta',
      description: data['description'] as String?,
      ingredients: _normalizeStringList(data['ingredients']),
      steps: _normalizeStringList(data['steps']),
      imagePath: data['image_url'] as String?,
      originalVideoUrl: data['original_video_url'] as String?,
      sourceUrl: data['source_url'] as String?,
      isPublic: data['is_public'] as bool? ?? false,
      isImported: data['is_imported'] as bool? ?? false,
      prepTimeMinutes: data['prep_time_minutes'] as int?,
      prepTimeText: data['prep_time_text'] as String?,
      uploader: data['uploader'] as String?,
      platform: data['platform'] as String?,
      thumbnailUrl: data['thumbnail_url'] as String?,
      finalQuantity: data['final_quantity'] as String?,
      macronutrients: macronutrientsRaw is Map<String, dynamic>
          ? RecipeMacronutrients.fromJson(macronutrientsRaw)
          : null,
      createdAt: _parseDate(data['created_at']),
    );
  }

  static Map<String, dynamic> _recipeToRemoteMap(
      Recipe recipe, String id) {
    final map = <String, dynamic>{
      'id': id,
      'title': recipe.title,
      'description': recipe.description,
      'ingredients': recipe.ingredients,
      'steps': recipe.steps,
      'image_path': recipe.imagePath,
      'original_video_url': recipe.originalVideoUrl,
      'source_url': recipe.sourceUrl,
      'is_public': recipe.isPublic,
      'is_imported': recipe.isImported,
      'prep_time_minutes': recipe.prepTimeMinutes,
      'prep_time_text': recipe.prepTimeText,
      'uploader': recipe.uploader,
      'platform': recipe.platform,
      'thumbnail_url': recipe.thumbnailUrl,
      'final_quantity': recipe.finalQuantity,
      'macronutrients': recipe.macronutrients?.toJson(),
      'created_at': recipe.createdAt.toUtc().toIso8601String(),
    };

    map.removeWhere((_, value) => value == null);
    return map;
  }

  static Map<String, dynamic> _collectionToRemoteMap(
    RecipeCollection collection,
    String id,
    String userId,
  ) {
    final map = <String, dynamic>{
      'id': id,
      'user_id': userId,
      'name': collection.name,
      'description': collection.description,
      'cover_image_path': collection.coverImagePath,
      'created_at': collection.createdAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    map.removeWhere((_, value) => value == null);
    return map;
  }

  static bool _looksLikeUuid(String? value) {
    if (value == null) {
      return false;
    }
    return _uuidRegExp.hasMatch(value);
  }

  static List<String> _normalizeStringList(dynamic input) {
    if (input is List) {
      return input
          .map((e) => e?.toString().trim())
          .whereType<String>()
          .where((element) => element.isNotEmpty)
          .toList();
    }
    if (input is String && input.isNotEmpty) {
      return [input];
    }
    return <String>[];
  }

  static DateTime _parseDate(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }
}
