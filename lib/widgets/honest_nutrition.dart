import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../shopping/quantities.dart';

class HonestNutrition extends StatefulWidget {
  const HonestNutrition({super.key, required this.recipe});
  final Recipe recipe;
  @override
  State<HonestNutrition> createState() => _HonestNutritionState();
}

class _HonestNutritionState extends State<HonestNutrition> {
  String? target;
  static const bases = {
    'whole_recipe': 'Receta completa',
    'per_serving': 'Por ración',
    'per_100g': 'Por 100 g',
  };
  @override
  Widget build(BuildContext context) {
    final n = widget.recipe.cloudDraft?['nutrition'] as Map<String, dynamic>?;
    if (n == null || n['status'] == 'unavailable') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nutrición no disponible'),
          const Text(
            'Si editaste ingredientes, la estimación anterior ya no es válida.',
          ),
          _recalculation(context),
        ],
      );
    }
    final basis = target ?? n['basis'] as String;
    final factor = nutritionFactor(
      n,
      basis,
      servings: widget.recipe.cloudDraft?['servings'],
    );
    final method =
        {
          'manual': 'Datos manuales',
          'source_label': 'Etiqueta de la fuente',
          'calculated': 'Cálculo por ingredientes',
          'ai_estimate': 'Estimación mediante IA',
        }[n['method']] ??
        'Fuente desconocida';
    final estimated = ['ai_estimate', 'calculated'].contains(n['method']);
    final macros = [
      'carbs_g',
      'protein_g',
      'fat_g',
    ].map((k) => double.tryParse('${n[k]}')).toList();
    final energy = macros.every((v) => v != null)
        ? macros[0]! * 4 + macros[1]! * 4 + macros[2]! * 9
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nutrición', style: Theme.of(context).textTheme.titleLarge),
        if (estimated) const Chip(label: Text('Estimación')),
        Text('$method · Base original: ${bases[n['basis']]}'),
        for (final assumption in n['assumptions'] as List? ?? [])
          Text('$assumption'),
        DropdownButton<String>(
          value: basis,
          items: bases.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => target = v),
        ),
        if (factor == null)
          const Text(
            'Conversión no disponible: faltan raciones o masa conocida.',
          )
        else
          ...['kcal', 'protein_g', 'carbs_g', 'fat_g'].map((key) {
            final value = double.tryParse('${n[key]}');
            return Text(
              '${{'kcal': 'Energía (kcal)', 'protein_g': 'Proteínas (g)', 'carbs_g': 'Carbohidratos (g)', 'fat_g': 'Grasas (g)'}[key]}: ${value == null ? '—' : humanQuantity(value * factor)}',
            );
          }),
        if (energy != null && energy > 0)
          Text(
            'Reparto energético aproximado: carbohidratos ${(macros[0]! * 4 / energy * 100).toStringAsFixed(1)} %, proteínas ${(macros[1]! * 4 / energy * 100).toStringAsFixed(1)} %, grasas ${(macros[2]! * 9 / energy * 100).toStringAsFixed(1)} %. Factores 4/4/9 kcal/g; puede diferir de las kcal declaradas por fibra y redondeo.',
          ),
        const Text(
          'Cambiar la base solo aplica aritmética. No solicita un nuevo cálculo IA.',
        ),
        _recalculation(context),
      ],
    );
  }

  Widget _recalculation(BuildContext context) => TextButton(
    onPressed: () => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Recálculo no disponible'),
        content: const Text(
          'No hay un proveedor nutricional ni una cuota de recálculo configurados. No se ha enviado una solicitud IA ni generado coste. Puedes introducir datos manuales o de etiqueta al editar la receta. La extracción de recetas no estima nutrición.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Entendido'),
          ),
        ],
      ),
    ),
    child: const Text('Solicitar recálculo · no habilitado'),
  );
}
