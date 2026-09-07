import '../config/cloud_runtime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static SupabaseClient? get _client => CloudRuntime.client;

  static Stream<AuthState> authStateChanges() =>
      _client?.auth.onAuthStateChange ?? const Stream<AuthState>.empty();

  static User? get currentUser => _client?.auth.currentUser;

  static Future<void> signOut() async {
    await _client?.auth.signOut();
  }
}
