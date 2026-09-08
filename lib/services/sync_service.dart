import '../repositories/library_repository.dart';

/// Legacy automatic ownership assignment is retired. Use the reviewed rescue flow.
@Deprecated('Use LegacyRecovery after explicit account confirmation')
class SyncService {
  Future<void> syncUserData() async {
    throw const CloudFailure(
      'Abre Rescatar datos antiguos y confirma la cuenta antes de importar.',
    );
  }
}
