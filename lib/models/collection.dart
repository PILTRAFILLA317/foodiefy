
class RecipeCollection {
  final String id;
  final String name;
  final String? description;
  final String? coverImagePath;
  final List<String> recipeIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isMaster;

  RecipeCollection({
    required this.id,
    required this.name,
    this.description,
    this.coverImagePath,
    required this.recipeIds,
    required this.createdAt,
    required this.updatedAt,
    required this.isMaster,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coverImagePath': coverImagePath,
      'recipeIds': recipeIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isMaster' : isMaster,
    };
  }

  factory RecipeCollection.fromJson(Map<String, dynamic> json) {
    return RecipeCollection(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      coverImagePath: json['coverImagePath'],
      recipeIds: List<String>.from(json['recipeIds']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isMaster: json['isMaster'] ?? false,
    );
  }
}