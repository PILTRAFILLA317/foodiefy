import 'package:flutter/material.dart';
import '../services/collection_service.dart';

class CollectionCreationDialog extends StatefulWidget {
  final VoidCallback onImportSuccess;

  const CollectionCreationDialog({super.key, required this.onImportSuccess});

  @override
  State<CollectionCreationDialog> createState() =>
      _CollectionCreationDialogState();
}

class _CollectionCreationDialogState extends State<CollectionCreationDialog> {
  final _nameController = TextEditingController();
  final bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Crear Colección'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            cursorColor: Colors.black,
            decoration: InputDecoration(
              fillColor: Colors.grey[300],
              filled: true,
              hintText: 'Nombre de la colección',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide.none,
              ),
              // contentPadding: const EdgeInsets.symmetric(
              //   vertical: 0,
              //   horizontal: 16,
              // ),
            ),
            controller: _nameController,
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: Colors.black),
          child: const Text('Cancelar', style: TextStyle(color: Colors.black)),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  // _importRecipe();
                  await CollectionService().saveCollection(
                    _nameController.text.trim(),
                  );
                  // print('Create Collection...');
                  widget.onImportSuccess();
                  Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey,
            disabledForegroundColor: Colors.white70,
          ),
          child: const Text('Crear'),
        ),
      ],
    );
  }

  // void _importRecipe() async {
  //   final url = _nameController.text.trim();
  //   if (url.isEmpty) {
  //     _showError('Por favor ingresa una URL');
  //     return;
  //   }

  //   if (!_isValidUrl(url)) {
  //     _showError('URL no válida. Debe ser de TikTok, Instagram o YouTube');
  //     return;
  //   }

  //   setState(() => _isLoading = true);

  //   try {
  //     await RecipeService.importRecipeFromUrl(url);
  //     widget.onImportSuccess();
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Receta importada exitosamente')),
  //       );
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       setState(() => _isLoading = false);
  //       _showError('Error al importar: $e');
  //     }
  //   }
  // }

  // bool _isValidUrl(String url) {
  //   return url.contains('tiktok.com') ||
  //          url.contains('instagram.com') ||
  //          url.contains('youtube.com') ||
  //          url.contains('youtu.be');
  // }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
