double? knownNumber(dynamic value) {
  final text = '$value'.trim().replaceAll(',', '.');
  final parts = text.split('/');
  final n = parts.length == 2
      ? (double.tryParse(parts[0]) ?? double.nan) /
            (double.tryParse(parts[1]) ?? double.nan)
      : double.tryParse(text);
  return n != null && n.isFinite && n > 0 && n < 1e12 ? n : null;
}

double scaleFactor({dynamic base, dynamic desired, double? multiplier}) {
  final b = knownNumber(base), d = knownNumber(desired);
  if (b != null && d != null) return d / b;
  if (multiplier != null && multiplier.isFinite && multiplier > 0) {
    return multiplier;
  }
  if (desired != null) {
    throw ArgumentError(
      'Raciones base desconocidas; usa multiplicador explícito.',
    );
  }
  return 1;
}

String humanQuantity(dynamic value) {
  final n = double.tryParse('$value');
  if (n == null) return '—';
  if (n != 0 && n.abs() < 0.000001) return n.toString();
  return n.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
}

Map<String, dynamic> scaledIngredient(
  Map<String, dynamic> ingredient,
  double factor,
) => {
  'name': ingredient['name'],
  'raw_text': ingredient['raw_text'],
  'quantity': knownNumber(ingredient['quantity']) == null
      ? null
      : knownNumber(ingredient['quantity'])! * factor,
  'quantity_max': knownNumber(ingredient['quantity_max']) == null
      ? null
      : knownNumber(ingredient['quantity_max'])! * factor,
  'unit': ingredient['unit'],
  'preparation': ingredient['preparation'],
};

/// Future seam: verified ingredient data must include basis and provenance.
abstract interface class VerifiedIngredientNutrition {
  Future<Map<String, dynamic>?> lookup(String ingredientId);
}

double? nutritionFactor(
  Map<String, dynamic> n,
  String target, {
  dynamic servings,
}) {
  final basis = n['basis'];
  if (basis == target) return 1;
  final count = knownNumber(servings), mass = knownNumber(n['known_mass_g']);
  final whole = switch (basis) {
    'whole_recipe' => 1.0,
    'per_serving' => count,
    'per_100g' => mass == null ? null : mass / 100,
    _ => null,
  };
  if (whole == null) return null;
  return switch (target) {
    'whole_recipe' => whole,
    'per_serving' => count == null ? null : whole / count,
    'per_100g' => mass == null ? null : whole * 100 / mass,
    _ => null,
  };
}
