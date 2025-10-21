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
                  if (_hasPrepOrQuantity) ...[
                    _buildPrepAndYieldSection(),
                    const SizedBox(height: 24),
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
          errorBuilder: (_, _, _) => _buildPlaceholderImage(),
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
    final creatorInfo = _buildCreatorInfo();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recipe.isImported) ...[
          _buildImportedBadge(),
          const SizedBox(height: 5),
        ],
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
                  Text(
                    recipe.uploader ?? 'Desconocido',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 7),
                  SvgPicture.asset(
                    width: 20,
                    height: 20,
                    'assets/${(recipe.platform ?? 'web').toLowerCase()}_icon.svg',
                    colorFilter: ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    semanticsLabel: 'Label',
                  ),
                ],
              ),
            ],
            if (recipe.isPublic) ...[
              const Icon(Icons.public, size: 16, color: Colors.green),
              const SizedBox(width: 4),
              const Text(
                'Pública',
                style: TextStyle(color: Colors.green, fontSize: 12),
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
    if (recipe.macronutrients == null) {
      return const SizedBox.shrink();
    }
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
                            Text(
                              recipe.macronutrients?.totalKcal != null
                                  ? '${recipe.macronutrients?.totalKcal}'
                                  : '0',
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
                            value: recipe.macronutrients?.carbsGrams != null
                                ? recipe.macronutrients!.carbsGrams!.toDouble()
                                : 0,
                            color: const Color.fromARGB(255, 82, 225, 211),
                            title: ' ',
                            radius: 15,
                          ),
                          PieChartSectionData(
                            // value: recipe.macronutrients['protein'] ?? 0,
                            value: recipe.macronutrients?.proteinGrams != null
                                ? recipe.macronutrients!.proteinGrams!
                                      .toDouble()
                                : 0,
                            color: const Color.fromARGB(255, 255, 168, 54),
                            title: ' ',
                            radius: 15,
                          ),
                          PieChartSectionData(
                            // value: recipe.macronutrients['fat'] ?? 0,
                            value: recipe.macronutrients?.fatGrams != null
                                ? recipe.macronutrients!.fatGrams!.toDouble()
                                : 0,
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
                    value: recipe.macronutrients?.carbsGrams != null
                        ? '${recipe.macronutrients?.carbsGrams}g'
                        : '0g',
                  ),
                  _buildMacronutrientCard(
                    color: const Color.fromARGB(255, 255, 168, 54),
                    label: 'Protein',
                    value: recipe.macronutrients?.proteinGrams != null
                        ? '${recipe.macronutrients?.proteinGrams}g'
                        : '0g',
                  ),
                  _buildMacronutrientCard(
                    color: const Color.fromARGB(255, 212, 98, 215),
                    label: 'Fat',
                    value: recipe.macronutrients?.fatGrams != null
                        ? '${recipe.macronutrients?.fatGrams}g'
                        : '0g',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool get _hasPrepOrQuantity {
    final hasPrep =
        (recipe.prepTimeText != null &&
            recipe.prepTimeText!.trim().isNotEmpty) ||
        recipe.prepTimeMinutes != null;
    final hasQuantity =
        recipe.finalQuantity != null && recipe.finalQuantity!.trim().isNotEmpty;
    return hasPrep || hasQuantity;
  }

  Widget _buildImportedBadge() {
    return Row(
      children: const [
        Icon(Icons.link, size: 16, color: Colors.black),
        SizedBox(width: 4),
        Text('Importada', style: TextStyle(color: Colors.black, fontSize: 12)),
      ],
    );
  }

  Widget? _buildCreatorInfo() {
    final uploader = recipe.uploader?.trim();
    final platform = recipe.platform?.trim();
    if (uploader == null || uploader.isEmpty) {
      return null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.person, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '@$uploader${platform != null && platform.isNotEmpty ? ' · ${_formatPlatform(platform)}' : ''}',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (platform != null && platform.isNotEmpty) ...[
          const SizedBox(width: 8),
          _buildPlatformChip(platform),
        ],
      ],
    );
  }

  Widget _buildPlatformChip(String platform) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForPlatform(platform), size: 14, color: Colors.black),
          const SizedBox(width: 4),
          Text(
            _formatPlatform(platform),
            style: const TextStyle(fontSize: 12, color: Colors.black),
          ),
        ],
      ),
    );
  }

  IconData _iconForPlatform(String platform) {
    switch (platform.toLowerCase()) {
      case 'tiktok':
        return Icons.music_note;
      case 'instagram':
        return Icons.camera_alt_outlined;
      case 'youtube':
        return Icons.play_arrow_rounded;
      default:
        return Icons.language;
    }
  }

  String _formatPlatform(String platform) {
    if (platform.isEmpty) return platform;
    return platform[0].toUpperCase() + platform.substring(1).toLowerCase();
  }

  Widget _buildPrepAndYieldSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recipe.formattedPrepTime.isNotEmpty &&
              recipe.formattedPrepTime != 'No especificado') ...[
            _buildInfoRow(
              icon: Icons.timer_outlined,
              label: 'Tiempo de preparación',
              value: recipe.formattedPrepTime,
            ),
            // if (recipe.finalQuantity != 'No especificado')
            //   const SizedBox(height: 12),
          ],
          SizedBox(height: 12),
          if (recipe.formattedFinalQuantity != 'No especificado')
            _buildInfoRow(
              icon: Icons.scale_outlined,
              label: 'Porciones / Cantidades',
              value: recipe.formattedFinalQuantity,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.black),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 14)),
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

  Padding _buildMacronutrientCard({
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
