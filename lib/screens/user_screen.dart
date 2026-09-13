import 'package:flutter/material.dart';
import '../repositories/app_repositories.dart';
import '../repositories/auth_errors.dart';
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
              session.email ?? 'Tu cuenta',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              session.ownerId == null
                  ? 'Inicia sesión para acceder a tus recetas.'
                  : 'Tus recetas son privadas. Los guardados se confirman en el servidor.',
            ),
            if (session.error != null) Text(session.error!),
            const SizedBox(height: 24),
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
                    final shopping = AppRepositories.shopping;
                    if (shopping?.pending == true) {
                      final choice = await showDialog<String>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Hay compras pendientes'),
                          content: const Text(
                            'Elige qué hacer antes de cerrar sesión.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, 'sync'),
                              child: const Text('Sincronizar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, 'discard'),
                              child: const Text('Descartar pendientes'),
                            ),
                          ],
                        ),
                      );
                      if (choice == null) return;
                      if (choice == 'sync') {
                        await shopping!.sync();
                        if (shopping.pending) return;
                      } else {
                        await shopping!.discardPending();
                      }
                    }
                    await session.signOut();
                  } catch (error, stack) {
                    logAuthError(error, stack);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(authErrorMessage(error))),
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
