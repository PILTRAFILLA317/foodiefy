import 'package:flutter/material.dart';
import '../repositories/app_repositories.dart';
import 'auth/account_form.dart';
import 'legacy_recovery_screen.dart';

class UserScreen extends StatelessWidget {
  const UserScreen({super.key, required this.savedRecipes});
  final int savedRecipes;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppRepositories.session,
    builder: (context, _) {
      final session = AppRepositories.session;
      return Scaffold(
        appBar: AppBar(title: const Text('Tu cuenta')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.person, size: 48, color: Colors.black),
            ),
            const SizedBox(height: 24),
            Text(
              session.email ?? 'Rescate y lectura local',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              session.ownerId == null
                  ? 'Necesitas una cuenta para guardar e importar en cloud. Los datos antiguos solo se trasladan después de revisarlos y confirmar su propietario.'
                  : 'Tus recetas son privadas. Los guardados se confirman en el servidor.',
            ),
            if (session.error != null) Text(session.error!),
            const SizedBox(height: 24),
            if (session.ownerId == null && session.configured) ...[
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountForm(mode: AccountMode.login),
                  ),
                ),
                child: const Text('Iniciar sesión'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const AccountForm(mode: AccountMode.register),
                  ),
                ),
                child: const Text('Crear cuenta'),
              ),
            ],
            OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LegacyRecoveryScreen()),
              ),
              child: const Text('Rescatar datos antiguos / exportar backup'),
            ),
            if (session.ownerId != null)
              TextButton(
                onPressed: () async {
                  try {
                    await session.signOut();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No se pudo completar el cierre. Reintenta con conexión.',
                          ),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Cerrar sesión'),
              ),
          ],
        ),
      );
    },
  );
}
