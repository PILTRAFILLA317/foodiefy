import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionRepository extends ChangeNotifier {
  SessionRepository(this.client) {
    _session = client?.auth.currentSession;
    _subscription = client?.auth.onAuthStateChange.listen(
      (state) {
        _session = state.session;
        if (state.event == AuthChangeEvent.passwordRecovery) {
          recoveringPassword = true;
        }
        if (_session == null) recoveringPassword = false;
        notifyListeners();
      },
      onError: (Object _) {
        error =
            'No se pudo renovar la sesión. Revisa la conexión e inicia sesión de nuevo.';
        notifyListeners();
      },
    );
  }
  final SupabaseClient? client;
  StreamSubscription<AuthState>? _subscription;
  Session? _session;
  bool recoveringPassword = false;
  String? error;
  String? get ownerId => _session?.user.id;
  String? get email => _session?.user.email;
  bool get configured => client != null;
  static const redirectUrl = 'io.supabase.foodiefy://login-callback';

  SupabaseClient get _required =>
      client ?? (throw StateError('Cloud no está configurado.'));
  Future<void> signIn(String email, String password) async {
    final response = await _required.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.session == null) {
      throw StateError('No hay una sesión confirmada.');
    }
    _session = response.session;
    error = null;
    notifyListeners();
  }

  /// false means confirmation is pending, never a signed-in success.
  Future<bool> register(String email, String password) async {
    final response = await _required.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: redirectUrl,
    );
    _session = response.session;
    notifyListeners();
    return response.session != null;
  }

  Future<void> recover(String email) => _required.auth.resetPasswordForEmail(
    email.trim(),
    redirectTo: redirectUrl,
  );
  Future<void> updatePassword(String password) async {
    if (ownerId == null || !recoveringPassword) {
      throw StateError('Abre primero el enlace de recuperación.');
    }
    await _required.auth.updateUser(UserAttributes(password: password));
    recoveringPassword = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    // Hide private data immediately, even if remote revocation fails.
    _session = null;
    recoveringPassword = false;
    notifyListeners();
    try {
      await _required.auth.signOut(scope: SignOutScope.local);
    } catch (_) {
      error =
          'La sesión se ocultó, pero no se pudo completar el cierre. Reintenta con conexión.';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> savePendingImport(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw StateError('Enlace de importación inválido.');
    }
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('pending_import_v1', url)) {
      throw StateError('No se pudo conservar el enlace.');
    }
  }

  Future<String?> pendingImport() async =>
      (await SharedPreferences.getInstance()).getString('pending_import_v1');
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
