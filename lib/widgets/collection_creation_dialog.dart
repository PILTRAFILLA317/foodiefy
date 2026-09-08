import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/collection.dart';
import '../repositories/library_repository.dart';
import '../services/collection_service.dart';

class CollectionCreationDialog extends StatefulWidget {
  final VoidCallback onImportSuccess;
  final RecipeCollection? collection;
  const CollectionCreationDialog({
    super.key,
    required this.onImportSuccess,
    this.collection,
  });
  @override
  State<CollectionCreationDialog> createState() =>
      _CollectionCreationDialogState();
}

class _CollectionCreationDialogState extends State<CollectionCreationDialog> {
  late final _name = TextEditingController(text: widget.collection?.name);
  final _id = const Uuid().v4();
  bool _busy = false;
  String? _error;
  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Escribe un nombre.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.collection != null) {
        await CollectionService().renameCollection(
          widget.collection!,
          _name.text,
        );
      } else {
        await CollectionService().saveCollection(_name.text, id: _id);
      }
      if (!mounted) return;
      widget.onImportSuccess();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = cloudError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    title: Text(
      widget.collection == null ? 'Crear Colección' : 'Editar colección',
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'Nombre de la colección',
          ),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        if (_busy) const LinearProgressIndicator(),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      ElevatedButton(
        onPressed: _busy ? null : _save,
        child: const Text('Guardar'),
      ),
    ],
  );
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }
}
