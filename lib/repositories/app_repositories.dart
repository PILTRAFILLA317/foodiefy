import '../config/cloud_runtime.dart';
import 'cloud_gateway.dart';
import 'library_repository.dart';
import 'local_cache.dart';
import 'session_repository.dart';

class AppRepositories {
  static SessionRepository session = SessionRepository(null);
  static LibraryRepository? library;
  static Future<void> initialize() async {
    if (library != null) {
      library!.dispose();
      await library!.cache.close();
      library = null;
    }
    session.dispose();
    session = SessionRepository(CloudRuntime.client);
    if (CloudRuntime.client != null) {
      library = LibraryRepository(
        session,
        await LocalCache.open(),
        SupabaseGateway(CloudRuntime.client!),
      );
      await library!.initialize();
    }
  }

  static LibraryRepository get writable =>
      library ??
      (throw const CloudFailure(
        'Inicia sesión y configura cloud para guardar. El rescate local es de solo lectura.',
      ));
}
