import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../repositories/session_repository.dart';
import '../repositories/recipe_codec.dart';
import '../models/recipe.dart';
import '../services/import_service.dart';

const stageLabels = {
  'resolving_source': 'Revisando el enlace…',
  'extracting_metadata': 'Obteniendo la receta y descripción…',
  'extracting_audio': 'Preparando el audio…',
  'transcribing': 'Transcribiendo…',
  'extracting_recipe': 'Analizando la receta…',
  'analyzing_visual_evidence': 'Revisando información visual…',
  'finalizing': 'Preparando el resultado…',
};

class PendingImport {
  PendingImport({
    required this.key,
    required this.recipeId,
    required this.payload,
    this.jobId,
    this.view,
    this.rejection,
    this.dismissed = false,
    this.collectionId,
    DateTime? created,
  }) : created = created ?? DateTime.now().toUtc();
  final String key;
  String recipeId;
  final Map<String, dynamic> payload;
  final DateTime created;
  final String? collectionId;
  String? jobId;
  String? rejection;
  Map<String, dynamic>? view;
  bool dismissed;
  String get status =>
      view?['status'] as String? ??
      (rejection == null ? 'submitting' : 'rejected');
  bool get terminal => const [
    'succeeded',
    'partial',
    'failed',
    'canceled',
    'rejected',
  ].contains(status);
  String get label => switch (status) {
    'rejected' => 'Solicitud no aceptada: ${importError(rejection!)}',
    'submitting' => 'Pendiente de confirmar el envío',
    'queued' => 'En cola; esperando al servidor…',
    'running' => stageLabels[view?['stage']] ?? 'Procesando…',
    'succeeded' =>
      view?['result']?['analysis_status'] == 'no_recipe'
          ? 'La fuente no contiene una receta'
          : 'Borrador listo para revisar',
    'partial' => 'Borrador parcial: necesita revisión',
    'canceled' => 'Importación cancelada',
    _ => importError(view?['error'] as String? ?? 'invalid_output'),
  };
  Map<String, dynamic> toJson() => {
    'key': key,
    'recipe_id': recipeId,
    'payload': payload,
    'job_id': jobId,
    'view': view,
    'rejection': rejection,
    'dismissed': dismissed,
    'collection_id': collectionId,
    'created': created.toIso8601String(),
  };
  factory PendingImport.fromJson(Map<String, dynamic> v) => PendingImport(
    key: v['key'],
    recipeId: v['recipe_id'],
    payload: Map<String, dynamic>.from(v['payload']),
    jobId: v['job_id'],
    rejection: v['rejection'],
    view: v['view'] == null ? null : Map<String, dynamic>.from(v['view']),
    dismissed: v['dismissed'] == true,
    collectionId: v['collection_id'],
    created: DateTime.parse(v['created']),
  );
  Recipe? get draft {
    try {
      final value = view?['result']?['recipe'];
      if (value is! Map) return null;
      return RecipeCodec.record({
        ...Map<String, dynamic>.from(value),
        'id': recipeId,
        'owner_id': null,
        'revision': null,
        'created_at': created.toIso8601String(),
      });
    } catch (_) {
      return null;
    }
  }
}

/// Owns logical attempts, disk-before-network, session boundary and one polling loop.
class ImportJobs extends ChangeNotifier with WidgetsBindingObserver {
  ImportJobs(this.session, this.prefs, this.client);
  final SessionRepository session;
  final SharedPreferences prefs;
  final ImportRecipeService client;
  List<PendingImport> items = [];
  String? error;
  String? _owner;
  int _epoch = 0, _failures = 0;
  bool _needsDiscovery = true;
  bool _authBlocked = false;
  bool _busy = false, _foreground = true, _disposed = false;
  Timer? _timer;
  Future<void> _writes = Future.value();
  bool get busy => _busy;
  List<PendingImport> get visible => items.where((x) => !x.dismissed).toList();
  void initialize() {
    session.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    _sessionChanged();
  }

  bool _current(int epoch) =>
      !_disposed && epoch == _epoch && session.ownerId == _owner;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (_owner == session.ownerId && _epoch > 0) return;
    _owner = session.ownerId;
    ++_epoch;
    _timer?.cancel();
    items = [];
    _needsDiscovery = true;
    _authBlocked = false;
    error = null;
    _failures = 0;
    final owner = _owner;
    if (owner != null) {
      try {
        final raw = prefs.getString('imports.v1.$owner');
        if (raw != null) {
          items = (jsonDecode(raw) as List)
              .map((x) => PendingImport.fromJson(Map<String, dynamic>.from(x)))
              .toList();
        }
      } catch (_) {
        error =
            'No se pudo leer el estado local. La lista remota permite recuperar tus jobs.';
      }
    }
    _notify();
    _schedule(immediate: true);
  }

  Future<void> _persist() {
    final owner = _owner;
    if (owner == null) return Future.value();
    final raw = jsonEncode(items.map((x) => x.toJson()).toList());
    final write = _writes.catchError((Object _) {}).then((_) async {
      if (!await prefs.setString('imports.v1.$owner', raw)) {
        throw StateError('disk');
      }
    });
    _writes = write;
    return write;
  }

  void _schedule({bool immediate = false}) {
    _timer?.cancel();
    if (_disposed || !_foreground || _owner == null || _authBlocked) return;
    _timer = Timer(
      Duration(seconds: immediate ? 0 : min(30, 2 + (1 << min(_failures, 4)))),
      () => refresh(manual: false),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _needsDiscovery = true;
      _schedule(immediate: true);
    } else {
      _timer?.cancel();
    }
  }

  Future<void> submit(
    Map<String, dynamic> payload, {
    String? collectionId,
  }) async {
    if (_owner == null || _busy) return;
    final epoch = _epoch;
    _busy = true;
    error = null;
    _timer?.cancel();
    final item = PendingImport(
      key: const Uuid().v4(),
      recipeId: const Uuid().v4(),
      payload: payload,
      collectionId: collectionId,
    );
    items.add(item);
    _notify();
    try {
      await _persist();
      if (!_current(epoch)) return;
      final id = await client.submit(item.payload, item.key);
      if (!_current(epoch)) return;
      _accepted(item, id);
      await _persist();
    } catch (e) {
      if (_current(epoch)) {
        await _submissionError(item, e);
        if (!_current(epoch)) return;
        error = e is ImportRecipeException
            ? e.message
            : 'No se pudo conservar o confirmar el intento. Reintenta.';
      }
    } finally {
      _busy = false;
      _notify();
      _schedule(immediate: true);
    }
  }

  Future<void> retry(PendingImport item) async {
    if (_busy || !items.contains(item)) return;
    if (item.jobId != null) {
      await refresh();
      return;
    }
    _busy = true;
    final epoch = _epoch;
    error = null;
    _notify();
    try {
      await _persist();
      if (!_current(epoch)) return;
      final id = await client.submit(item.payload, item.key);
      if (_current(epoch)) {
        _accepted(item, id);
        await _persist();
      }
    } catch (e) {
      if (_current(epoch)) {
        await _submissionError(item, e);
        if (!_current(epoch)) return;
        error = e is ImportRecipeException
            ? e.message
            : 'No se pudo confirmar el intento.';
      }
    } finally {
      _busy = false;
      _notify();
      _schedule(immediate: true);
    }
  }

  Future<void> _submissionError(PendingImport item, Object error) async {
    if (error is ImportRecipeException &&
        const {
          'invalid_request',
          'source_unavailable',
          'quota_exceeded',
          'budget_exhausted',
          'unauthorized',
          'idempotency_conflict',
          'disabled',
        }.contains(error.code)) {
      item.rejection = error.code;
      try {
        await _persist();
      } catch (_) {
        /* No request will start without a successful persistence retry. */
      }
    }
  }

  void _accepted(PendingImport item, String id) {
    item.rejection = null;
    final recovered = items
        .where((x) => x != item && x.jobId == id)
        .firstOrNull;
    item.jobId = id;
    item.recipeId = const Uuid().v5(
      Namespace.url.value,
      'foodiefy:$_owner:$id',
    );
    item.view ??= recovered?.view;
    if (recovered != null) items.remove(recovered);
  }

  Future<void> refresh({bool manual = true}) async {
    if (manual) {
      _authBlocked = false;
    }
    if (_authBlocked) return;
    if (_busy || !_foreground || _owner == null || _disposed) {
      _schedule();
      return;
    }
    _busy = true;
    final epoch = _epoch;
    try {
      // Recover all pages, including terminal jobs missed while the app was closed.
      if (_needsDiscovery) {
        String? cursor;
        final seenCursors = <String>{};
        do {
          final page = await client.list(cursor: cursor);
          if (!_current(epoch) || !_foreground) return;
          for (final raw in page['items'] as List) {
            final view = Map<String, dynamic>.from(raw);
            final id = view['job_id'] as String;
            var item = items.where((x) => x.jobId == id).firstOrNull;
            item ??= PendingImport(
              key: 'recovered-$id',
              recipeId: const Uuid().v5(
                Namespace.url.value,
                'foodiefy:$_owner:$id',
              ),
              payload: {},
              jobId: id,
              created: DateTime.parse(view['created_at']),
            );
            if (!items.contains(item)) items.add(item);
            item.view = view;
          }
          cursor = page['next_cursor'] as String?;
          if (cursor != null && !seenCursors.add(cursor)) {
            throw const FormatException();
          }
        } while (cursor != null);
        _needsDiscovery = false;
      } else {
        for (final item in items.where((x) => x.jobId != null && !x.terminal)) {
          final value = await client.get(item.jobId!);
          if (!_current(epoch) || !_foreground) return;
          item.view = value;
        }
      }
      // A response lost on POST is resolved only by explicit retry with the same key.
      await _persist();
      if (_current(epoch)) {
        if (_failures > 0) error = null;
        _failures = 0;
      }
    } catch (e) {
      if (_current(epoch)) {
        _failures++;
        _authBlocked = e is ImportRecipeException && e.code == 'unauthorized';
        error = e is ImportRecipeException
            ? e.message
            : 'No se pudo actualizar. Reintenta con conexión.';
      }
    } finally {
      _busy = false;
      _notify();
      _schedule();
    }
  }

  Future<void> cancel(PendingImport item) async {
    if (_busy || item.jobId == null || !items.contains(item)) return;
    _busy = true;
    final epoch = _epoch;
    try {
      final view = await client.cancel(item.jobId!);
      if (!_current(epoch)) return;
      item.view = view;
      await _persist();
    } catch (e) {
      if (_current(epoch)) {
        error = e is ImportRecipeException
            ? e.message
            : 'No se pudo confirmar la cancelación.';
      }
    } finally {
      _busy = false;
      _notify();
      _schedule();
    }
  }

  Future<void> dismiss(PendingImport item) async {
    if (!items.contains(item)) return;
    item.dismissed = true;
    await _persist();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _timer?.cancel();
    session.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    client.close();
    super.dispose();
  }
}
