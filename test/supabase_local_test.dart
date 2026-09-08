import 'dart:io';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiefy/models/recipe.dart';
import 'package:foodiefy/repositories/cloud_gateway.dart';
import 'package:foodiefy/repositories/library_repository.dart';
import 'package:foodiefy/repositories/local_cache.dart';
import 'package:foodiefy/repositories/session_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

void main() {
  final enabled = Platform.environment['FOODIEFY_LOCAL_TEST'] == '1';
  test(
    'real local auth CRUD reopen revision conflict memberships and A/B isolation',
    () async {
      final url = Platform.environment['FOODIEFY_LOCAL_URL']!;
      final uri = Uri.parse(url);
      expect(uri.scheme, 'http');
      expect(['127.0.0.1', 'localhost', '::1'], contains(uri.host));
      expect(uri.port, 54321);
      final key = Platform.environment['FOODIEFY_LOCAL_ANON_KEY']!;
      final a = SupabaseClient(
        url,
        key,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
      final b = SupabaseClient(
        url,
        key,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
      final secondA = SupabaseClient(
        url,
        key,
        authOptions: const AuthClientOptions(
          authFlowType: AuthFlowType.implicit,
        ),
      );
      final id = const Uuid().v4();
      final emailA = 'a-$id@example.invalid';
      final emailB = 'b-$id@example.invalid';
      final password = 'T-${const Uuid().v4()}-9a!';
      final session = SessionRepository(a);
      final cache = LocalCache(NativeDatabase.memory());
      final library = LibraryRepository(session, cache, SupabaseGateway(a));
      try {
        final registeredA = await a.auth.signUp(
          email: emailA,
          password: password,
        );
        final registeredB = await b.auth.signUp(
          email: emailB,
          password: password,
        );
        expect(registeredA.session, isNotNull);
        expect(registeredB.session, isNotNull);
        await session.signIn(emailA, password);
        await library.initialize();
        final owner = library.requireOwner();
        final recipe = Recipe(
          id: id,
          title: 'Local phase04',
          ingredients: ['1.5 kg tomato', 'salt'],
          steps: ['Mix'],
          createdAt: DateTime.now(),
        );
        await library.saveRecipe(recipe);
        expect(library.recipes.single.id, id);
        expect(library.recipes.single.revision, 1);
        final first = library.recipes.single;
        await secondA.auth.signInWithPassword(
          email: emailA,
          password: password,
        );
        final reopened = await SupabaseGateway(secondA).snapshot(owner);
        expect(reopened['recipes'], hasLength(1));
        expect(reopened['recipes'][0]['ingredients'], hasLength(2));
        final edited = Recipe(
          id: id,
          title: 'Edited',
          ingredients: first.ingredients,
          steps: first.steps,
          createdAt: first.createdAt,
          ownerId: owner,
          revision: first.revision,
          cloudDraft: first.cloudDraft,
        );
        await library.saveRecipe(edited, editing: true);
        expect(library.recipes.single.title, 'Edited');
        expect(library.recipes.single.revision, 2);
        await expectLater(
          library.saveRecipe(edited, editing: true),
          throwsA(isA<CloudFailure>()),
        );
        final collection = const Uuid().v4();
        final destination = const Uuid().v4();
        await library.saveCollection(collection, 'First');
        await library.saveCollection(destination, 'Second');
        await library.setCollections(id, [collection]);
        expect(
          library.collections.firstWhere((c) => c.id == collection).recipeIds,
          [id],
        );
        await library.setCollections(id, [destination]);
        expect(
          library.collections.firstWhere((c) => c.id == collection).recipeIds,
          isEmpty,
        );
        await library.setCollections(id, []);
        expect(library.recipes, hasLength(1));
        final c = library.collections.firstWhere((c) => c.id == collection);
        await library.saveCollection(c.id, 'Renamed', revision: c.revision);
        expect(
          library.collections.firstWhere((x) => x.id == collection).name,
          'Renamed',
        );
        await expectLater(
          library.saveCollection(c.id, 'Stale', revision: c.revision),
          throwsA(isA<CloudFailure>()),
        );
        final insideId = const Uuid().v4();
        final inside = Recipe(
          id: insideId,
          title: 'Inside',
          ingredients: ['Salt'],
          steps: ['Mix'],
          createdAt: DateTime.now(),
        );
        await expectLater(
          library.saveRecipe(inside, initialCollectionId: const Uuid().v4()),
          throwsA(isA<CloudFailure>()),
        );
        await library.refresh();
        expect(library.recipes.any((r) => r.id == insideId), isFalse);
        await library.saveRecipe(inside, initialCollectionId: destination);
        expect(
          library.collections.firstWhere((c) => c.id == destination).recipeIds,
          [insideId],
        );
        await library.deleteRecipe(insideId);
        final isolated = await SupabaseGateway(
          b,
        ).snapshot(b.auth.currentUser!.id);
        expect(isolated['recipes'], isEmpty);
        expect(isolated['collections'], isEmpty);
        await expectLater(
          b.rpc(
            'cloud_mutation_v1',
            params: {
              'p_operation_id': const Uuid().v4(),
              'p_kind': 'delete_recipe',
              'p_payload': {'id': id, 'revision': 2},
            },
          ),
          throwsA(isA<PostgrestException>()),
        );
        // Private Storage: own prefix works, other owner's prefix is rejected.
        final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
        final path = '$owner/$id/test.png';
        await SupabaseGateway(a).upload(owner, path, bytes, 'image/png');
        await expectLater(
          b.storage.from('recipe-images').download(path),
          throwsA(isA<StorageException>()),
        );
        await a.storage.from('recipe-images').remove([path]);
        await library.deleteRecipe(id);
        expect(library.recipes, isEmpty);
        for (final item in List.of(library.collections)) {
          await library.deleteCollection(item);
        }
        await session.signOut();
        await library.readRecipes();
        expect(library.recipes, isEmpty);
        expect(await cache.read(owner, 'library'), isNull);
        await session.signIn(emailB, password);
        await library.readRecipes();
        expect(library.recipes, isEmpty);
        expect(library.collections, isEmpty);
      } finally {
        library.dispose();
        session.dispose();
        await cache.close();
        await a.dispose();
        await b.dispose();
        await secondA.dispose();
      }
    },
    skip: !enabled
        ? 'NO EJECUTADO: activa mediante tool/test_supabase_local.py (solo loopback).'
        : false,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
