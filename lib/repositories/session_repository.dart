import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_errors.dart';

enum SessionStatus {
  initializing,
  unauthenticated,
  authenticated,
  passwordRecovery,
}

class SessionRepository extends ChangeNotifier {
  SessionRepository(this.client) {
    _session = client?.auth.currentSession;
    _initializing = _session?.isExpired ?? false;
    _scheduleExpiry();
    _subscription = client?.auth.onAuthStateChange.listen(
      (state) {
        // A refresh completed after logout/account switch must not restore its owner.
        if ((state.event == AuthChangeEvent.tokenRefreshed ||
                state.event == AuthChangeEvent.userUpdated) &&
            state.session?.user.id != _session?.user.id) {
          return;
        }
        if (state.event == AuthChangeEvent.signedIn ||
            state.session?.user.id != _session?.user.id) {
          _recoveringPassword = false;
        }
        _session = state.session;
        error = null;
        if (state.event == AuthChangeEvent.passwordRecovery) {
          _recoveringPassword = _session != null && !_session!.isExpired;
        }
        if (_session == null) _recoveringPassword = false;
        _scheduleExpiry();
        notifyListeners();
      },
      onError: (Object exception, StackTrace stack) {
        logAuthError(exception, stack);
        error = authErrorMessage(exception);
        notifyListeners();
      },
    );
  }
  final SupabaseClient? client;
  StreamSubscription<AuthState>? _subscription;
  Session? _session;
  Timer? _expiryTimer;
  bool _initializing = false;
  bool _recoveringPassword = false;
  bool get recoveringPassword => _recoveringPassword && ownerId != null;
  SessionStatus get status => _initializing
      ? SessionStatus.initializing
      : recoveringPassword
      ? SessionStatus.passwordRecovery
      : ownerId != null
      ? SessionStatus.authenticated
      : SessionStatus.unauthenticated;
  String? error;
  String? get ownerId =>
      _session?.isExpired == false ? _session?.user.id : null;
  String? get accessToken => ownerId == null ? null : _session?.accessToken;

  /// Supabase owns persistence/refresh; never admit its expired startup snapshot.
  Future<void> initialize() async {
    try {
      if (_session?.isExpired == true) {
        await _required.auth.refreshSession().timeout(
          const Duration(seconds: 20),
        );
      }
    } catch (exception, stack) {
      logAuthError(exception, stack);
      error = authErrorMessage(exception);
    } finally {
      _initializing = false;
      notifyListeners();
    }
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    final expiresAt = _session?.expiresAt;
    if (expiresAt == null || _session!.isExpired) return;
    // Match the installed SDK's ten-second safety margin.
    final delay = DateTime.fromMillisecondsSinceEpoch(
      expiresAt * 1000,
    ).subtract(const Duration(seconds: 10)).difference(DateTime.now());
    _expiryTimer = Timer(delay, notifyListeners);
  }

  Future<void> refreshAccessToken() async {
    final owner = ownerId;
    if (owner == null) throw StateError('Inicia sesión.');
    final response = await _required.auth.refreshSession();
    if (ownerId != owner || response.session?.user.id != owner) {
      throw StateError('La sesión cambió.');
    }
    _session = response.session;
  }

  String? get email => _session?.user.email;
  bool get configured => client != null;
  static const redirectUrl = 'io.supabase.foodiefy://login-callback';

  SupabaseClient get _required =>
      client ?? (throw StateError('El acceso no está configurado.'));
  Future<void> signIn(String email, String password) async {
    final response = await _required.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (response.session == null) {
      throw StateError('No hay una sesión confirmada.');
    }
    _session = response.session;
    _scheduleExpiry();
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
    _startResendCooldown();
    _session = response.session;
    _scheduleExpiry();
    notifyListeners();
    return response.session != null;
  }

  Future<void> recover(String email) => _required.auth.resetPasswordForEmail(
    email.trim(),
    redirectTo: redirectUrl,
  );
  DateTime? _resendAvailableAt;
  bool _resending = false;
  int get resendCooldownSeconds {
    final remaining =
        _resendAvailableAt?.difference(DateTime.now()).inMilliseconds ?? 0;
    return remaining <= 0 ? 0 : (remaining / 1000).ceil();
  }

  void _startResendCooldown() {
    _resendAvailableAt = DateTime.now().add(const Duration(seconds: 60));
  }

  Future<void> resendConfirmation(String email) async {
    if (_resending || resendCooldownSeconds > 0) {
      throw const AuthException('Email rate limit exceeded', statusCode: '429');
    }
    _resending = true;
    _startResendCooldown();
    try {
      await _required.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: redirectUrl,
      );
    } finally {
      _resending = false;
    }
  }

  Future<void> updatePassword(String password) async {
    if (ownerId == null || !recoveringPassword) {
      throw StateError('Abre primero el enlace de recuperación.');
    }
    final owner = ownerId;
    await _required.auth.updateUser(UserAttributes(password: password));
    if (ownerId != owner || !recoveringPassword) {
      throw StateError('La sesión cambió.');
    }
    _recoveringPassword = false;
    notifyListeners();
  }

  Future<void> Function()? beforeSignOut;
  Future<void> signOut() async {
    await beforeSignOut?.call();
    // Hide private data immediately, even if remote revocation fails.
    _session = null;
    _recoveringPassword = false;
    _expiryTimer?.cancel();
    notifyListeners();
    try {
      await _required.auth.signOut(scope: SignOutScope.local);
    } catch (exception, stack) {
      logAuthError(exception, stack);
      error = authErrorMessage(exception);
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
    _expiryTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
