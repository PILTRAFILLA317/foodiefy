import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:foodiefy/models/recipe.dart';
import 'package:foodiefy/models/collection.dart';
import 'package:foodiefy/services/storage_service.dart';
import 'package:foodiefy/services/collection_service.dart';

class CollectionCard extends StatefulWidget {
  final RecipeCollection collection;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const CollectionCard({
    super.key,
    required this.collection,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<CollectionCard> {
  List<Recipe> _recipes = [];
  bool _isLoading = true;
  int _totalRecipes = 0;
  List<String> _lastRecipeIds = [];

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  @override
  void didUpdateWidget(covariant CollectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collection.id != widget.collection.id ||
        !listEquals(widget.collection.recipeIds, _lastRecipeIds)) {
      _loadRecipes();
    }
  }

  Future<void> _loadRecipes() async {
    try {
      final all = await StorageService.getRecipes();
      List<String> activeRecipeIds;
      if (widget.collection.isMaster) {
        activeRecipeIds = all.map((recipe) => recipe.id).toList();
      } else {
        final collections = await CollectionService().getCollections();
        final latest = collections.firstWhere(
          (collection) => collection.id == widget.collection.id,
          orElse: () => widget.collection,
        );
        activeRecipeIds = List<String>.from(latest.recipeIds);
        widget.collection.recipeIds
          ..clear()
          ..addAll(activeRecipeIds);
      }

      final recipes = widget.collection.isMaster
          ? all
          : all.where((r) => activeRecipeIds.contains(r.id)).toList();

      if (!mounted) return;
      setState(() {
        _totalRecipes = recipes.length;
        _recipes = recipes.take(4).toList();
        _isLoading = false;
        _lastRecipeIds = List<String>.from(activeRecipeIds);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: _showOptionsMenu,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildImageGrid()),
            Expanded(flex: 1, child: _buildCollectionInfo()),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          color: Colors.grey,
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 6),
        ),
      );
    }

    if (_recipes.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          color: Colors.grey[200],
        ),
        child: const Center(
          child: Icon(Icons.restaurant_menu, size: 40, color: Colors.grey),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: _recipes.length == 1
            ? _buildSingleImage(_recipes[0])
            : _buildMultipleImages(),
      ),
    );
  }

  Widget _buildSingleImage(Recipe recipe) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        image: recipe.imagePath != null
            ? DecorationImage(
                image: NetworkImage(recipe.imagePath!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: recipe.imagePath == null
          ? const Center(
              child: Icon(Icons.restaurant_menu, size: 40, color: Colors.grey),
            )
          : null,
    );
  }

  Widget _buildMultipleImages() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: 4,
      itemBuilder: (context, index) {
        if (index < _recipes.length) {
          final recipe = _recipes[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[300],
              image: recipe.imagePath != null
                  ? DecorationImage(
                      image: NetworkImage(recipe.imagePath!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: recipe.imagePath == null
                ? const Center(
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 20,
                      color: Colors.grey,
                    ),
                  )
                : null,
          );
        } else {
          return Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.add, size: 20, color: Colors.grey),
            ),
          );
        }
      },
    );
  }

  Widget _buildCollectionInfo() {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, right: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.collection.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '$_totalRecipes ${_totalRecipes == 1 ? 'receta' : 'recetas'}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu() {
    if (widget.collection.isMaster) {
      return;
    }
    showModalBottomSheet(
      backgroundColor: Colors.white,
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 15,
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Collection'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement edit functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Collection',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}
