import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';
import '../models/collection.dart';
import 'cloud_gateway.dart';
import 'local_cache.dart';
import 'recipe_codec.dart';
import 'session_repository.dart';

class CloudFailure implements Exception {
  const CloudFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

String cloudError(Object error) {
  if (error is CloudFailure) return error.message;
  if (error is PostgrestException && error.code == '40001') {
    return 'Conflicto: cambió en otro dispositivo. Reabre la receta o colección antes de editar; tu formulario sigue abierto.';
  }
  if (error is PostgrestException &&
      ['22023', '23514', '23502', '23505'].contains(error.code)) {
    return 'Los datos no cumplen el contrato o el identificador ya existe. Revisa el borrador.';
  }
  return 'No se pudo confirmar el guardado cloud. Revisa la conexión y reintenta; el borrador sigue abierto.';
}

/// Owns recipe/collection lists and the session boundary; UI uses ChangeNotifier.
class LibraryRepository extends ChangeNotifier {
  LibraryRepository(this.session, this.cache, this.remote) {
    session.addListener(_sessionChanged);
  }
  final SessionRepository session;
  final LocalCache cache;
  final CloudGateway? remote;
  String? _owner;
  int _epoch = 0;
  int _read = 0;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  Future<void> _transition = Future.value();
  List<Recipe> recipes = [];
  List<RecipeCollection> collections = [];
  Map<String, dynamic> _snapshot = {};
  final Map<String, String> _imageUrls = {};
  bool loading = false;
  bool offline = false;
  String? message;
  String? get ownerId => _owner;
  int get generation => _epoch;
  bool get canWrite =>
      _owner != null && _owner == session.ownerId && remote != null;

  Future<void> initialize() async {
    await cache.retainOnly(session.ownerId);
    _sessionChanged();
    await _transition;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (_owner == session.ownerId && _epoch > 0) return;
    final previous = _owner;
    _owner = session.ownerId;
    final epoch = ++_epoch;
    _read++;
    recipes = [];
    collections = [];
    _snapshot = {};
    _imageUrls.clear();
    message = null;
    offline = false;
    loading = false;
    _notify();
    _transition = _transition
        .catchError((Object _) {})
        .then((_) async {
          if (previous != null) await cache.clearOwner(previous);
          if (!_current(epoch) || _owner == null) return;
          final cached = await cache.read(_owner!, 'library');
          if (!_current(epoch)) return;
          if (cached != null) _accept(cached);
          await refresh();
        })
        .catchError((Object _) {
          if (_current(epoch)) {
            message = 'No se pudo abrir la caché. Reintenta.';
            _notify();
          }
        });
  }

  bool _current(int epoch) =>
      !_disposed && epoch == _epoch && _owner == session.ownerId;
  void _guard(String owner, int epoch) {
    if (!_current(epoch) || _owner != owner) {
      throw const CloudFailure('La sesión cambió. Vuelve a abrir tus datos.');
    }
  }

  String requireOwner() {
    if (!canWrite) {
      throw const CloudFailure(
        'Inicia sesión para guardar en cloud. Los datos legacy son de solo lectura.',
      );
    }
    return _owner!;
  }

  Future<void> refresh() async {
    final owner = _owner;
    final epoch = _epoch;
    final read = ++_read;
    if (owner == null || remote == null) return;
    loading = true;
    _notify();
    try {
      final data = await remote!.snapshot(owner);
      _guard(owner, epoch);
      if (read != _read) return;
      if (data['owner_id'] != owner) {
        throw const CloudFailure('Respuesta de otra cuenta rechazada.');
      }
      for (final entry in (data['images'] as Map? ?? {}).entries) {
        try {
          final url = await remote!.imageUrl(owner, entry.value as String);
          _guard(owner, epoch);
          if (read != _read) return;
          _imageUrls[entry.key as String] = url;
        } catch (_) {
          _guard(owner, epoch);
        }
      }
      _accept(data);
      offline = false;
      message = null;
      await cache.write(owner, 'library', data);
      if (!_current(epoch)) await cache.clearOwner(owner);
    } catch (_) {
      if (_current(epoch) && read == _read) {
        offline = true;
        message =
            'Sin conexión o sesión no disponible. Mostrando solo recetas ya cargadas; guardar requiere confirmación cloud.';
      }
    } finally {
      if (_current(epoch) && read == _read) {
        loading = false;
        _notify();
      }
    }
  }

  void _accept(Map<String, dynamic> data) {
    if (data['owner_id'] != _owner) return;
    _snapshot = data;
    recipes = [
      for (final record in data['recipes'] as List)
        RecipeCodec.record(
          Map<String, dynamic>.from(record),
          imagePath: _imageUrls[record['id']],
        ),
    ];
    collections = [
      for (final c in data['collections'] as List)
        RecipeCollection(
          id: c['id'],
          name: c['name'],
          recipeIds: List<String>.from(c['recipe_ids']),
          createdAt: DateTime.parse(c['created_at']),
          updatedAt: DateTime.parse(c['updated_at']),
          isMaster: false,
          revision: c['revision'],
        ),
    ];
    _notify();
  }

  Future<List<Recipe>> readRecipes() async {
    await _transition;
    return List.unmodifiable(recipes);
  }

  Future<List<RecipeCollection>> readCollections() async {
    await _transition;
    return List.unmodifiable(collections);
  }

  Future<String?> imageUrl(String id) async {
    final owner = requireOwner();
    final epoch = _epoch;
    final path = (_snapshot['images'] as Map?)?[id] as String?;
    if (path == null) return null;
    final url = await remote!.imageUrl(owner, path);
    _guard(owner, epoch);
    return url;
  }

  Future<Map<String, dynamic>> mutate(
    String kind,
    Map<String, dynamic> payload, {
    String? operationId,
  }) {
    final owner = requireOwner();
    final epoch = _epoch;
    final completer = Completer<Map<String, dynamic>>();
    _writes = _writes.catchError((Object _) {}).then((_) async {
      try {
        _guard(owner, epoch);
        final key =
            'pending:${sha256.convert(utf8.encode(jsonEncode({'kind': kind, 'payload': payload})))}';
        final pending = await cache.read(owner, key);
        _guard(owner, epoch);
        final operation =
            operationId ?? pending?['id'] as String? ?? const Uuid().v4();
        await cache.write(owner, key, {'id': operation});
        _guard(owner, epoch);
        final result = await remote!.mutate(owner, operation, kind, payload);
        _guard(owner, epoch);
        // The remote response is authoritative. Cache/refresh errors cannot undo it.
        try {
          await cache.remove(owner, key);
        } catch (_) {
          message = 'Guardado cloud confirmado; caché pendiente de actualizar.';
        }
        _guard(owner, epoch);
        await refresh();
        _guard(owner, epoch);
        completer.complete(result);
      } catch (error) {
        if (!_current(epoch)) {
          try {
            await cache.clearOwner(owner);
          } catch (_) {
            /* A disposed cache must not strand the caller. */
          }
        }
        completer.completeError(
          error is CloudFailure ? error : CloudFailure(cloudError(error)),
        );
      }
    });
    return completer.future;
  }

  Future<void> saveRecipe(
    Recipe recipe, {
    bool editing = false,
    Map<String, dynamic>? draft,
    String? operationId,
    bool uploadImage = true,
    String? initialCollectionId,
  }) async {
    final owner = requireOwner();
    final epoch = _epoch;
    if (editing && (recipe.ownerId != owner || recipe.revision == null)) {
      throw const CloudFailure(
        'Reabre la receta desde la cuenta actual antes de editar.',
      );
    }
    final payload = <String, dynamic>{
      'id': recipe.id,
      if (initialCollectionId != null) 'collection_id': initialCollectionId,
      'revision': editing ? recipe.revision : null,
      'draft': draft ?? RecipeCodec.draft(recipe),
    };
    if (uploadImage &&
        recipe.imagePath != null &&
        RecipeCodec.httpUrl(recipe.imagePath) == null) {
      final file = File(
        recipe.imagePath!.startsWith('file:')
            ? Uri.parse(recipe.imagePath!).toFilePath()
            : recipe.imagePath!,
      );
      if (!await file.exists()) {
        throw const CloudFailure(
          'No se encuentra la imagen elegida. Quítala o elige otra antes de guardar.',
        );
      }
      if (await file.length() > 10485760) {
        throw const CloudFailure('La imagen supera 10 MB.');
      }
      final bytes = await file.readAsBytes();
      _guard(owner, epoch);
      String mime;
      String extension;
      if (bytes.length > 3 && bytes[0] == 255 && bytes[1] == 216) {
        mime = 'image/jpeg';
        extension = 'jpg';
      } else if (bytes.length > 8 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71) {
        mime = 'image/png';
        extension = 'png';
      } else if (bytes.length > 12 &&
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
        mime = 'image/webp';
        extension = 'webp';
      } else {
        throw const CloudFailure('Elige una imagen JPEG, PNG o WebP.');
      }
      final path = '$owner/${recipe.id}/${sha256.convert(bytes)}.$extension';
      try {
        await remote!.upload(owner, path, bytes, mime);
      } catch (_) {
        throw const CloudFailure(
          'No se pudo subir la imagen elegida. Reintenta con conexión.',
        );
      }
      _guard(owner, epoch);
      payload['image_path'] = path;
    }
    await mutate('save_recipe', payload, operationId: operationId);
  }

  Future<void> deleteRecipe(String id) async {
    final recipe = recipes.where((r) => r.id == id).firstOrNull;
    if (recipe == null) {
      throw const CloudFailure('Receta no disponible. Actualiza la lista.');
    }
    await mutate('delete_recipe', {'id': id, 'revision': recipe.revision});
  }

  Future<void> saveCollection(
    String id,
    String name, {
    int? revision,
    String? operationId,
  }) async {
    await mutate('save_collection', {
      'id': id,
      'name': name.trim(),
      'revision': revision,
    }, operationId: operationId);
  }

  Future<void> deleteCollection(RecipeCollection collection) async {
    await mutate('delete_collection', {
      'id': collection.id,
      'revision': collection.revision,
    });
  }

  Future<void> setCollections(
    String recipeId,
    List<String> ids, {
    String? operationId,
  }) async {
    final expected = [
      for (final c in collections)
        if (c.recipeIds.contains(recipeId)) c.id,
    ]..sort();
    final desired = ids.toSet().toList()..sort();
    await mutate('set_collections', {
      'id': recipeId,
      'collection_ids': desired,
      'expected_collection_ids': expected,
    }, operationId: operationId);
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    recipes = [];
    collections = [];
    session.removeListener(_sessionChanged);
    super.dispose();
  }
}
