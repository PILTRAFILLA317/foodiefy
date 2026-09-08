import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/session_repository.dart';

List<String> sharedUrls(String text) {
  if (text.length > 32768) return [];
  final urls = <String>{};
  for (final match in RegExp(
    r'https?://[^\s<>"\x27]+',
    caseSensitive: false,
  ).allMatches(text)) {
    final raw = match.group(0)!.replaceFirst(RegExp(r'[.,;!?)\]]+$'), '');
    final uri = Uri.tryParse(raw);
    if (uri != null &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        raw.length <= 4096) {
      urls.add(raw);
    }
    if (urls.length == 10) break;
  }
  return urls.toList();
}

class ShareInbox extends ChangeNotifier with WidgetsBindingObserver {
  ShareInbox(this.prefs, this.session);
  static const channel = MethodChannel('foodiefy/share');
  final SharedPreferences prefs;
  final SessionRepository session;
  final List<Map<String, dynamic>> _queue = [];
  Map<String, dynamic>? get pending => _queue.firstOrNull;
  bool _polling = false, _disposed = false;
  String? _owner;
  final Map<String, int> _seen = {};
  Future<void> _writes = Future.value();
  List<String> get urls => List<String>.from(pending?['urls'] ?? []);
  Future<void> initialize() async {
    _owner = session.ownerId;
    try {
      final raw = prefs.getString('share.inbox.v1');
      if (raw != null) {
        final data = jsonDecode(raw);
        _queue.addAll(
          (data['queue'] as List? ?? []).map(
            (x) => Map<String, dynamic>.from(x),
          ),
        );
        _seen.addAll(Map<String, int>.from(data['seen'] ?? {}));
      }
    } catch (_) {
      _queue.clear();
    }
    _expire();
    _queue.removeWhere((x) => x['owner'] != null && x['owner'] != _owner);
    session.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') await poll();
    });
    await poll();
  }

  void _expire() {
    final cutoff =
        DateTime.now().millisecondsSinceEpoch -
        const Duration(hours: 24).inMilliseconds;
    _queue.removeWhere((x) => (x['created'] as int? ?? 0) < cutoff);
    _seen.removeWhere((_, stamp) => stamp < cutoff);
    while (_seen.length > 200) {
      _seen.remove(_seen.keys.first);
    }
  }

  void _sessionChanged() {
    final next = session.ownerId;
    if (_owner == next) return;
    if (_owner != null) {
      _queue.clear();
    } else if (next != null && pending != null) {
      for (final entry in _queue) {
        entry['owner'] = next;
      }
    }
    _owner = next;
    _save().catchError((Object _) {});
    if (!_disposed) notifyListeners();
  }

  Future<void> _save() {
    final raw = jsonEncode({'queue': _queue, 'seen': _seen});
    _writes = _writes.catchError((Object _) {}).then((_) async {
      if (!await prefs.setString('share.inbox.v1', raw)) {
        throw StateError('share_storage');
      }
    });
    return _writes;
  }

  Future<bool> receive(Map<String, dynamic> event) async {
    _expire();
    final id = event['id'];
    final stamp = event['created'];
    if (id is! String ||
        id.length > 100 ||
        stamp is! int ||
        stamp > DateTime.now().millisecondsSinceEpoch + 60000 ||
        DateTime.now().millisecondsSinceEpoch - stamp > 86400000) {
      return false;
    }
    if (_seen.containsKey(id)) {
      await _save();
      return false;
    }
    if (_queue.length >= 20) throw StateError('share_inbox_full');
    _seen[id] = stamp;
    final urls = (event['urls'] is List)
        ? (event['urls'] as List)
              .whereType<String>()
              .expand(sharedUrls)
              .toSet()
              .take(10)
              .toList()
        : sharedUrls(event['text'] is String ? event['text'] : '');
    _queue.add({'id': id, 'created': stamp, 'urls': urls, 'owner': _owner});
    await _save();
    if (!_disposed) notifyListeners();
    return true;
  }

  Future<void> clear({String? expectedId}) async {
    if (expectedId != null && pending?['id'] != expectedId) return;
    if (_queue.isNotEmpty) _queue.removeAt(0);
    await _save();
    if (!_disposed) notifyListeners();
  }

  Future<void> poll() async {
    if (_polling || _disposed) return;
    _polling = true;
    try {
      _expire();
      for (var count = 0; count < 20; count++) {
        final event = await channel.invokeMapMethod<String, dynamic>('peek');
        if (event == null) break;
        await receive(event);
        await channel.invokeMethod('ack', event['id']);
      }
    } on MissingPluginException {
      /* Desktop/tests do not receive native shares. */
    } on PlatformException {
      /* Native event remains for next resume. */
    } catch (_) {
      /* Failed persistence: do not acknowledge the native event. */
    } finally {
      _polling = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) poll();
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    channel.setMethodCallHandler(null);
    super.dispose();
  }
}
