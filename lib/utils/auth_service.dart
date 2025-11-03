import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _client = Supabase.instance.client;

  static Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  static User? get currentUser => _client.auth.currentUser;

  static Future<void> signOut() => _client.auth.signOut();
}
