import 'package:supabase_flutter/supabase_flutter.dart';

/// Set only after successful initialization. Local rescue never touches Supabase.instance.
class CloudRuntime {
  static SupabaseClient? client;
  static bool get enabled => client != null;
}
