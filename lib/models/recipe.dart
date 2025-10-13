class Recipe {
  final String id;
  final String title;
  final String? description;
  final List<String> ingredients;
  final List<String> steps;
  final String? imagePath;
  final String? originalVideoUrl;
  final bool isPublic;
  final bool isImported;
  final int? prepTimeMinutes;
  final String? prepTimeText;
  final String? uploader;
  final String? platform;
  final String? thumbnailUrl;
  final String? finalQuantity;
  final RecipeMacronutrients? macronutrients;
  final DateTime createdAt;

  Recipe({
    required this.id,
    required this.title,
    this.description,
    required this.ingredients,
    required this.steps,
    this.imagePath,
    this.originalVideoUrl,
    this.isPublic = false,
    this.isImported = false,
    this.prepTimeMinutes,
    this.prepTimeText,
    this.uploader,
    this.platform,
    this.thumbnailUrl,
    this.finalQuantity,
    this.macronutrients,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'ingredients': ingredients,
      'steps': steps,
      'imagePath': imagePath,
      'originalVideoUrl': originalVideoUrl,
      'isPublic': isPublic,
      'isImported': isImported,
      'prepTimeMinutes': prepTimeMinutes,
      'prepTimeText': prepTimeText,
      'uploader': uploader,
      'platform': platform,
      'thumbnailUrl': thumbnailUrl,
      'finalQuantity': finalQuantity,
      'macronutrients': macronutrients?.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      ingredients: List<String>.from(json['ingredients']),
      steps: List<String>.from(json['steps']),
      imagePath: json['imagePath'],
      originalVideoUrl: json['originalVideoUrl'],
      isPublic: json['isPublic'] ?? false,
      isImported: json['isImported'] ?? false,
      prepTimeMinutes: json['prepTimeMinutes'],
      prepTimeText: json['prepTimeText'],
      uploader: json['uploader'],
      platform: json['platform'],
      thumbnailUrl: json['thumbnailUrl'],
      finalQuantity: json['finalQuantity'],
      macronutrients: json['macronutrients'] != null
          ? RecipeMacronutrients.fromJson(
              Map<String, dynamic>.from(json['macronutrients']),
            )
          : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  String get formattedPrepTime {
    if (prepTimeText != null && prepTimeText!.trim().isNotEmpty) {
      return prepTimeText!;
    }
    if (prepTimeMinutes == null) return 'No especificado';
    if (prepTimeMinutes! < 60) return '$prepTimeMinutes min';
    final hours = prepTimeMinutes! ~/ 60;
    final minutes = prepTimeMinutes! % 60;
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}min';
  }

  String get formattedFinalQuantity {
    if (finalQuantity != null && finalQuantity!.trim().isNotEmpty) {
      print(finalQuantity);
      return finalQuantity!;
    }
    print(finalQuantity);
    return 'No especificado';
  }
}

class RecipeMacronutrients {
  const RecipeMacronutrients({
    this.totalKcal,
    this.carbsGrams,
    this.proteinGrams,
    this.fatGrams,
    this.carbsPercentage,
    this.proteinPercentage,
    this.fatPercentage,
  });

  final int? totalKcal;
  final int? carbsGrams;
  final int? proteinGrams;
  final int? fatGrams;
  final int? carbsPercentage;
  final int? proteinPercentage;
  final int? fatPercentage;

  Map<String, dynamic> toJson() {
    return {
      'kcal_totales': totalKcal,
      'carbohidratos_gramos': carbsGrams,
      'proteinas_gramos': proteinGrams,
      'grasas_gramos': fatGrams,
      'carbohidratos_porcentaje': carbsPercentage,
      'proteinas_porcentaje': proteinPercentage,
      'grasas_porcentaje': fatPercentage,
    };
  }

  factory RecipeMacronutrients.fromJson(Map<String, dynamic> json) {
    return RecipeMacronutrients(
      totalKcal: _asInt(json['kcal_totales']),
      carbsGrams: _asInt(json['carbohidratos_gramos']),
      proteinGrams: _asInt(json['proteinas_gramos']),
      fatGrams: _asInt(json['grasas_gramos']),
      carbsPercentage: _asInt(json['carbohidratos_porcentaje']),
      proteinPercentage: _asInt(json['proteinas_porcentaje']),
      fatPercentage: _asInt(json['grasas_porcentaje']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool get hasPercentages =>
      carbsPercentage != null ||
      proteinPercentage != null ||
      fatPercentage != null;

  bool get hasGramValues =>
      carbsGrams != null || proteinGrams != null || fatGrams != null;
}
