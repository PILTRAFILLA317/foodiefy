import 'package:flutter/material.dart';
import 'package:foodiefy/models/recipe.dart';
import 'package:foodiefy/models/collection.dart';
import 'package:foodiefy/widgets/collection_card.dart';
import 'package:foodiefy/widgets/collection_creation_dialog.dart';

import 'package:foodiefy/screens/collection_detail_screen.dart';
import 'package:foodiefy/screens/create_recipe_screen.dart';
import 'package:foodiefy/screens/import_recipe_screen.dart';
import 'package:foodiefy/services/collection_service.dart';
import 'package:foodiefy/services/storage_service.dart';

import 'user_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<RecipeCollection> _collections = [];
  List<Recipe> _allRecipes = [];
  List<RecipeCollection> _filteredCollections = [];
  String _collectionQuery = '';
  String assetName = 'assets/foodtext_svg.svg';

  @override
  void initState() {
    super.initState();
    _loadCollections();
    _loadAllRecipes();
  }

  Future<void> _loadCollections() async {
    final collections = await CollectionService().getCollections();
    setState(() {
      _collections = collections;
      _applyCollectionFilter();
    });
  }

  Future<void> _loadAllRecipes() async {
    final recipes = await StorageService.getRecipes();
    setState(() {
      _allRecipes = recipes;
      _applyCollectionFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'Foodiefy',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        // title: SvgPicture.asset(
        //   assetName,
        //   height: 28,
        //   colorFilter:
        //       const ColorFilter.mode(Colors.black, BlendMode.srcIn),
        // ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () {
              // print('add button pressed');
              _showCollectionCreationDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserScreen(savedRecipes: _allRecipes.length),
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
        child: Column(
          children: [
            TextField(
              cursorColor: Colors.black,
              decoration: InputDecoration(
                fillColor: Colors.grey[300],
                filled: true,
                hintText: 'Search collections...',
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
              onChanged: (value) {
                setState(() {
                  _collectionQuery = value;
                  _applyCollectionFilter();
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount:
                    _filteredCollections.length +
                    (_collectionQuery.trim().isEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  final showMasterCard = _collectionQuery.trim().isEmpty;
                  if (showMasterCard && index == 0) {
                    // "Todas las recetas" card
                    final allRecipesCollection = RecipeCollection(
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                      recipeIds: _allRecipes.map((r) => r.id).toList(),
                      id: '0',
                      name: 'Todas las recetas',
                      isMaster: true,
                    );
                    return CollectionCard(
                      collection: allRecipesCollection,
                      onTap: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CollectionDetailScreen(
                              recipeCollection: allRecipesCollection,
                            ),
                          ),
                        );
                        if (changed == true) {
                          await Future.wait([
                            _loadCollections(),
                            _loadAllRecipes(),
                          ]);
                        }
                      },
                      // No delete for this card
                      onDelete: () {},
                    );
                  }
                  // Other collections
                  final relativeIndex = index - (showMasterCard ? 1 : 0);
                  final collection = _filteredCollections[relativeIndex];
                  return CollectionCard(
                    collection: collection,
                    onTap: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CollectionDetailScreen(
                            recipeCollection: collection,
                          ),
                        ),
                      );
                      if (changed == true) {
                        await Future.wait([
                          _loadCollections(),
                          _loadAllRecipes(),
                        ]);
                      }
                    },
                    onDelete: () async {
                      await CollectionService().deleteCollection(collection);
                      await _loadCollections();
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
    );
  }

  Widget _buildFloatingActionButtons() {
    return SizedBox(
      width: 100, // Set your desired width here
      child: FloatingActionButton.extended(
        backgroundColor: const Color.fromARGB(255, 4, 4, 6),
        onPressed: _showAddRecipeOptions,
        tooltip: 'Add Recipe',
        label: const Icon(Icons.add, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
      ),
    );
  }

  Future<void> _showAddRecipeOptions() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Añadir receta',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildAddRecipeOption(
                  icon: Icons.edit,
                  title: 'Crear manualmente',
                  subtitle: 'Escribe ingredientes y pasos desde cero.',
                  onTap: () => Navigator.pop(context, 'manual'),
                ),
                const SizedBox(height: 12),
                _buildAddRecipeOption(
                  icon: Icons.link,
                  title: 'Importar desde enlace',
                  subtitle: 'Pega un link de tus redes y generamos la receta.',
                  onTap: () => Navigator.pop(context, 'import'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    if (result == 'manual') {
      await _navigateToCreateRecipe();
    } else if (result == 'import') {
      final importedRecipe = await Navigator.push<Recipe?>(
        context,
        MaterialPageRoute(builder: (_) => const ImportRecipeScreen()),
      );
      if (importedRecipe != null) {
        await _onRecipeCreated(importedRecipe);
      }
    }
  }

  Widget _buildAddRecipeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToCreateRecipe({Recipe? template}) async {
    final recipe = await Navigator.push<Recipe?>(
      context,
      MaterialPageRoute(builder: (_) => CreateRecipeScreen(template: template)),
    );
    if (recipe != null) {
      await _onRecipeCreated(recipe);
    }
  }

  Future<void> _onRecipeCreated(Recipe recipe) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${recipe.title}" se guardó en tus recetas.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    await Future.wait([_loadCollections(), _loadAllRecipes()]);
    if (_collectionQuery.isNotEmpty) {
      setState(_applyCollectionFilter);
    }
  }

  void _applyCollectionFilter() {
    final query = _collectionQuery.trim().toLowerCase();
    final recipeLookup = {for (final recipe in _allRecipes) recipe.id: recipe};

    if (query.isEmpty) {
      _filteredCollections = _collections
          .where((collection) => !collection.isMaster)
          .toList();
      return;
    }

    _filteredCollections = _collections
        .where((collection) => !collection.isMaster)
        .where(
          (collection) =>
              collection.name.toLowerCase().contains(query) ||
              collection.recipeIds.any((id) {
                final recipe = recipeLookup[id];
                if (recipe == null) return false;
                return recipe.title.toLowerCase().contains(query);
              }),
        )
        .toList();
  }

  void _showCollectionCreationDialog() {
    showDialog(
      context: context,
      builder: (context) => CollectionCreationDialog(
        onImportSuccess: () {
          _loadCollections();
          // Navigator.pop(context);
        },
      ),
    );
  }
}
