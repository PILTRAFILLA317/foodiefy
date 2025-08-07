import 'package:flutter/material.dart';
import 'dart:io';
import '../models/collection.dart';

class CollectionDetailScreen extends StatelessWidget {
  final RecipeCollection recipeCollection;

  const CollectionDetailScreen({super.key, required this.recipeCollection});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          recipeCollection.name,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: 10, // Replace with your collection count
                itemBuilder: (context, index) {
                  // return CollectionCard(
                  //   collection: RecipeCollection(
                  //     createdAt: DateTime.now(),
                  //     updatedAt: DateTime.now(),
                  //     id: 'collection_$index',
                  //     name: 'Collection $index',
                  //     recipeIds: List.generate(4, (i) => 'recipe_$i'),
                  //   ),
                  //   onTap: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder: (context) => CollectionDetailScreen(
                  //           recipeCollection: RecipeCollection(
                  //             createdAt: DateTime.now(),
                  //             updatedAt: DateTime.now(),
                  //             id: 'collection_$index',
                  //             name: 'Collection $index',
                  //             recipeIds: List.generate(4, (i) => 'recipe_$i'),
                  //           ),
                  //         ),
                  //       ),
                  //     );
                  //   },
                  //   onDelete: () {
                  //     print('Deleted Collection $index');
                  //   },
                  // );
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
