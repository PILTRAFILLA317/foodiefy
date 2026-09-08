class Recipe {
  final String? ownerId;
  final int? revision;
  final Map<String, dynamic>? cloudDraft;
  final String id;
  final String title;
  final String? description;
  final List<String> ingredients;
  final List<String> steps;
  final String? imagePath;
  final String? originalVideoUrl;
  final String? sourceUrl;
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
    this.ownerId,
    this.revision,
    this.cloudDraft,
    required this.id,
    required this.title,
    this.description,
    required this.ingredients,
    required this.steps,
    this.imagePath,
    this.originalVideoUrl,
    this.sourceUrl,
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
      'sourceUrl': sourceUrl,
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
      sourceUrl: json['sourceUrl'],
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
      // print(finalQuantity);
      return finalQuantity!;
    }
    // print(finalQuantity);
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

  final double? totalKcal;
  final double? carbsGrams;
  final double? proteinGrams;
  final double? fatGrams;
  final double? carbsPercentage;
  final double? proteinPercentage;
  final double? fatPercentage;

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
      totalKcal: parseValue(json['kcal_totales']),
      carbsGrams: parseValue(json['carbohidratos_gramos']),
      proteinGrams: parseValue(json['proteinas_gramos']),
      fatGrams: parseValue(json['grasas_gramos']),
      carbsPercentage: parseValue(json['carbohidratos_porcentaje']),
      proteinPercentage: parseValue(json['proteinas_porcentaje']),
      fatPercentage: parseValue(json['grasas_porcentaje']),
    );
  }

  /// Unknown and invalid input stays unavailable; never invent or round nutrition.
  static double? parseValue(dynamic value) {
    final double? parsed = value is num
        ? value.toDouble()
        : value is String
        ? double.tryParse(value.trim().replaceAll(',', '.'))
        : null;
    return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
  }

  bool get hasAnyValue => totalKcal != null || hasGramValues || hasPercentages;

  bool get hasPercentages =>
      carbsPercentage != null ||
      proteinPercentage != null ||
      fatPercentage != null;

  bool get hasGramValues =>
      carbsGrams != null || proteinGrams != null || fatGrams != null;
}
