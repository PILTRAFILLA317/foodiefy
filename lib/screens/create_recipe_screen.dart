// lib/screens/create_recipe_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
// import '../widgets/auth_required_dialog.dart';
import '../widgets/time_picker_widget.dart';
// import 'auth_placeholder_screen.dart';

class CreateRecipeScreen extends StatefulWidget {
  final Recipe? template;

  const CreateRecipeScreen({super.key, this.template});

  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _totalKcalController = TextEditingController();
  final _carbsController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _ingredientController = TextEditingController();
  final _stepController = TextEditingController();

  final List<String> _ingredients = [];
  final List<String> _steps = [];
  File? _selectedImage;
  String? _remoteImagePath;
  bool _isPublic = false;
  bool _isSaving = false;
  int? _prepTimeMinutes;
  late final bool _isImportedSource;
  bool _includeMacros = false;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _isImportedSource = template?.isImported ?? false;

    if (template != null) {
      _titleController.text = template.title;
      _descriptionController.text = template.description ?? '';
      _quantityController.text = template.finalQuantity ?? '';
      _ingredients.addAll(template.ingredients);
      _steps.addAll(template.steps);
      _isPublic = template.isPublic;
      _prepTimeMinutes = template.prepTimeMinutes;

      final macros = template.macronutrients;
      if (macros != null) {
        _totalKcalController.text = macros.totalKcal?.toString() ?? '';
        _carbsController.text = macros.carbsGrams?.toString() ?? '';
        _proteinController.text = macros.proteinGrams?.toString() ?? '';
        _fatController.text = macros.fatGrams?.toString() ?? '';
        _includeMacros = true;
      }

      final path = template.imagePath;
      if (path != null && path.trim().isNotEmpty) {
        final trimmed = path.trim();
        if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
          _remoteImagePath = trimmed;
        } else {
          final filePath = trimmed.startsWith('file://')
              ? Uri.parse(trimmed).toFilePath()
              : trimmed;
          final file = File(filePath);
          if (file.existsSync()) {
            _selectedImage = file;
          } else {
            _remoteImagePath = trimmed;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Crear Receta'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: ElevatedButton(
              onPressed: _canSave() && !_isSaving ? _saveRecipe : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text('Guardar'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildImageSection(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBasicInfoSection(),
                    const SizedBox(height: 24),
                    _buildTimeSection(),
                    const SizedBox(height: 24),
                    _buildMacrosSection(),
                    const SizedBox(height: 24),
                    _buildIngredientsSection(),
                    const SizedBox(height: 24),
                    _buildStepsSection(),
                    // const SizedBox(height: 24),
                    // _buildVisibilitySection(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        // gradient: LinearGradient(
        //   begin: Alignment.topCenter,
        //   end: Alignment.bottomCenter,
        //   colors: [
        //     Colors.white,
        //     Colors.grey[600]!,
        //   ],
        // ),
        color: Colors.grey[300],
      ),
      child: Stack(
        children: [
          if (_selectedImage != null)
            Positioned.fill(
              child: Image.file(_selectedImage!, fit: BoxFit.cover),
            )
          else if (_remoteImagePath != null)
            Positioned.fill(
              child: Image.network(
                _remoteImagePath!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                // gradient: LinearGradient(
                //   begin: Alignment.topCenter,
                //   end: Alignment.bottomCenter,
                //   colors: [
                //     Colors.grey[600]!,
                //     Colors.transparent,
                //   ],
                // ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _selectedImage != null ? Icons.edit : Icons.camera_alt,
                    size: 32,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
          _selectedImage != null || _remoteImagePath != null
            ? 'Cambiar foto'
            : 'Agregar foto',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(onTap: _pickImage),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey[300],
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      color: Colors.grey[100],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.info_outline, color: Colors.black),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Información Básica',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              cursorColor: Colors.black,
              controller: _titleController,
              decoration: InputDecoration(
                fillColor: Colors.grey[300],
                labelText: 'Título de la receta *',
                labelStyle: const TextStyle(color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El título es requerido';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextFormField(
              cursorColor: Colors.black,
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Descripción (opcional)',
                labelStyle: const TextStyle(color: Colors.black),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSection() {
    return Card(
      color: Colors.grey[100],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.timer, color: Colors.black),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Tiempo de Preparación',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              cursorColor: Colors.black,
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: 'Porciones / Cantidad (texto libre)',
                labelStyle: const TextStyle(color: Colors.black),
                hintText: 'Ej. "Sirve para 4 personas" o "Rinde 12 galletas"',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
                prefixIcon: const Icon(Icons.flatware),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TimePickerWidget(
              initialMinutes: _prepTimeMinutes,
              onTimeChanged: (minutes) {
                setState(() {
                  _prepTimeMinutes = minutes;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacrosSection() {
    return Card(
      color: Colors.grey[100],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.pie_chart_outline, color: Colors.black),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Macronutrientes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Añadir macronutrientes'),
              subtitle: const Text(
                'Calorías totales y gramos de carbohidratos, proteínas y grasas.',
              ),
              value: _includeMacros,
              onChanged: (value) {
                setState(() => _includeMacros = value);
              },
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: !_includeMacros
                  ? const SizedBox.shrink()
                  : Column(
                      key: const ValueKey('macros-form'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMacroTextField(
                          label: 'Calorías totales',
                          suffix: 'kcal',
                          controller: _totalKcalController,
                          icon: Icons.local_fire_department,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMacroTextField(
                                label: 'Carbohidratos',
                                suffix: 'g',
                                controller: _carbsController,
                                icon: Icons.bubble_chart,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMacroTextField(
                                label: 'Proteínas',
                                suffix: 'g',
                                controller: _proteinController,
                                icon: Icons.fitness_center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildMacroTextField(
                          label: 'Grasas',
                          suffix: 'g',
                          controller: _fatController,
                          icon: Icons.opacity,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? suffix,
  }) {
    return TextFormField(
      controller: controller,
      cursorColor: Colors.black,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black),
        suffixText: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        prefixIcon: Icon(icon, color: Colors.black)
      ),
    );
  }

  Widget _buildIngredientsSection() {
    return Card(
      color: Colors.grey[100],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.shopping_cart, color: Colors.black),
                ),
                const SizedBox(width: 12),
                Text(
                  'Ingredientes (${_ingredients.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    cursorColor: Colors.black,
                    controller: _ingredientController,
                    decoration: InputDecoration(
                      // focusColor: Colors.black,
                      // hoverColor: Colors.black,
                      labelStyle: const TextStyle(color: Colors.black),
                      hintText: 'Agregar ingrediente',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.black, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.add_shopping_cart),
                    ),
                    onFieldSubmitted: (_) => _addIngredient(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: _addIngredient,
                    icon: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_ingredients.isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _ingredients.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Container(
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
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        title: Text(_ingredients[index]),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeIngredient(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'No hay ingredientes agregados',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsSection() {
    return Card(
      color: Colors.grey[100],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.list_alt, color: Colors.black),
                ),
                const SizedBox(width: 12),
                Text(
                  'Pasos (${_steps.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    cursorColor: Colors.black,
                    controller: _stepController,
                    decoration: InputDecoration(
                      hintText: 'Agregar paso',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.black, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.format_list_numbered),
                    ),
                    maxLines: 2,
                    onFieldSubmitted: (_) => _addStep(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: _addStep,
                    icon: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_steps.isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _steps.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
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
                        title: Text(
                          _steps[index],
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeStep(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Center(
                  child: Text(
                    'No hay pasos agregados',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilitySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isPublic ? Icons.public : Icons.lock,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Visibilidad',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Hacer pública'),
              subtitle: Text(
                _isPublic
                    ? 'Otros usuarios podrán ver esta receta'
                    : 'Solo tú podrás ver esta receta',
              ),
              value: _isPublic,
              activeThumbColor: Colors.orange,
              onChanged: (value) {
                if (value) {
                  _showAuthRequiredForPublic();
                } else {
                  setState(() => _isPublic = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (!mounted) return;

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _remoteImagePath = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo seleccionar la imagen. Intenta nuevamente.'),
        ),
      );
    }
  }

  void _addIngredient() {
    final ingredient = _ingredientController.text.trim();
    if (ingredient.isNotEmpty) {
      setState(() {
        _ingredients.add(ingredient);
        _ingredientController.clear();
      });
    }
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
  }

  void _addStep() {
    final step = _stepController.text.trim();
    if (step.isNotEmpty) {
      setState(() {
        _steps.add(step);
        _stepController.clear();
      });
    }
  }

  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
  }

  bool _canSave() {
    return _titleController.text.trim().isNotEmpty &&
        _ingredients.isNotEmpty &&
        _steps.isNotEmpty;
  }

  void _saveRecipe() async {
    if (!_formKey.currentState!.validate() || !_canSave()) return;

    setState(() => _isSaving = true);

    try {
      final macros = _collectMacronutrients();

      final recipe = Recipe(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
    finalQuantity: _quantityController.text.trim().isEmpty
      ? null
      : _quantityController.text.trim(),
        ingredients: _ingredients,
        steps: _steps,
        imagePath: _selectedImage?.path ?? _remoteImagePath,
        isPublic: _isPublic,
        isImported: _isImportedSource,
        prepTimeMinutes: _prepTimeMinutes,
        macronutrients: macros,
        createdAt: DateTime.now(),
      );

      await RecipeService.createRecipe(recipe);

      if (mounted) {
        Navigator.pop(context, recipe);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showAuthRequiredForPublic() {
    // showDialog(
    //   context: context,
    //   builder: (context) => AuthRequiredDialog(
    //     message: 'Para hacer pública una receta necesitas crear una cuenta.',
    //     onAuthPressed: () {
    //       Navigator.pop(context);
    //       Navigator.push(
    //         context,
    //         MaterialPageRoute(
    //           builder: (context) => const AuthPlaceholderScreen(),
    //         ),
    //       );
    //     },
    //   ),
    // );
  }

  RecipeMacronutrients? _collectMacronutrients() {
    if (!_includeMacros) return null;

    final totalKcal = _parseMacroValue(_totalKcalController);
    final carbs = _parseMacroValue(_carbsController);
    final protein = _parseMacroValue(_proteinController);
    final fat = _parseMacroValue(_fatController);

    final hasAnyValue =
        totalKcal != null || carbs != null || protein != null || fat != null;
    if (!hasAnyValue) {
      return null;
    }

    return RecipeMacronutrients(
      totalKcal: totalKcal,
      carbsGrams: carbs,
      proteinGrams: protein,
      fatGrams: fat,
    );
  }

  int? _parseMacroValue(TextEditingController controller) {
    final raw = controller.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _ingredientController.dispose();
    _stepController.dispose();
    _quantityController.dispose();
    _totalKcalController.dispose();
    _carbsController.dispose();
    _proteinController.dispose();
    _fatController.dispose();
    super.dispose();
  }
}
