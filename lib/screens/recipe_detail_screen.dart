import 'package:flutter/material.dart';
import 'dart:io';
import '../models/recipe.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:foodiefy/screens/step_detail_screen.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        // backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: CircleAvatar(
            backgroundColor: Colors.black,
            child: Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: CircleAvatar(
              backgroundColor: Colors.black,
              child: const Icon(color: Colors.white, Icons.share, size: 20),
            ),
            onPressed: () => _shareRecipe(context),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(),
                  const SizedBox(height: 18),
                  if (recipe.description != null) ...[
                    _buildDescriptionSection(),
                    const SizedBox(height: 16),
                  ],
                  _buildIngredientsSection(),
                  const SizedBox(height: 24),
                  _buildStepsSection(context),
                  const SizedBox(height: 16),
                  _buildMacronutrients(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final provider = _resolveImageProvider(recipe.imagePath);
    if (provider != null) {
      return SizedBox(
        height: 250,
        width: double.infinity,
        child: Image(
          image: provider,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
        ),
      );
    }
    return _buildPlaceholderImage();
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 250,
      width: double.infinity,
      color: Colors.grey[300],
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 64, color: Colors.grey),
          SizedBox(height: 8),
          Text('Sin imagen', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  ImageProvider<Object>? _resolveImageProvider(String? path) {
    if (path == null) return null;
    final trimmed = path.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }

    final filePath = trimmed.startsWith('file://')
        ? Uri.parse(trimmed).toFilePath()
        : trimmed;

    final file = File(filePath);
    if (!file.existsSync()) {
      return null;
    }

    return FileImage(file);
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe.isImported) ...[
              Row(
                children: [
                  const Icon(Icons.link, size: 16, color: Colors.black),
                  const SizedBox(width: 4),
                  const Text(
                    'Importada',
                    style: TextStyle(color: Colors.black, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            if (recipe.isPublic) ...[
              const Icon(Icons.public, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              const Text(
                'Pública',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ] else ...[
              Row(
                children: [
                  SvgPicture.asset(
                    width: 30,
                    height: 30,
                    'assets/instagram_icon.svg',
                    colorFilter: ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    semanticsLabel: 'Label',
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    // '@${recipe.author}',
                    '@juan_el_recetas',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Descripción',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(recipe.description!, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shopping_cart, size: 24, color: Colors.black),
            const SizedBox(width: 8),
            Text(
              'Ingredientes (${recipe.ingredients.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...recipe.ingredients.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStepsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.format_list_numbered_rounded,
              size: 24,
              color: Colors.black,
            ),
            const SizedBox(width: 8),
            Text(
              'Preparación (${recipe.steps.length} pasos)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...recipe.steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StepDetailScreen(
                    steps: recipe.steps,
                    initialIndex: index,
                  ),
                ),
              );
            },
            child: Card(
              color: Colors.grey[200],
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(fontSize: 16),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMacronutrients() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.pie_chart_rounded, size: 24, color: Colors.black),
            const SizedBox(width: 8),
            Text(
              'Macronutrientes',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        // const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '1234',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'kcal',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    PieChart(
                      PieChartData(
                        centerSpaceColor: Colors.transparent,
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 5,
                        centerSpaceRadius: 35,
                        startDegreeOffset: 180,
                        sections: [
                          PieChartSectionData(
                            // value: recipe.macronutrients['carbs'] ?? 0,
                            value: 12,
                            color: const Color.fromARGB(255, 82, 225, 211),
                            title: ' ',
                            radius: 15,
                          ),
                          PieChartSectionData(
                            // value: recipe.macronutrients['protein'] ?? 0,
                            value: 8,
                            color: const Color.fromARGB(255, 255, 168, 54),
                            title: ' ',
                            radius: 15,
                          ),
                          PieChartSectionData(
                            // value: recipe.macronutrients['fat'] ?? 0,
                            value: 10,
                            color: const Color.fromARGB(255, 212, 98, 215),
                            title: ' ',
                            radius: 15,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMacronutrientCard(
                    color: const Color.fromARGB(255, 82, 225, 211),
                    label: 'Carbs',
                    value: '12g',
                  ),
                  _buildMacronutrientCard(
                    color: const Color.fromARGB(255, 255, 168, 54),
                    label: 'Protein',
                    value: '8g',
                  ),
                  _buildMacronutrientCard(
                    color: const Color.fromARGB(255, 212, 98, 215),
                    label: 'Fat',
                    value: '10g',
                  ),
                ],
              ),
              // Stack(
              //   children: [
              //     Positioned.fill(
              //       child: Center(
              //         child: Column(
              //           mainAxisSize: MainAxisSize.min,
              //           children: [
              //             const Text(
              //               '1234',
              //               style: TextStyle(
              //                 fontSize: 16,
              //                 fontWeight: FontWeight.bold,
              //               ),
              //             ),
              //             Text(
              //               'kcal',
              //               style: const TextStyle(
              //                 fontSize: 14,
              //                 color: Colors.grey,
              //               ),
              //             ),
              //           ],
              //         ),
              //         // child: const Text(
              //         //   '1240 Kcal',
              //         //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              //         // ),
              //       ),
              //     ),
              //     PieChart(
              //       PieChartData(
              //         centerSpaceColor: Colors.transparent,
              //         borderData: FlBorderData(show: false),
              //         sectionsSpace: 5,
              //         centerSpaceRadius: 35,
              //         startDegreeOffset: 180,
              //         sections: [
              //           PieChartSectionData(
              //             // value: recipe.macronutrients['carbs'] ?? 0,
              //             value: 12,
              //             color: const Color.fromARGB(255, 82, 225, 211),
              //             title: ' ',
              //             radius: 15,
              //           ),
              //           PieChartSectionData(
              //             // value: recipe.macronutrients['protein'] ?? 0,
              //             value: 8,
              //             color: const Color.fromARGB(255, 255, 168, 54),
              //             title: ' ',
              //             radius: 15,
              //           ),
              //           PieChartSectionData(
              //             // value: recipe.macronutrients['fat'] ?? 0,
              //             value: 10,
              //             color: const Color.fromARGB(255, 212, 98, 215),
              //             title: ' ',
              //             radius: 15,
              //           ),
              //         ],
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ),
      ],
    );
  }

  void _shareRecipe(BuildContext context) {
    // TODO: Implementar compartir receta
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Función de compartir próximamente')),
    );
  }

  _buildMacronutrientCard({
    required Color color,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w300),
          ),
          // const SizedBox(height: 4),
        ],
      ),
    );
  }
}
