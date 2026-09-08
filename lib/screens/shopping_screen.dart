import 'package:flutter/material.dart';
import '../repositories/app_repositories.dart';
import '../models/recipe.dart';
import '../shopping/quantities.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final repo = AppRepositories.shopping;
    if (repo == null || repo.owner == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi compra')),
        body: const Center(
          child: Text('Inicia sesión para usar tu lista personal.'),
        ),
      );
    }
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final visible = repo.items
            .where((e) => e['deleted_at'] == null)
            .toList();
        final checked = visible.where((e) => e['checked'] == true).length;
        return Scaffold(
          appBar: AppBar(
            title: Text('Mi compra · ${visible.length - checked} pendientes'),
            actions: [
              IconButton(
                tooltip: 'Sincronizar',
                onPressed: repo.sync,
                icon: const Icon(Icons.sync),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (repo.pending)
                Text('${repo.queue.length} cambios pendientes de sincronizar'),
              if (repo.message != null) Text(repo.message!),
              if (repo.queue.any((e) => e['conflict'] == true)) ...[
                TextButton(
                  onPressed: () => _run(context, () async {
                    final current = await repo.conflictVersion();
                    if (!context.mounted) return;
                    if (current == null || current['deleted_at'] != null) {
                      await _confirm(
                        context,
                        'El producto fue borrado. La propuesta se conserva; puedes copiarla y añadir un producto nuevo.',
                      );
                      return;
                    }
                    if (await _confirm(
                          context,
                          'Servidor: ${current['name']} · ${humanQuantity(current['quantity'])} ${current['unit'] ?? ''}. ¿Aplicar tus valores pendientes sobre esta versión?',
                        ) &&
                        context.mounted) {
                      await repo.resolveConflict(current);
                    }
                  }),
                  child: const Text('Revisar conflicto'),
                ),

                const Text(
                  'Tu propuesta se conserva. Revisa la versión del servidor antes de volver a aplicarla.',
                ),
                ...repo.queue
                    .where((e) => e['conflict'] == true)
                    .map(
                      (e) => SelectableText(
                        '${e['payload']['name'] ?? 'Producto'} · ${humanQuantity(e['payload']['quantity'])} ${e['payload']['unit'] ?? ''} · ${e['payload']['notes'] ?? ''}',
                      ),
                    ),
              ],
              FilledButton.icon(
                onPressed: () => editShopping(context),
                icon: const Icon(Icons.add),
                label: const Text('Añadir producto'),
              ),
              for (final done in [false, true]) ...[
                Text(
                  done ? 'Comprados ($checked)' : 'Por comprar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ...visible
                    .where((e) => (e['checked'] == true) == done)
                    .map(
                      (item) => ListTile(
                        leading: Checkbox(
                          value: done,
                          onChanged: (value) => _run(
                            context,
                            () => repo.enqueue('checked', {
                              'id': item['id'],
                              'revision': item['revision'],
                              'checked': value,
                            }),
                          ),
                        ),
                        title: Text('${item['name']}'),
                        subtitle: Text(
                          '${humanQuantity(item['quantity'])}${item['quantity_max'] == null ? '' : '–${humanQuantity(item['quantity_max'])}'} ${item['unit'] ?? ''}\n${item['raw_text']}',
                        ),
                        onTap: () => editShopping(context, item: item),
                        trailing: IconButton(
                          tooltip: 'Borrar',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _run(
                            context,
                            () => repo.enqueue('delete', {
                              'id': item['id'],
                              'revision': item['revision'],
                            }),
                          ),
                        ),
                      ),
                    ),
              ],
              if (checked > 0)
                TextButton(
                  onPressed: () async {
                    if (await _confirm(
                      context,
                      '¿Vaciar los $checked productos comprados?',
                    )) {
                      if (context.mounted) {
                        await _run(
                          context,
                          () => repo.enqueueBatch(
                            visible
                                .where((e) => e['checked'] == true)
                                .map(
                                  (item) => (
                                    'delete',
                                    <String, dynamic>{
                                      'id': item['id'],
                                      'revision': item['revision'],
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Vaciar comprados'),
                ),
              if (repo.pending)
                TextButton(
                  onPressed: () async {
                    if (await _confirm(
                          context,
                          '¿Descartar explícitamente todos los cambios pendientes? Las operaciones ya aceptadas por el servidor se conservarán.',
                        ) &&
                        context.mounted) {
                      await _run(context, repo.discardPending);
                    }
                  },
                  child: const Text('Descartar pendientes'),
                ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _run(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo guardar. Revisa los valores, la sesión o el límite de pendientes.',
          ),
        ),
      );
    }
  }
}

Future<bool> _confirm(BuildContext context, String text) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;
Future<void> editShopping(
  BuildContext context, {
  Map<String, dynamic>? item,
}) async {
  final name = TextEditingController(text: item?['name']);
  final quantity = TextEditingController(text: item?['quantity']?.toString());
  final max = TextEditingController(text: item?['quantity_max']?.toString());
  final unit = TextEditingController(text: item?['unit']);
  final notes = TextEditingController(text: item?['notes']);
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(item == null ? 'Añadir producto' : 'Editar producto'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Producto (incluye forma y estado)',
              ),
            ),
            TextField(
              controller: quantity,
              decoration: const InputDecoration(labelText: 'Cantidad opcional'),
            ),
            TextField(
              controller: max,
              decoration: const InputDecoration(
                labelText: 'Máximo del rango opcional',
              ),
            ),
            TextField(
              controller: unit,
              decoration: const InputDecoration(labelText: 'Unidad opcional'),
            ),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notas'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty ||
                (quantity.text.isNotEmpty &&
                    knownNumber(quantity.text) == null) ||
                (max.text.isNotEmpty &&
                    (knownNumber(max.text) == null ||
                        knownNumber(quantity.text) == null ||
                        knownNumber(max.text)! <
                            knownNumber(quantity.text)!))) {
              return;
            }
            Navigator.pop(c, {
              'name': name.text.trim(),
              'quantity': knownNumber(quantity.text),
              'quantity_max': knownNumber(max.text),
              'unit': unit.text.trim().isEmpty ? null : unit.text.trim(),
              'notes': notes.text.trim(),
              if (item == null) 'raw_text': name.text,
              if (item != null) 'id': item['id'],
              if (item != null) 'revision': item['revision'],
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  if (result != null && context.mounted) {
    await _run(
      context,
      () => AppRepositories.shopping!.enqueue(
        item == null ? 'add' : 'edit',
        result,
      ),
    );
  }
  // Dialog routes may still animate; controllers are owned by this short-lived form.
}

Future<void> addRecipeShopping(BuildContext context, Recipe recipe) async {
  final repo = AppRepositories.shopping;
  if (repo == null || repo.owner == null) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShoppingScreen()),
    );
    return;
  }
  final ingredients =
      (recipe.cloudDraft?['ingredients'] as List? ??
              recipe.ingredients
                  .map((s) => {'name': s, 'raw_text': s})
                  .toList())
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  final selected = List.filled(ingredients.length, true);
  final base = knownNumber(recipe.cloudDraft?['servings']);
  final portions = TextEditingController(text: base?.toString() ?? '1');
  final quantities = ingredients
      .map((i) => TextEditingController(text: i['quantity']?.toString() ?? ''))
      .toList();
  final units = ingredients
      .map((i) => TextEditingController(text: i['unit']?.toString() ?? ''))
      .toList();
  final maxima = ingredients
      .map(
        (i) => TextEditingController(text: i['quantity_max']?.toString() ?? ''),
      )
      .toList();
  String? error;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: const Text('Añadir a la compra'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  base == null
                      ? 'Raciones desconocidas. ×1 conserva cantidades originales; elige un multiplicador explícito.'
                      : 'Receta base: ${humanQuantity(base)} raciones',
                ),
                TextField(
                  controller: portions,
                  decoration: InputDecoration(
                    labelText: base == null
                        ? 'Multiplicador explícito'
                        : 'Raciones deseadas',
                  ),
                ),
                for (var i = 0; i < ingredients.length; i++)
                  Row(
                    children: [
                      Checkbox(
                        value: selected[i],
                        onChanged: (v) => set(() => selected[i] = v!),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('${ingredients[i]['raw_text']}'),
                            TextField(
                              controller: quantities[i],
                              decoration: const InputDecoration(
                                labelText: 'Cantidad base opcional',
                              ),
                            ),
                            TextField(
                              controller: maxima[i],
                              decoration: const InputDecoration(
                                labelText: 'Máximo base opcional',
                              ),
                            ),
                            TextField(
                              controller: units[i],
                              decoration: const InputDecoration(
                                labelText: 'Unidad opcional (g, kg, ml, lata…)',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (error != null) Text(error!),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (knownNumber(portions.text) == null ||
                  quantities.any(
                    (q) => q.text.isNotEmpty && knownNumber(q.text) == null,
                  ) ||
                  List.generate(
                    ingredients.length,
                    (i) =>
                        maxima[i].text.isNotEmpty &&
                        (knownNumber(maxima[i].text) == null ||
                            (knownNumber(quantities[i].text) != null &&
                                knownNumber(maxima[i].text)! <
                                    knownNumber(quantities[i].text)!)),
                  ).any((invalid) => invalid)) {
                set(
                  () => error =
                      'Usa cantidades positivas; deja desconocidos vacíos.',
                );
                return;
              }
              Navigator.pop(c, true);
            },
            child: const Text('Añadir seleccionados'),
          ),
        ],
      ),
    ),
  );
  if (accepted != true || !context.mounted) return;
  final factor = scaleFactor(
    base: base,
    desired: base == null ? null : portions.text,
    multiplier: base == null ? knownNumber(portions.text) : null,
  );
  final operations = <(String, Map<String, dynamic>)>[];
  for (var i = 0; i < ingredients.length; i++) {
    if (selected[i]) {
      final source = {
        ...ingredients[i],
        'quantity': knownNumber(quantities[i].text),
        'quantity_max': knownNumber(maxima[i].text),
        'unit': units[i].text.trim().isEmpty ? null : units[i].text.trim(),
      };
      operations.add((
        'add',
        {
          ...scaledIngredient(source, factor),
          'recipe_id': recipe.id,
          'ingredient_position': ingredients[i]['position'],
          'notes': 'Factor explícito: $factor',
        },
      ));
    }
  }
  try {
    await repo.enqueueBatch(operations);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se añadió la selección. Revisa el límite de 200 pendientes y las cantidades.',
          ),
        ),
      );
    }
    return;
  }
  if (context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShoppingScreen()),
    );
  }
}
