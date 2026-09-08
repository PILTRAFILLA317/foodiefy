import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../imports/import_jobs.dart';
import '../imports/share_inbox.dart';
import '../models/recipe.dart';
import '../repositories/app_repositories.dart';
import '../services/import_service.dart';
import 'auth/login_screen.dart';
import 'create_recipe_screen.dart';

class ImportRecipeScreen extends StatefulWidget {
  const ImportRecipeScreen({super.key, this.initialCollectionId});
  final String? initialCollectionId;
  @override
  State<ImportRecipeScreen> createState() => _ImportRecipeScreenState();
}

class _ImportRecipeScreenState extends State<ImportRecipeScreen> {
  final _url = TextEditingController(), _text = TextEditingController();
  bool _paste = false;
  String? _error, _selectedShare, _shownShareId, _lastSharedUrl;
  @override
  void initState() {
    super.initState();
    AppRepositories.shares?.addListener(_changed);
    AppRepositories.imports?.addListener(_changed);
    final urls = AppRepositories.shares?.urls ?? [];
    _shownShareId = AppRepositories.shares?.pending?['id'];
    if (urls.length == 1) {
      _url.text = urls.single;
      _lastSharedUrl = urls.single;
    }
  }

  void _changed() {
    if (!mounted) return;
    final inbox = AppRepositories.shares;
    final next = inbox?.pending?['id'] as String?;
    if (next != _shownShareId) {
      final urls = inbox?.urls ?? [];
      if (_url.text.isEmpty || _url.text == _lastSharedUrl) {
        _url.text = urls.length == 1 ? urls.single : '';
      }
      _lastSharedUrl = urls.length == 1 ? urls.single : null;
      _selectedShare = null;
      _shownShareId = next;
    }
    setState(() {});
  }

  @override
  void dispose() {
    AppRepositories.shares?.removeListener(_changed);
    AppRepositories.imports?.removeListener(_changed);
    _url.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final url = _url.text.trim(), text = _text.text.trim();
    if ((!_paste &&
            (sharedUrls(url).length != 1 || sharedUrls(url).single != url)) ||
        (_paste && (text.isEmpty || utf8.encode(text).length > 6000))) {
      setState(
        () => _error =
            'Revisa el enlace HTTP(S) o pega hasta 6000 bytes de texto.',
      );
      return;
    }
    if (AppRepositories.session.ownerId == null) {
      if (url.isNotEmpty &&
          !(AppRepositories.shares?.urls.contains(url) ?? false)) {
        await AppRepositories.shares?.receive({
          'id': const Uuid().v4(),
          'created': DateTime.now().millisecondsSinceEpoch,
          'text': url,
        });
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    final jobs = AppRepositories.imports;
    if (jobs == null) {
      setState(() => _error = importError('disabled'));
      return;
    }
    if (jobs.visible.any((x) => !x.terminal)) {
      setState(
        () => _error =
            'Continúa o cancela el intento pendiente antes de crear otro.',
      );
      return;
    }
    setState(() => _error = null);
    final shareId = AppRepositories.shares?.pending?['id'] as String?;
    await jobs.submit({
      if (!_paste || (url.isNotEmpty && sharedUrls(url).contains(url)))
        'url': url,
      if (_paste) 'description': text,
    }, collectionId: widget.initialCollectionId);
    if (!mounted) return;
    // Confirmation was explicit. No share callback starts a request.
    if (shareId != null) {
      await AppRepositories.shares?.clear(expectedId: shareId);
    }
  }

  Future<void> _review(PendingImport item) async {
    final recipe = item.draft;
    if (recipe == null) return;
    final owner = AppRepositories.session.ownerId;
    final result = await Navigator.push<Recipe>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateRecipeScreen(
          template: recipe,
          importRecipeId: item.recipeId,
          importOperationId: const Uuid().v5(
            Namespace.url.value,
            'foodiefy-save:${item.recipeId}',
          ),
          initialCollectionId: item.collectionId ?? widget.initialCollectionId,
        ),
      ),
    );
    if (!mounted || owner != AppRepositories.session.ownerId) return;
    if (result != null) await AppRepositories.imports?.dismiss(item);
  }

  Future<void> _cancel(PendingImport item) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar importación?'),
        content: const Text(
          'Se detendrán las próximas etapas. Una llamada ya enviada puede haber generado coste. El servidor conserva la transcripción necesaria dentro de su TTL.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar importación'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) await AppRepositories.imports?.cancel(item);
  }

  @override
  Widget build(BuildContext context) {
    final jobs = AppRepositories.imports, shares = AppRepositories.shares;
    final choices = shares?.urls ?? [];
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Importar receta'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Pega el enlace y revisa el borrador antes de guardarlo. La importación continúa aunque cierres la app.',
          ),
          if (shares?.pending != null) ...[
            const SizedBox(height: 16),
            if (choices.isEmpty)
              const Text(
                'El contenido compartido no incluye un enlace. Puedes escribir uno o pegar la receta tras iniciar sesión.',
              ),
            if (choices.length > 1) ...[
              const Text('Hay varios enlaces. Selecciona cuál importar:'),
              for (final url in choices)
                ListTile(
                  title: Text(url),
                  leading: Icon(
                    _selectedShare == url
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  onTap: () => setState(() {
                    _selectedShare = url;
                    _url.text = url;
                  }),
                ),
            ],
            TextButton(
              onPressed: () => shares!.clear(),
              child: const Text('Descartar contenido compartido'),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            maxLength: 4096,
            decoration: InputDecoration(
              labelText: _paste ? 'Enlace de origen (opcional)' : 'Enlace',
              prefixIcon: const Icon(Icons.link),
              filled: true,
              fillColor: Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pegar texto / receta'),
            subtitle: const Text(
              'Si el enlace no es accesible. No necesitas cookies ni credenciales de redes sociales.',
            ),
            value: _paste,
            onChanged: (v) => setState(() => _paste = v),
          ),
          if (_paste)
            TextField(
              controller: _text,
              minLines: 5,
              maxLines: 12,
              maxLength: 6000,
              decoration: const InputDecoration(
                labelText: 'Descripción o receta completa',
                helperText:
                    'Se procesa como evidencia separada, con las mismas cuotas.',
              ),
            ),
          if (_error != null) Text(_error!, semanticsLabel: 'Error: $_error'),
          if (jobs?.error != null)
            Text(jobs!.error!, semanticsLabel: 'Error: ${jobs.error}'),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
            onPressed: jobs?.busy == true ? null : _start,
            child: Text(
              AppRepositories.session.ownerId == null
                  ? 'Iniciar sesión para importar'
                  : 'Importar receta',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tus importaciones',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Actualizar importaciones',
                onPressed: jobs?.busy == true ? null : jobs?.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          for (final item in jobs?.visible.reversed ?? <PendingImport>[])
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        item.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (item.view?['stage'] != null && item.status == 'queued')
                      const Text(
                        'Esperando el siguiente intento del servidor.',
                      ),
                    if (item.jobId != null)
                      Text(
                        'ID: ${item.jobId}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (item.view?['result'] != null)
                      DraftWarnings(
                        result: Map<String, dynamic>.from(item.view!['result']),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (item.draft != null)
                          ElevatedButton(
                            onPressed: () => _review(item),
                            child: const Text('Revisar borrador'),
                          ),
                        if (!item.terminal && item.jobId != null)
                          TextButton(
                            onPressed: jobs!.busy ? null : () => _cancel(item),
                            child: const Text('Cancelar'),
                          ),
                        if (item.jobId == null)
                          TextButton(
                            onPressed: jobs!.busy
                                ? null
                                : () => jobs.retry(item),
                            child: const Text('Reintentar el mismo envío'),
                          ),
                        if (item.terminal)
                          TextButton(
                            onPressed: () => jobs!.dismiss(item),
                            child: const Text('Descartar borrador'),
                          ),
                        if (item.view?['error'] == 'source_unavailable')
                          TextButton(
                            onPressed: () => setState(() => _paste = true),
                            child: const Text('Pegar receta'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DraftWarnings extends StatelessWidget {
  const DraftWarnings({super.key, required this.result});
  final Map<String, dynamic> result;
  @override
  Widget build(BuildContext context) {
    final draft = result['recipe'] as Map?;
    final nutrition = draft?['nutrition'] as Map?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result['analysis_status'] == 'partial')
          const Text(
            'Información incompleta: revisa ingredientes, cantidades y pasos.',
          ),
        for (final warning in {
          ...(result['warnings'] as List? ?? []),
          ...(draft?['warnings'] as List? ?? []),
        })
          Text('Aviso: $warning'),
        for (final missing in result['missing_information'] as List? ?? [])
          Text('Falta información: $missing'),
        for (final conflict in result['conflicts'] as List? ?? [])
          Text(
            'Contradicción en ${conflict['field_path']}: ${(conflict['evidence'] as List).map((e) => "${e['source_kind']}: ${e['quote']}").join(' / ')}',
          ),
        if (nutrition != null)
          Text(
            'Nutrición ${['calculated', 'estimated'].contains(nutrition['method']) ? 'estimada' : 'según ${nutrition['method']}'} · Base: ${nutrition['basis']}',
          ),
        if (nutrition == null && draft != null)
          const Text('Nutrición no disponible; no se han rellenado valores.'),
      ],
    );
  }
}
