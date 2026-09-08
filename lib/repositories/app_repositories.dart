import '../shopping/shopping_repository.dart';
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
  static ShoppingRepository? shopping;
  static Future<void> initialize() async {
    shopping?.dispose();
    shopping = null;
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
      shopping = ShoppingRepository(session, library!.cache, (
        owner,
        operation,
        kind,
        payload,
      ) async {
        if (session.ownerId != owner) throw StateError('La sesión cambió.');
        final result = await CloudRuntime.client!
            .rpc(
              operation == null
                  ? 'shopping_snapshot_v1'
                  : 'shopping_mutation_v1',
              params: operation == null
                  ? {}
                  : {
                      'p_operation_id': operation,
                      'p_kind': kind,
                      'p_payload': payload,
                    },
            )
            .timeout(const Duration(seconds: 20));
        if (session.ownerId != owner) throw StateError('La sesión cambió.');
        return Map<String, dynamic>.from(result);
      });
      await shopping!.initialize();
      session.beforeSignOut = () async {
        if (shopping?.pending == true) {
          throw StateError(
            'Hay compras pendientes. Sincroniza o descarta explícitamente.',
          );
        }
      };
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
