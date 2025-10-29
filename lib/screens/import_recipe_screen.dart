import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gif/gif.dart';

import '../models/recipe.dart';
import '../services/import_service.dart';
import 'create_recipe_screen.dart';
import '../utils/lottie_rules.dart';

import 'package:loading_animation_widget/loading_animation_widget.dart';

class ImportRecipeScreen extends StatefulWidget {
  const ImportRecipeScreen({super.key});

  @override
  State<ImportRecipeScreen> createState() => _ImportRecipeScreenState();
}

class ImportLoadingResult {
  final Recipe? recipe;
  final String? errorMessage;

  const ImportLoadingResult({this.recipe, this.errorMessage});

  bool get hasError => errorMessage != null;
}

class ImportLoadingScreen extends StatefulWidget {
  final String url;
  final ImportRecipeService service;

  const ImportLoadingScreen({
    super.key,
    required this.url,
    required this.service,
  });

  @override
  State<ImportLoadingScreen> createState() => _ImportLoadingScreenState();
}

class _ImportLoadingScreenState extends State<ImportLoadingScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _cycleDuration = Duration(seconds: 2);
  static const Duration _gifPeriod = Duration(milliseconds: 1800);
  final Random _random = Random();
  final List<String> _messages = const [
    'Preparando ingredientes...',
    'Generando pasos...',
    'Buscando sabores secretos...',
    'Emplatando la receta...',
    'Afinando cantidades...',
    'Cocinando a fuego lento...',
  ];

  late final List<String> _gifPool = _resolveGifPool();
  Timer? _timer;
  String? _currentMessage;
  String? _currentGif;
  GifController? _gifController;
  int _gifInstance = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _gifController = GifController(vsync: this);
    _advanceVisuals(initial: true);
    _timer = Timer.periodic(_cycleDuration, (_) {
      if (!mounted) return;
      _advanceVisuals();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _startImport());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gifController?.dispose();
    super.dispose();
  }

  List<String> _resolveGifPool() {
    final assets = <String>{
      defaultAnimationAsset,
      ...fallbackAnimations,
      ...lottieRules.map((rule) => rule.asset),
    };
    final gifs = assets.where((asset) => asset.endsWith('.gif')).toList();
    if (gifs.isEmpty) {
      return const ['assets/gifs/kitchen.gif'];
    }
    return gifs;
  }

  String _chooseMessage({required bool initial}) {
    if (_messages.isEmpty) {
      return '';
    }
    if (initial || _currentMessage == null) {
      return _messages.first;
    }
    String nextMessage;
    do {
      nextMessage = _messages[_random.nextInt(_messages.length)];
    } while (nextMessage == _currentMessage && _messages.length > 1);
    return nextMessage;
  }

  String _chooseGif({required bool initial}) {
    if (_gifPool.isEmpty) {
      return 'assets/gifs/kitchen.gif';
    }
    if (initial || _currentGif == null) {
      return _gifPool[_random.nextInt(_gifPool.length)];
    }
    String nextGif;
    do {
      nextGif = _gifPool[_random.nextInt(_gifPool.length)];
    } while (nextGif == _currentGif && _gifPool.length > 1);
    return nextGif;
  }

  void _restartGifPlayback() {
    if (_gifController == null) return;
    _gifController!
      ..stop()
      ..value = 0
      ..repeat(min: 0, max: 1, period: _gifPeriod);
  }

  void _advanceVisuals({bool initial = false}) {
    final nextMessage = _chooseMessage(initial: initial);
    final nextGif = _chooseGif(initial: initial);
    final gifChanged = nextGif != _currentGif;

    setState(() {
      _currentMessage = nextMessage;
      if (gifChanged || initial) {
        _currentGif = nextGif;
        _gifInstance++;
      }
    });

    if (gifChanged || initial) {
      _restartGifPlayback();
    }
  }

  Future<void> _startImport() async {
    try {
      final recipe = await widget.service.importRecipeFromUrl(widget.url);
      _complete(ImportLoadingResult(recipe: recipe));
    } on ImportRecipeException catch (error) {
      _complete(ImportLoadingResult(errorMessage: error.message));
    } catch (_) {
      _complete(const ImportLoadingResult(
        errorMessage: 'No se pudo importar la receta. Intenta nuevamente.',
      ));
    }
  }

  void _complete(ImportLoadingResult result) {
    if (_completed) return;
    _completed = true;
    _timer?.cancel();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final message = _currentMessage ?? '';
    final gifAsset = _currentGif ?? 'assets/gifs/kitchen.gif';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: SizedBox(
                  key: ValueKey('gif-$_gifInstance-$gifAsset'),
                  height: 220,
                  width: 220,
                  child: _gifController == null
                      ? const SizedBox.shrink()
                      : Gif(
                          image: AssetImage(gifAsset),
                          controller: _gifController!,
                          autostart: Autostart.no,
                        ),
                ),
              ),
              const SizedBox(height: 32),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: Text(
                  message,
                  key: ValueKey(message),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Estamos importando tu receta. Esto puede tardar unos segundos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // const LinearProgressIndicator(minHeight: 4),
              LoadingAnimationWidget.inkDrop(
                color: Colors.orange,
                size: 50,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportRecipeScreenState extends State<ImportRecipeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final ImportRecipeService _service = ImportRecipeService();
  bool _isNavigating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleImport() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Ingresa un enlace válido.';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isNavigating = true;
    });

    ImportLoadingResult? result;

    try {
      result = await Navigator.push<ImportLoadingResult>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ImportLoadingScreen(
            url: url,
            service: _service,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }

    if (!mounted || result == null) {
      return;
    }

    final errorMessage = result.errorMessage;
    if (errorMessage != null) {
      setState(() => _errorMessage = errorMessage);
      return;
    }

    final recipe = result.recipe;
    if (recipe == null) {
      return;
    }

    final createdRecipe = await Navigator.push<Recipe?>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateRecipeScreen(template: recipe),
      ),
    );

    if (!mounted) return;

    Navigator.pop(context, createdRecipe);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar receta'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pega la URL de esa receta que viste en redes y nosotros rellenamos la ficha por ti.',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _urlController,
              enabled: !_isNavigating,
              cursorColor: Colors.black,
              decoration: InputDecoration(
                labelText: 'Enlace',
                hintText: 'https://www.instagram.com/p/...',
                prefixIcon: const Icon(Icons.link),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.black, width: 2),
                ),
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_isNavigating) {
                  _handleImport();
                }
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isNavigating ? null : _handleImport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 4, 4, 6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Importar receta'),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.info_outline,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Beta: estamos conectándonos a la API para traerte la receta automáticamente. '
                      'Puede responder con datos incompletos o con errores si el enlace no es compatible todavía.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
