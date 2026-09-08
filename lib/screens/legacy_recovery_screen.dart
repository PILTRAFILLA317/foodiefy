import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../recovery/legacy_recovery.dart';
import '../repositories/app_repositories.dart';
import '../repositories/library_repository.dart';

class LegacyRecoveryScreen extends StatefulWidget {
  const LegacyRecoveryScreen({super.key});
  @override
  State<LegacyRecoveryScreen> createState() => _LegacyRecoveryScreenState();
}

class _LegacyRecoveryScreenState extends State<LegacyRecoveryScreen> {
  LegacyRecovery? _recovery;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final recovery = await LegacyRecovery.open();
      await recovery.prepare();
      if (!mounted) {
        recovery.dispose();
        return;
      }
      setState(() => _recovery = recovery);
      recovery.addListener(_changed);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No se pudo verificar el backup. Conserva los datos antiguos y reintenta.',
        );
      }
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is CloudFailure
              ? e.message
              : 'No se pudo completar la operación. El backup se conserva.',
        );
      }
    }
  }

  Future<void> _import() async {
    final session = AppRepositories.session;
    final owner = session.ownerId;
    if (owner == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar cuenta propietaria'),
        content: Text(
          'Copiar estas recetas privadas a:\n${session.email}\n$owner\n\nSolo se subirán las imágenes marcadas. Este backup quedará vinculado a esta cuenta y no se borrará.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmo esta cuenta'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(
        () => _recovery!.importTo(
          AppRepositories.writable,
          confirmedOwner: owner,
        ),
      );
    }
  }

  Future<void> _editRecipe(
    int index,
    Map<String, dynamic> entry, {
    bool collection = false,
  }) async {
    final controller = TextEditingController(
      text: entry['corrected_raw'] ?? entry['raw'].toString(),
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revisar copia #${index + 1}'),
        content: SizedBox(
          width: 550,
          child: TextField(
            controller: controller,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'JSON de la copia; el original se conserva',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Validar copia'),
          ),
        ],
      ),
    );
    // Dialog route can still animate out; dispose after its transition.
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    if (value != null) {
      await _run(
        () => collection
            ? _recovery!.correctCollection(index, value)
            : _recovery!.correctRecipe(index, value),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recovery = _recovery;
    final plan = recovery?.plan;
    final otherOwner =
        plan?['owner_id'] != null &&
        plan?['owner_id'] != AppRepositories.session.ownerId;
    return Scaffold(
      appBar: AppBar(title: const Text('Rescate de datos antiguos')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          if (recovery == null) const LinearProgressIndicator(),
          if (otherOwner)
            const Text(
              'Este rescate está vinculado a otra cuenta. Inicia sesión con ella para consultar o reanudar.',
            ),
          if (plan != null && !otherOwner) ...[
            const Text(
              'Dry-run · originales en cuarentena',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              '${recovery!.entries.length} recetas · ${(plan['collections'] as List).length} colecciones · ${recovery.relations.length} referencias',
            ),
            SelectableText(
              'Backup: ${recovery.directory.path}\nSHA-256: ${recovery.checksum}',
            ),
            TextButton(
              onPressed: () => _run(() async {
                await recovery.verifyBackup();
                await Clipboard.setData(
                  ClipboardData(
                    text: await File(
                      '${recovery.directory.path}/raw.json',
                    ).readAsString(),
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Raw copiado. Guárdalo en un archivo privado; el backup local y las imágenes se conservan.',
                      ),
                    ),
                  );
                }
              }),
              child: const Text('Exportar raw: copiar JSON'),
            ),
            const Text(
              'El orden y los IDs nuevos corresponden a cada ocurrencia, incluso cuando los IDs antiguos están vacíos o repetidos. Las relaciones ambiguas requieren revisión.',
            ),
            const SizedBox(height: 16),
            for (final entry in recovery.entries)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${(entry['index'] as int) + 1} · ${entry['draft']?['title'] ?? 'Objeto pendiente de revisión'}',
                      ),
                      Text(
                        'Ingredientes: ${entry['ingredient_count'] ?? '?'} · imagen: ${entry['image_status']} · ${entry['done'] == true ? 'guardado' : 'pendiente'}',
                      ),
                      if (entry['issue'] != null)
                        Text(
                          entry['issue'],
                          style: const TextStyle(color: Colors.red),
                        ),
                      TextButton(
                        onPressed: recovery.busy || plan['confirmed'] == true
                            ? null
                            : () => _editRecipe(entry['index'], entry),
                        child: const Text('Revisar copia raw'),
                      ),
                      if (entry['image_status'] == 'copied')
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Subir esta imagen privada'),
                          value: entry['selected_image'] == true,
                          onChanged: recovery.busy || plan['confirmed'] == true
                              ? null
                              : (value) => _run(
                                  () => recovery.selectImage(
                                    entry['index'],
                                    value ?? false,
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            for (var i = 0; i < recovery.relations.length; i++)
              if (recovery.relations[i]['resolved'] != true) ...[
                Text(
                  'Relación ambigua/ausente: colección #${(recovery.relations[i]['collection_index'] as int) + 1}, referencia #${(recovery.relations[i]['relation_index'] as int) + 1}',
                ),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Elige la ocurrencia o conserva sin asociar',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: -1,
                      child: Text('Conservar raw sin asociar'),
                    ),
                    for (final entry in recovery.entries)
                      DropdownMenuItem(
                        value: entry['index'] as int,
                        child: Text(
                          '#${(entry['index'] as int) + 1} · ${entry['draft']?['title'] ?? 'sin título'}',
                        ),
                      ),
                  ],
                  onChanged: recovery.busy
                      ? null
                      : (value) {
                          if (value != null) {
                            _run(
                              () => recovery.resolve(
                                i,
                                value == -1 ? null : value,
                              ),
                            );
                          }
                        },
                ),
              ],
            for (final c in plan['collections'])
              Card(
                child: ListTile(
                  title: Text(
                    'Colección #${c['index'] + 1}: ${c['name'] ?? 'Sin interpretar'}',
                  ),
                  subtitle: c['issue'] == null
                      ? null
                      : Text(
                          c['issue'],
                          style: const TextStyle(color: Colors.red),
                        ),
                  trailing: TextButton(
                    onPressed: recovery.busy || plan['confirmed'] == true
                        ? null
                        : () => _editRecipe(
                            c['index'],
                            Map<String, dynamic>.from(c),
                            collection: true,
                          ),
                    child: const Text('Revisar raw'),
                  ),
                ),
              ),
            if (recovery.busy) const LinearProgressIndicator(),
            if (plan['complete'] == true)
              const Text('Rescate verificado. Backup conservado.'),
            ElevatedButton(
              onPressed:
                  recovery.busy || AppRepositories.session.ownerId == null
                  ? null
                  : _import,
              child: Text(
                plan['confirmed'] == true
                    ? 'Reanudar / verificar sin duplicar'
                    : 'Elegir cuenta y confirmar importación',
              ),
            ),
            if (AppRepositories.session.ownerId == null)
              const Text(
                'Inicia sesión desde Tu cuenta para elegir el propietario. Puedes revisar y exportar antes.',
              ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _recovery?.removeListener(_changed);
    _recovery?.dispose();
    super.dispose();
  }
}
