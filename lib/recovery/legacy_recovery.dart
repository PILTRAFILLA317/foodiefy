import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';
import '../repositories/library_repository.dart';
import '../repositories/recipe_codec.dart';
import '../services/storage_service.dart';

/// Ownerless raw data never enters the session cache. IDs belong to occurrences.
class LegacyRecovery extends ChangeNotifier {
  LegacyRecovery(this.directory);
  final Directory directory;
  Map<String, dynamic>? plan;
  bool busy = false;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static Future<LegacyRecovery> open() async {
    final root = await getApplicationSupportDirectory();
    return LegacyRecovery(Directory('${root.path}/legacy-quarantine'));
  }

  String get checksum => plan?['checksum'] ?? '';
  List<Map<String, dynamic>> get entries => [
    for (final r in plan?['recipes'] ?? []) Map<String, dynamic>.from(r),
  ];
  List<Map<String, dynamic>> get relations => [
    for (final r in plan?['relations'] ?? []) Map<String, dynamic>.from(r),
  ];
  Future<void> _atomic(File file, String data) async {
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(data, flush: true);
    await temp.rename(file.path);
  }

  Future<void> _save() async {
    await _atomic(File('${directory.path}/plan.json'), jsonEncode(plan));
    _notify();
  }

  Future<void> verifyBackup() async {
    final raw = await File('${directory.path}/raw.json').readAsBytes();
    final backup = await File(
      '${directory.path}/raw.backup.json',
    ).readAsBytes();
    if (sha256.convert(raw).toString() != checksum ||
        sha256.convert(backup).toString() != checksum) {
      throw const CloudFailure(
        'Checksum incorrecto. No se importará ningún dato. Conserva los archivos para revisar la copia.',
      );
    }
  }

  Future<void> prepare({String? rawExport}) async {
    if (busy) return;
    busy = true;
    _notify();
    try {
      await directory.create(recursive: true);
      final file = File('${directory.path}/plan.json');
      if (await file.exists()) {
        plan = Map<String, dynamic>.from(jsonDecode(await file.readAsString()));
        await verifyBackup();
        return;
      }
      // First durable action: exact raw export and redundant verified backup.
      final rawFile = File('${directory.path}/raw.json');
      final raw = await rawFile.exists()
          ? await rawFile.readAsString()
          : rawExport ?? await StorageService.exportLegacyJson();
      if (!await rawFile.exists()) await _atomic(rawFile, raw);
      final backup = File('${directory.path}/raw.backup.json');
      if (!await backup.exists()) await _atomic(backup, raw);
      final hash = sha256.convert(utf8.encode(raw)).toString();
      final data = Map<String, dynamic>.from(jsonDecode(raw));
      plan = {
        'version': 1,
        'checksum': hash,
        'owner_id': null,
        'confirmed': false,
        'complete': false,
        'recipes': <dynamic>[],
        'collections': <dynamic>[],
        'relations': <dynamic>[],
      };
      await verifyBackup();
      final rawRecipes = data['recipes'] as List;
      final rawCollections = data['collections'] as List;
      for (var i = 0; i < rawRecipes.length; i++) {
        final entry = <String, dynamic>{
          'index': i,
          'id': const Uuid().v4(),
          'operation_id': const Uuid().v4(),
          'raw': rawRecipes[i],
          'done': false,
          'selected_image': false,
          'image_status': 'none',
        };
        try {
          final json = Map<String, dynamic>.from(
            jsonDecode(rawRecipes[i] as String),
          );
          entry['old_id'] = json['id'];
          final recipe = Recipe.fromJson({...json, 'id': entry['id']});
          entry['draft'] = RecipeCodec.draft(recipe, legacy: true);
          entry['ingredient_count'] = recipe.ingredients.length;
          entry['step_count'] = recipe.steps.length;
          if (recipe.title.trim().isEmpty ||
              recipe.ingredients.isEmpty ||
              recipe.steps.isEmpty ||
              recipe.ingredients.any((x) => x.trim().isEmpty) ||
              recipe.steps.any((x) => x.trim().isEmpty)) {
            entry['issue'] =
                'Revisa título, ingredientes y pasos; raw conservado.';
          }
          final path = recipe.imagePath;
          if (path != null && path.isNotEmpty) {
            if (RecipeCodec.httpUrl(path) != null) {
              entry['image_status'] = 'remote_expiring';
            } else {
              try {
                final source = File(
                  path.startsWith('file:')
                      ? Uri.parse(path).toFilePath()
                      : path,
                );
                if (await source.exists()) {
                  final copy = File('${directory.path}/image-${entry['id']}');
                  await source.copy(copy.path);
                  entry['image_path'] = copy.path;
                  entry['image_checksum'] = sha256
                      .convert(await copy.readAsBytes())
                      .toString();
                  entry['image_status'] = 'copied';
                } else {
                  entry['image_status'] = 'missing';
                }
              } catch (_) {
                entry['image_status'] = 'missing';
              }
            }
          }
        } catch (_) {
          entry['issue'] =
              'Objeto no interpretable; corregir una copia desde revisión.';
        }
        (plan!['recipes'] as List).add(entry);
      }
      for (var i = 0; i < rawCollections.length; i++) {
        final entry = <String, dynamic>{
          'index': i,
          'id': const Uuid().v4(),
          'operation_id': const Uuid().v4(),
          'raw': rawCollections[i],
          'done': false,
        };
        try {
          final c = Map<String, dynamic>.from(
            jsonDecode(rawCollections[i] as String),
          );
          entry['name'] = c['name'];
          entry['virtual'] = c['isMaster'] == true;
          if (c['name'] is! String || (c['name'] as String).trim().isEmpty) {
            entry['issue'] = 'Revisa el nombre de colección.';
          }
          final ids = c['recipeIds'] as List;
          for (var j = 0; j < ids.length; j++) {
            final candidates = [
              for (final r in plan!['recipes'])
                if (r['old_id'] == ids[j]) r['index'],
            ];
            (plan!['relations'] as List).add({
              'collection_index': i,
              'relation_index': j,
              'old_id': ids[j],
              'candidates': candidates,
              'recipe_index': candidates.length == 1 ? candidates.single : null,
              'resolved': candidates.length == 1 || entry['virtual'] == true,
              'skip': entry['virtual'] == true,
            });
          }
        } catch (_) {
          entry['issue'] = 'Colección no interpretable; raw conservado.';
        }
        (plan!['collections'] as List).add(entry);
      }
      await _save();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> resolve(int relationIndex, int? occurrence) async {
    if (busy || plan!['confirmed'] == true) {
      throw const CloudFailure('La revisión ya está bloqueada para importar.');
    }
    final relation = plan!['relations'][relationIndex];
    if (occurrence != null &&
        (occurrence < 0 || occurrence >= entries.length)) {
      throw const CloudFailure('Ocurrencia inválida.');
    }
    relation['recipe_index'] = occurrence;
    relation['skip'] = occurrence == null;
    relation['resolved'] = true;
    await _save();
  }

  Future<void> selectImage(int index, bool value) async {
    if (busy || plan!['confirmed'] == true) {
      throw const CloudFailure('La revisión ya está bloqueada para importar.');
    }
    final entry = plan!['recipes'][index];
    if (entry['image_status'] != 'copied') {
      throw const CloudFailure('No hay una copia de esa imagen.');
    }
    entry['selected_image'] = value;
    await _save();
  }

  Future<void> correctRecipe(int index, String correctedRaw) async {
    if (busy || plan!['confirmed'] == true) {
      throw const CloudFailure('La revisión ya está bloqueada para importar.');
    }
    final entry = plan!['recipes'][index];
    final data = Map<String, dynamic>.from(jsonDecode(correctedRaw));
    final recipe = Recipe.fromJson({...data, 'id': entry['id']});
    if (recipe.title.trim().isEmpty ||
        recipe.ingredients.isEmpty ||
        recipe.steps.isEmpty ||
        recipe.ingredients.any((x) => x.trim().isEmpty) ||
        recipe.steps.any((x) => x.trim().isEmpty)) {
      throw const CloudFailure(
        'La receta requiere título, ingredientes y pasos no vacíos.',
      );
    }
    entry['corrected_raw'] = correctedRaw;
    entry['draft'] = RecipeCodec.draft(recipe, legacy: true);
    entry['ingredient_count'] = recipe.ingredients.length;
    entry['step_count'] = recipe.steps.length;
    entry.remove('issue');
    await _save();
  }

  Future<void> correctCollection(int index, String correctedRaw) async {
    if (busy || plan!['confirmed'] == true) {
      throw const CloudFailure('La revisión ya está bloqueada para importar.');
    }
    final data = Map<String, dynamic>.from(jsonDecode(correctedRaw));
    final name = data['name'];
    final ids = data['recipeIds'];
    if (name is! String ||
        name.trim().isEmpty ||
        ids is! List ||
        ids.any((id) => id is! String)) {
      throw const CloudFailure(
        'La colección requiere name y recipeIds (lista de IDs).',
      );
    }
    final c = plan!['collections'][index];
    c['name'] = name.trim();
    c['virtual'] = data['isMaster'] == true;
    c['corrected_raw'] = correctedRaw;
    c.remove('issue');
    final links = plan!['relations'] as List;
    links.removeWhere((r) => r['collection_index'] == index);
    for (var j = 0; j < ids.length; j++) {
      final candidates = [
        for (final r in plan!['recipes'])
          if (r['old_id'] == ids[j]) r['index'],
      ];
      links.add({
        'collection_index': index,
        'relation_index': j,
        'old_id': ids[j],
        'candidates': candidates,
        'recipe_index': candidates.length == 1 ? candidates.single : null,
        'resolved': candidates.length == 1 || c['virtual'] == true,
        'skip': c['virtual'] == true,
      });
    }
    links.sort((a, b) {
      final c = (a['collection_index'] as int).compareTo(
        b['collection_index'] as int,
      );
      return c != 0
          ? c
          : (a['relation_index'] as int).compareTo(b['relation_index'] as int);
    });
    await _save();
  }

  Future<void> importTo(
    LibraryRepository library, {
    required String confirmedOwner,
  }) async {
    if (busy) throw const CloudFailure('El rescate ya está en curso.');
    if (plan == null) {
      throw const CloudFailure('Genera primero el backup y dry-run.');
    }
    final owner = library.requireOwner();
    if (confirmedOwner != owner) {
      throw const CloudFailure('Confirma la cuenta actual.');
    }
    if (plan!['owner_id'] != null && plan!['owner_id'] != owner) {
      throw const CloudFailure(
        'Este backup está vinculado a otra cuenta. No se reasignará.',
      );
    }
    if ((plan!['recipes'] as List).any((r) => r['issue'] != null) ||
        (plan!['collections'] as List).any((c) => c['issue'] != null) ||
        relations.any((r) => r['resolved'] != true)) {
      throw const CloudFailure(
        'Resuelve los conflictos del dry-run antes de importar.',
      );
    }
    busy = true;
    _notify();
    try {
      await verifyBackup();
      plan!['owner_id'] = owner;
      plan!['confirmed'] = true;
      await _save();
      for (final entry in plan!['recipes']) {
        if (library.requireOwner() != owner) {
          throw const CloudFailure('La cuenta ha cambiado. Rescate pausado.');
        }
        if (entry['done'] == true) continue;
        final json = Map<String, dynamic>.from(
          jsonDecode(entry['corrected_raw'] ?? entry['raw']),
        );
        final selected = entry['selected_image'] == true;
        if (selected) {
          final file = File(entry['image_path']);
          if (!await file.exists() ||
              sha256.convert(await file.readAsBytes()).toString() !=
                  entry['image_checksum']) {
            throw const CloudFailure(
              'Falta una imagen elegida o cambió su checksum. Se conserva el progreso.',
            );
          }
        }
        final recipe = Recipe.fromJson({
          ...json,
          'id': entry['id'],
          'imagePath': selected ? entry['image_path'] : null,
        });
        await library.saveRecipe(
          recipe,
          draft: Map<String, dynamic>.from(entry['draft']),
          operationId: entry['operation_id'],
          uploadImage: selected,
        );
        entry['done'] = true;
        await _save();
      }
      for (final c in plan!['collections']) {
        if (library.requireOwner() != owner) {
          throw const CloudFailure('La cuenta ha cambiado. Rescate pausado.');
        }
        if (c['done'] == true || c['virtual'] == true) continue;
        await library.saveCollection(
          c['id'],
          c['name'],
          operationId: c['operation_id'],
        );
        c['done'] = true;
        await _save();
      }
      await library.refresh();
      if (library.offline) {
        throw const CloudFailure(
          'Conecta para verificar el rescate antes de terminar.',
        );
      }
      for (final r in plan!['recipes']) {
        if (library.requireOwner() != owner) {
          throw const CloudFailure('La cuenta ha cambiado. Rescate pausado.');
        }
        if (r['relations_done'] == true) continue;
        if (r['relation_payload'] == null) {
          final ids = <String>{
            for (final rel in relations)
              if (rel['skip'] != true && rel['recipe_index'] == r['index'])
                plan!['collections'][rel['collection_index']]['id'],
          }.toList()..sort();
          final expected = [
            for (final c in library.collections)
              if (c.recipeIds.contains(r['id'])) c.id,
          ]..sort();
          r['relation_payload'] = {
            'id': r['id'],
            'collection_ids': ids,
            'expected_collection_ids': expected,
          };
          r['relation_operation'] = const Uuid().v4();
          await _save();
        }
        await library.mutate(
          'set_collections',
          Map<String, dynamic>.from(r['relation_payload']),
          operationId: r['relation_operation'],
        );
        r['relations_done'] = true;
        await _save();
      }
      await library.refresh();
      if (library.offline || library.requireOwner() != owner) {
        throw const CloudFailure(
          'Falta la verificación cloud final. Reanuda con conexión.',
        );
      }
      for (final r in plan!['recipes']) {
        final saved = library.recipes.where((x) => x.id == r['id']).firstOrNull;
        if (saved == null ||
            saved.ingredients.length != r['ingredient_count'] ||
            saved.steps.length != r['step_count']) {
          throw const CloudFailure(
            'Recuento distinto en cloud. Conserva el backup y revisa la receta.',
          );
        }
      }
      for (final rel in relations.where((r) => r['skip'] != true)) {
        final c = plan!['collections'][rel['collection_index']];
        final r = plan!['recipes'][rel['recipe_index']];
        if (!library.collections.any(
          (x) => x.id == c['id'] && x.recipeIds.contains(r['id']),
        )) {
          throw const CloudFailure(
            'Referencia no verificada. Reanuda el rescate.',
          );
        }
      }
      plan!['complete'] = true;
      await _save();
    } finally {
      busy = false;
      _notify();
    }
  }
}
