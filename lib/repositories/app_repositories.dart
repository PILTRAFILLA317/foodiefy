import '../imports/share_inbox.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../imports/import_jobs.dart';
import '../services/import_service.dart';
import '../config/cloud_runtime.dart';
import 'cloud_gateway.dart';
import 'library_repository.dart';
import 'local_cache.dart';
import 'session_repository.dart';

class AppRepositories {
  static SessionRepository session = SessionRepository(null);
  static LibraryRepository? library;
  static ImportJobs? imports;
  static ShareInbox? shares;
  static Future<void> initialize() async {
    shares?.dispose();
    shares = null;
    imports?.dispose();
    imports = null;
    if (library != null) {
      library!.dispose();
      await library!.cache.close();
      library = null;
    }
    session.dispose();
    session = SessionRepository(CloudRuntime.client);
    shares = ShareInbox(await SharedPreferences.getInstance(), session);
    await shares!.initialize();
    if (CloudRuntime.client != null) {
      library = LibraryRepository(
        session,
        await LocalCache.open(),
        SupabaseGateway(CloudRuntime.client!),
      );
      await library!.initialize();
      imports = ImportJobs(
        session,
        await SharedPreferences.getInstance(),
        ImportRecipeService(),
      )..initialize();
    }
  }

  static LibraryRepository get writable =>
      library ??
      (throw const CloudFailure(
        'Inicia sesión y configura cloud para guardar. El rescate local es de solo lectura.',
      ));
}
