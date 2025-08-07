import 'package:flutter/material.dart';
import 'package:foodiefy/models/recipe.dart';
import 'package:foodiefy/models/collection.dart';
// import 'package:foodiefy/models/collection_service.dart';

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
  // final CollectionService _collectionService = CollectionService();
  List<Recipe> _recipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    // super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    try {
      print('Loading recipes for collection: ${widget.collection.name}');
      // final recipes = await _collectionService
      //     .getRecipesByIds(widget.collection.recipeIds);
      final recipes = List.generate(
        widget.collection.recipeIds.length,
        (index) => Recipe(
          id: widget.collection.recipeIds[index],
          title: 'Recipe ${widget.collection.recipeIds[index]}',
          imagePath: 'https://picsum.photos/200/300?random=${index + 1}',
          ingredients: [],
          steps: [],
          createdAt: DateTime.now(),
        ),
      );
      setState(() {
        _recipes = recipes.take(2).toList();
        _isLoading = false;
      });
    } catch (e) {
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
          // borderRadius: BorderRadius.circular(0),
          color: Colors.transparent,
          // boxShadow: [
          //   BoxShadow(
          //     color: Colors.black.withOpacity(0.1),
          //     blurRadius: 8,
          //     offset: const Offset(0, 2),
          //   ),
          // ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _buildImageGrid(),
            ),
            Expanded(
              flex: 1,
              child: _buildCollectionInfo(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    if (_isLoading) {
      return Container(
        decoration: const BoxDecoration(
          // borderRadius: BorderRadius.all(Radius.circular(0)),
          color: Colors.grey,
        ),
        child: const Center(child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 6,
        )),
      );
    }

    if (_recipes.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          // borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          color: Colors.grey[200],
        ),
        child: const Center(
          child: Icon(
            Icons.restaurant_menu,
            size: 40,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        // borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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
                    child: Icon(Icons.restaurant_menu,
                        size: 20, color: Colors.grey),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${widget.collection.recipeIds.length} recipes',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              title: const Text('Delete Collection',
                  style: TextStyle(color: Colors.red)),
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