import 'package:flutter/material.dart';
import 'dart:io';
import '../models/collection.dart';
import '../models/recipe.dart';
import 'package:foodiefy/widgets/recipe_card.dart';
import 'package:foodiefy/screens/recipe_detail_screen.dart';

class CollectionDetailScreen extends StatelessWidget {
  final RecipeCollection recipeCollection;

  CollectionDetailScreen({super.key, required this.recipeCollection});

  var testRecipe = Recipe(
    id: '1',
    title: 'Test Recipe',
    imagePath: 'https://i.ytimg.com/vi/WcsQPkBPiDw/maxresdefault.jpg',
    ingredients: ['Ingredient 1', 'Ingredient 2'],
    steps: ['Step 1', 'Step 2', 'Step 3', 'Step 4', 'Step 5', 'Step 6'],
    createdAt: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          recipeCollection.name,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.share),
          //   // onPressed: () => _shareRecipe(context),
          //   onPressed: () {
          //     // Implement share functionality
          //     print('Share button pressed');
          //   },
          // ),
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
                hintText: 'Search in ${recipeCollection.name}...',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // _buildStatsRow(),
                  // const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      // itemCount: recipes.length,
                      itemCount: recipeCollection.recipeIds.length,
                      itemBuilder: (context, index) {
                        return RecipeCard(
                          // recipe: recipes[index],
                          recipe: testRecipe,
                          // onTap: () => _openRecipeDetail(recipes[index]),
                          onTap: () {
                            // Implement recipe detail navigation
                            // print(
                            //   'Recipe tapped: ${recipeCollection.recipeIds[index]}',
                            // );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    RecipeDetailScreen(recipe: testRecipe),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
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
        onPressed: () {
          print('Add Recipe button pressed');
        },
        tooltip: 'Add Recipe',
        label: const Icon(Icons.add, color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
      ),
    );
  }
}
