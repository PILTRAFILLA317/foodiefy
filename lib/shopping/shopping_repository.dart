import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../repositories/local_cache.dart';
import '../repositories/session_repository.dart';

typedef ShoppingCall =
    Future<Map<String, dynamic>> Function(
      String owner,
      String? operation,
      String? kind,
      Map<String, dynamic> payload,
    );

class ShoppingRepository extends ChangeNotifier with WidgetsBindingObserver {
  ShoppingRepository(this.session, this.cache, this.call) {
    session.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
  }
  final SessionRepository session;
  final LocalCache cache;
  final ShoppingCall call;
  String? owner;
  int epoch = 0;
  bool loaded = false;
  Future<void> transition = Future.value();
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> queue = [];
  String? message;
  bool busy = false, disposed = false, active = true;
  Timer? timer;
  int failures = 0;
  Future<void> serial = Future.value();
  bool get pending => queue.isNotEmpty;
  void notify() {
    if (!disposed) notifyListeners();
  }

  Future<void> initialize() async {
    transition = _load();
    await transition;
  }

  void _changed() {
    if (owner != session.ownerId) {
      owner = null;
      items = [];
      queue = [];
      notify();
      transition = _load();
    }
  }

  Future<void> _load() async {
    final generation = ++epoch;
    loaded = false;
    final next = session.ownerId;
    owner = next;
    items = [];
    queue = [];
    if (next == null) return;
    Map<String, dynamic>? state;
    try {
      state = await cache.readShopping(next);
    } catch (_) {
      message =
          'No se pudo abrir la compra guardada. No se sobrescribirá; reinicia la app.';
      notify();
      return;
    }
    if (owner != next || disposed || generation != epoch) return;
    loaded = true;
    items = (state?['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    queue = (state?['queue'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    notify();
    unawaited(sync());
  }

  Future<void> save(String who) =>
      cache.writeShopping(who, {'items': items, 'queue': queue});
  Future<void> enqueue(String kind, Map<String, dynamic> payload) =>
      enqueueBatch([(kind, payload)]);
  Future<void> enqueueBatch(List<(String, Map<String, dynamic>)> operations) {
    final who = owner;
    final done = serial.then((_) async {
      await transition;
      if (!loaded) throw StateError("La compra aún no está disponible.");
      if (who == null || owner != who || session.ownerId != who) {
        throw StateError('Inicia sesión.');
      }
      if (queue.length + operations.length > 200) {
        throw StateError(
          'Hay 200 operaciones pendientes. Sincroniza antes de continuar.',
        );
      }
      for (final (kind, payload) in operations) {
        if (utf8.encode(jsonEncode(payload)).length > 32000) {
          throw StateError('Producto demasiado largo.');
        }
        if (['add', 'edit'].contains(kind) &&
            ('${payload['name'] ?? ''}'.trim().isEmpty ||
                '${payload['name']}'.length > 200)) {
          throw StateError('Revisa el nombre.');
        }
      }
      final oldItems = jsonDecode(jsonEncode(items)) as List;
      final oldQueue = jsonDecode(jsonEncode(queue)) as List;
      for (final (kind, payload) in operations) {
        final p = Map<String, dynamic>.from(payload);
        p['id'] ??= const Uuid().v4();
        final dependent = queue.any((e) => e['payload']['id'] == p['id']);
        queue.add({
          'operation_id': const Uuid().v4(),
          'kind': kind,
          'payload': p,
          'dependent': dependent,
        });
        final index = items.indexWhere((e) => e['id'] == p['id']);
        if (kind == 'add') {
          items.add({...p, 'checked': false, 'revision': 0});
        } else if (index >= 0) {
          items[index] = {
            ...items[index],
            ...p,
            if (kind == 'delete') 'deleted_at': 'pending',
          };
        }
      }
      try {
        await save(who);
      } catch (_) {
        items = oldItems.map((e) => Map<String, dynamic>.from(e)).toList();
        queue = oldQueue.map((e) => Map<String, dynamic>.from(e)).toList();
        rethrow;
      }
      notify();
    });
    serial = done.catchError((Object _) {});
    return done.then((_) {
      unawaited(sync());
    });
  }

  Future<void> sync() async {
    if (busy || owner == null || !active || disposed) return;
    busy = true;
    final who = owner!;
    final generation = epoch;
    try {
      await transition;
      if (!loaded || epoch != generation) return;
      await serial;
      while (queue.isNotEmpty && owner == who && session.ownerId == who) {
        final op = queue.first;
        if (op['conflict'] == true) {
          message =
              'Conflicto pendiente: revisa o descarta explícitamente la operación.';
          break;
        }
        op['attempted'] = true;
        await save(who);
        final result = await call(
          who,
          op['operation_id'],
          op['kind'],
          Map<String, dynamic>.from(op['payload']),
        );
        if (owner != who ||
            session.ownerId != who ||
            generation != epoch ||
            disposed) {
          return;
        }
        await serial;
        final oldId = op['payload']['id'];
        queue.removeAt(0);
        // Only unsent dependent operations can acquire the accepted server identity/revision.
        var resolvedRevision = false;
        for (final next in queue) {
          if (next['payload']['id'] == oldId && next['attempted'] != true) {
            next['payload']['id'] = result['id'];
            if (next['dependent'] == true && !resolvedRevision) {
              next['payload']['revision'] = result['revision'];
              next['dependent'] = false;
              resolvedRevision = true;
            }
          }
        }
        items.removeWhere((e) => e['id'] == oldId || e['id'] == result['id']);
        items.add(result);
        for (final next in queue) {
          final p = next['payload'];
          final i = items.indexWhere((e) => e['id'] == p['id']);
          if (i >= 0) {
            items[i] = {
              ...items[i],
              ...Map<String, dynamic>.from(p),
              if (next['kind'] == 'delete') 'deleted_at': 'pending',
            };
          }
        }
        await save(who);
        notify();
      }
      if (!disposed && owner == who && generation == epoch && queue.isEmpty) {
        final snapshot = await call(who, null, null, {});
        await serial;
        if (!disposed && owner == who && generation == epoch && queue.isEmpty) {
          items = (snapshot['items'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          await save(who);
          message = null;
        }
      }
      failures = 0;
    } catch (e) {
      if (!disposed && owner == who && generation == epoch) {
        if (e is PostgrestException &&
            [
              '40001',
              'P0002',
              '23505',
              '22023',
              '23514',
              '23502',
            ].contains(e.code) &&
            queue.isNotEmpty) {
          queue.first['conflict'] = true;
          await save(who);
          message = 'Operación pendiente de revisión. No se ha descartado.';
        } else {
          failures = (failures + 1).clamp(1, 6);
          message =
              'Sin conexión confirmada · cambios pendientes guardados en este dispositivo';
        }
      }
    } finally {
      busy = false;
      notify();
      timer?.cancel();
      if (!disposed && active) {
        timer = Timer(
          Duration(seconds: failures == 0 ? 15 : 1 << failures),
          sync,
        );
      }
    }
  }

  Future<Map<String, dynamic>?> conflictVersion() async {
    if (owner == null || queue.isEmpty || queue.first['conflict'] != true) {
      return null;
    }
    final who = owner!, generation = epoch;
    final snapshot = await call(who, null, null, {});
    if (owner != who || generation != epoch) {
      throw StateError('La sesión cambió.');
    }
    final id = queue.first['payload']['id'];
    for (final item in snapshot['items'] as List) {
      if (item['id'] == id) return Map<String, dynamic>.from(item);
    }
    return null;
  }

  Future<void> resolveConflict(Map<String, dynamic> current) async {
    if (busy ||
        owner == null ||
        queue.isEmpty ||
        queue.first['conflict'] != true) {
      throw StateError('Espera o recarga.');
    }
    if (current['deleted_at'] != null) {
      throw StateError('El producto fue borrado. No se puede restaurar.');
    }
    final op = queue.first;
    if (op['payload']['id'] != current['id'] || current['owner_id'] != owner) {
      throw StateError('La sesión cambió.');
    }
    final replacement = {
      ...op,
      'operation_id': const Uuid().v4(),
      'payload': {
        ...Map<String, dynamic>.from(op['payload']),
        'revision': current['revision'],
      },
      'conflict': false,
      'attempted': false,
    };
    queue[0] = replacement;
    try {
      await save(owner!);
    } catch (_) {
      queue[0] = op;
      rethrow;
    }
    notify();
    await sync();
  }

  Future<void> discardPending() async {
    if (busy) throw StateError('Espera a que termine la sincronización.');
    if (owner == null) return;
    queue = [];
    items = [];
    await save(owner!);
    notify();
    await sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) {
      unawaited(sync());
    } else {
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    disposed = true;
    timer?.cancel();
    session.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
