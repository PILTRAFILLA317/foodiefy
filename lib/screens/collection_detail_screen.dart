import 'package:flutter/material.dart';
import '../models/collection.dart';
import '../models/recipe.dart';
import 'package:foodiefy/widgets/recipe_card.dart';
import 'package:foodiefy/screens/recipe_detail_screen.dart';
import 'package:foodiefy/services/storage_service.dart';
import 'package:foodiefy/services/collection_service.dart';
import 'package:foodiefy/services/recipe_service.dart';

class CollectionDetailScreen extends StatefulWidget {
  final RecipeCollection recipeCollection;

  const CollectionDetailScreen({super.key, required this.recipeCollection});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Recipe> _recipes = [];
  List<Recipe> _filteredRecipes = [];
  bool _isLoading = true;
  Map<String, Recipe> _recipeLookup = {};
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _loadRecipes();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    try {
      final allRecipes = await StorageService.getRecipes();
      final recipeLookup = {
        for (final recipe in allRecipes) recipe.id: recipe,
      };
      List<String> activeRecipeIds;
      if (widget.recipeCollection.isMaster) {
        activeRecipeIds = allRecipes.map((recipe) => recipe.id).toList();
      } else {
        final collections = await CollectionService().getCollections();
        final latestCollection = collections.firstWhere(
          (collection) => collection.id == widget.recipeCollection.id,
          orElse: () => widget.recipeCollection,
        );
        activeRecipeIds = List<String>.from(latestCollection.recipeIds);

        // Mantén sincronizado el objeto recibido con los datos persistidos.
        widget.recipeCollection.recipeIds
          ..clear()
          ..addAll(activeRecipeIds);
      }

      final recipes = widget.recipeCollection.isMaster
          ? allRecipes
          : allRecipes
              .where((recipe) => activeRecipeIds.contains(recipe.id))
              .toList();

      if (!mounted) return;
      final filtered = _filterRecipes(recipes, _searchController.text);
      setState(() {
        _recipeLookup = recipeLookup;
        _recipes = recipes;
        _filteredRecipes = filtered;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recipes = [];
        _filteredRecipes = [];
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    if (!_isLoading) {
      final filtered = _filterRecipes(_recipes, _searchController.text);
      setState(() {
        _filteredRecipes = filtered;
      });
    }
  }

  List<Recipe> _filterRecipes(List<Recipe> source, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return List<Recipe>.from(source);
    }
    return source
        .where((recipe) => recipe.title.toLowerCase().contains(normalized))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _hasChanges);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context, _hasChanges),
          ),
          title: Text(
            widget.recipeCollection.name,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          actions: const [],
        ),
        backgroundColor: Colors.white,
        body: Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                cursorColor: Colors.black,
                decoration: InputDecoration(
                  fillColor: Colors.grey[300],
                  filled: true,
                  hintText: 'Buscar en ${widget.recipeCollection.name}...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredRecipes.isEmpty
                        ? _buildEmptyState()
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _filteredRecipes.length,
                            itemBuilder: (context, index) {
                              final recipe = _filteredRecipes[index];
                              return RecipeCard(
                                recipe: recipe,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RecipeDetailScreen(recipe: recipe),
                                    ),
                                  );
                                },
                                onLongPress: () {
                                  _openCollectionSelectionSheet(recipe);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        floatingActionButton: _buildFloatingActionButtons(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            widget.recipeCollection.isMaster
                ? 'No hay recetas guardadas todavía.'
                : 'Esta colección aún no tiene recetas.',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _openCollectionSelectionSheet(Recipe recipe) async {
    final service = CollectionService();
    final allCollections = await service.getCollections();
    if (!mounted) return;

    final collections = allCollections
        .where((collection) => !collection.isMaster)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (collections.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Guardar en colecciones'),
          content:
              const Text('Crea una colección para poder guardar la receta.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      return;
    }

    if (_recipeLookup.isEmpty) {
      final allRecipes = await StorageService.getRecipes();
      if (!mounted) return;
      _recipeLookup = {
        for (final r in allRecipes) r.id: r,
      };
    }

    final Map<String, bool> selections = {
      for (final collection in collections)
        collection.id: collection.recipeIds.contains(recipe.id),
    };

    final shouldPersist = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 16 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Guardar en colecciones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          icon: const Icon(Icons.close, color: Colors.black),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(sheetContext).size.height * 0.6,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: collections.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final collection = collections[index];
                          final isSelected = selections[collection.id] ?? false;
                          final previewRecipe = _findFirstRecipeInCollection(collection);

                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                selections[collection.id] = !isSelected;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFF2F2F2)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF040406)
                                      : Colors.grey.shade300,
                                ),
                                boxShadow: [
                                  if (isSelected)
                                    BoxShadow(
                                      color: const Color(0x0D000000),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  _buildCollectionThumbnail(previewRecipe),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      collection.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle
                                        : Icons.add_circle_outline,
                                    color: isSelected
                                        ? const Color(0xFF040406)
                                        : Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (!mounted) return;
                          final navigator = Navigator.of(sheetContext);
                          final shouldDelete = await showDialog<bool>(
                            context: sheetContext,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Eliminar receta'),
                              content: Text(
                                '¿Eliminar "${recipe.title}" de todas tus colecciones? Esta acción no se puede deshacer.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );

                          if (shouldDelete == true) {
                            if (!navigator.mounted) return;
                            navigator.pop(false);
                            if (!mounted) return;
                            await _deleteRecipeEverywhere(recipe);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Eliminar receta de todas las colecciones'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF040406),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (shouldPersist != true || !mounted) {
      return;
    }

    setState(() => _isLoading = true);

    final futures = <Future<void>>[];
    for (final collection in collections) {
      final shouldContain = selections[collection.id] ?? false;
      final currentlyContains = collection.recipeIds.contains(recipe.id);

      if (shouldContain && !currentlyContains) {
        futures.add(service.addRecipeToCollection(collection.id, recipe.id));
      } else if (!shouldContain && currentlyContains) {
        futures.add(
          service.removeRecipeFromCollection(collection.id, recipe.id),
        );
      }
    }

    final hasChanges = futures.isNotEmpty;

    try {
      if (hasChanges) {
        await Future.wait(futures);
        _hasChanges = true;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('No se pudieron guardar los cambios. Intenta de nuevo.'),
          ),
        );
      }
    }

    if (hasChanges) {
      final currentSelection = selections[widget.recipeCollection.id];
      if (currentSelection != null) {
        if (currentSelection) {
          if (!widget.recipeCollection.recipeIds.contains(recipe.id)) {
            widget.recipeCollection.recipeIds.add(recipe.id);
          }
        } else {
          widget.recipeCollection.recipeIds.remove(recipe.id);
        }
      }
    }

    if (mounted) {
      await _loadRecipes();
    }
  }

  Recipe? _findFirstRecipeInCollection(RecipeCollection collection) {
    for (final recipeId in collection.recipeIds) {
      final recipe = _recipeLookup[recipeId];
      if (recipe != null) {
        return recipe;
      }
    }
    return null;
  }

  Widget _buildCollectionThumbnail(Recipe? recipe) {
    const double size = 48;
    final imagePath = recipe?.imagePath;

    Widget buildPlaceholder() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.restaurant_menu,
          color: Colors.grey,
          size: 20,
        ),
      );
    }

    if (imagePath != null && imagePath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imagePath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => buildPlaceholder(),
        ),
      );
    }

    return buildPlaceholder();
  }

  Future<void> _deleteRecipeEverywhere(Recipe recipe) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    final service = CollectionService();
    final collections = await service.getCollections();

    final futures = <Future<void>>[];
    for (final collection in collections) {
      if (collection.recipeIds.contains(recipe.id)) {
        futures.add(service.removeRecipeFromCollection(collection.id, recipe.id));
      }
    }

    futures.add(RecipeService.deleteRecipe(recipe.id));

    try {
      await Future.wait(futures);
      _hasChanges = true;
      _recipeLookup.remove(recipe.id);
      _recipes.removeWhere((r) => r.id == recipe.id);
      _filteredRecipes.removeWhere((r) => r.id == recipe.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${recipe.title}" se eliminó correctamente.'),
        ),
      );
      if (mounted) {
        await _loadRecipes();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo eliminar la receta. Intenta de nuevo.'),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildFloatingActionButtons() {
    return SizedBox(
      width: 100,
      child: FloatingActionButton.extended(
        backgroundColor: const Color.fromARGB(255, 4, 4, 6),
        onPressed: () {
          // TODO: conectar con flujo de agregar receta a la colección
        },
        tooltip: 'Agregar receta',
        label: const Icon(Icons.add, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
      ),
    );
  }
}
