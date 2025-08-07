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
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  String get formattedPrepTime {
    if (prepTimeMinutes == null) return 'No especificado';
    if (prepTimeMinutes! < 60) return '$prepTimeMinutes min';
    final hours = prepTimeMinutes! ~/ 60;
    final minutes = prepTimeMinutes! % 60;
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}min';
  }
}