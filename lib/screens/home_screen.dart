import 'package:flutter/material.dart';
import 'package:foodiefy/models/recipe.dart';
import 'package:foodiefy/models/collection.dart';
import 'package:foodiefy/widgets/collection_card.dart';
import 'package:foodiefy/widgets/collection_creation_dialog.dart';

import 'package:foodiefy/screens/collection_detail_screen.dart';
import 'package:foodiefy/screens/create_recipe_screen.dart';
import 'package:foodiefy/services/collection_service.dart';
import 'package:foodiefy/services/storage_service.dart'; // Asegúrate de importar

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<RecipeCollection> _collections = [];
  List<Recipe> _allRecipes = [];

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
    });
  }

  Future<void> _loadAllRecipes() async {
    final recipes = await StorageService.getRecipes();
    setState(() {
      _allRecipes = recipes;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Foodiefy'),
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
              print('person button pressed');
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
                // Implement search logic here
                print('Search: $value');
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
                    _collections.length + 1, // +1 for "Todas las recetas"
                itemBuilder: (context, index) {
                  if (index == 0) {
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
                  final collection = _collections[index - 1];
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
                      _loadCollections();
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
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateRecipeScreen()),
          );
          if (result == true) {
            _loadCollections();
            _loadAllRecipes();
          }
        },
        tooltip: 'Add Recipe',
        label: const Icon(Icons.add, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
      ),
    );
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
