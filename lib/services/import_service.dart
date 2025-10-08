import 'dart:math';

import '../models/recipe.dart';

class ImportRecipeService {
  ImportRecipeService({Random? random}) : _random = random ?? Random();

  final Random _random;

  Future<Recipe> importRecipeFromUrl(String url) async {
    await Future.delayed(const Duration(seconds: 1));

    final sample = _mockRecipes[_random.nextInt(_mockRecipes.length)];

    final json = sample.toJson()
      ..addAll({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'isPublic': false,
        'isImported': true,
        'createdAt': DateTime.now().toIso8601String(),
      });

    return Recipe.fromJson(json);
  }
}

class _MockRecipe {
  const _MockRecipe({
    required this.title,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.imageUrl,
    required this.prepTimeMinutes,
  });

  final String title;
  final String description;
  final List<String> ingredients;
  final List<String> steps;
  final String imageUrl;
  final int prepTimeMinutes;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'steps': steps,
      'imagePath': imageUrl,
      'originalVideoUrl': null,
      'prepTimeMinutes': prepTimeMinutes,
    };
  }
}

const List<_MockRecipe> _mockRecipes = [
  _MockRecipe(
    title: 'Tacos de birria caseros',
    description:
        'Tacos jugosos con tortilla doradita, queso fundido y un consomé lleno de sabor.',
    ingredients: [
      '800 g de carne de res (falda o chambarete)',
      '6 chiles guajillos hidratados',
      '2 dientes de ajo',
      '1/2 cebolla blanca',
      '1 cucharadita de comino',
      '1 taza de queso Oaxaca deshebrado',
      '12 tortillas de maíz',
      'Limón y cilantro picado al gusto',
    ],
    steps: [
      'Licúa los chiles con ajo, cebolla y comino. Marina la carne al menos 2 horas.',
      'Cocina la carne a fuego lento hasta que esté muy suave y deshebra.',
      'Calienta el consomé y reserva.',
      'Sumerge tortillas en el consomé, rellena con carne y queso, y dora en plancha.',
      'Sirve con cilantro, limón y consomé para acompañar.',
    ],
    imageUrl:
        'https://images.unsplash.com/photo-1608039858788-2a7e3f9ca0b1?auto=format&fit=crop&w=1200&q=80',
    prepTimeMinutes: 90,
  ),
  _MockRecipe(
    title: 'Pasta cremosa de pistacho',
    description:
        'Una pasta al dente con salsa cremosa de pistacho y limón para sorprender a tus invitados.',
    ingredients: [
      '320 g de pasta corta',
      '120 g de pistachos sin cáscara',
      '1 diente de ajo',
      '80 ml de aceite de oliva',
      '100 g de queso parmesano rallado',
      'Jugo y ralladura de 1 limón',
      'Sal y pimienta al gusto',
    ],
    steps: [
      'Tosta ligeramente los pistachos en una sartén.',
      'Procesa pistachos, ajo, aceite, parmesano y limón hasta obtener una pasta suave.',
      'Cuece la pasta en agua con sal hasta que esté al dente.',
      'Reserva un poco de agua de cocción y mezcla con la salsa de pistacho.',
      'Combina la pasta con la salsa y ajusta de sal, pimienta y limón.',
    ],
    imageUrl:
        'https://images.unsplash.com/photo-1525755662778-989d0524087e?auto=format&fit=crop&w=1200&q=80',
    prepTimeMinutes: 25,
  ),
  _MockRecipe(
    title: 'Cheesecake de frutos rojos sin horno',
    description:
        'Postre cremoso, fresco y sin horno que combina queso crema con frutos rojos.',
    ingredients: [
      '200 g de galletas tipo María',
      '90 g de mantequilla derretida',
      '400 g de queso crema',
      '200 ml de crema para batir',
      '100 g de azúcar glas',
      '1 cucharadita de esencia de vainilla',
      '250 g de frutos rojos frescos',
    ],
    steps: [
      'Tritura las galletas y mézclalas con la mantequilla. Presiona en un molde y enfría.',
      'Bate el queso crema con azúcar glas y vainilla hasta esponjar.',
      'Integra la crema batida y vierte sobre la base fría.',
      'Refrigera al menos 4 horas hasta que cuaje.',
      'Decora con frutos rojos antes de servir.',
    ],
    imageUrl:
        'https://images.unsplash.com/photo-1505253716362-afaea1d3d1eb?auto=format&fit=crop&w=1200&q=80',
    prepTimeMinutes: 30,
  ),
];
