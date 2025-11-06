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

class ImportErrorScreen extends StatefulWidget {
  final String message;

  const ImportErrorScreen({super.key, required this.message});

  @override
  State<ImportErrorScreen> createState() => _ImportErrorScreenState();
}

class _ImportErrorScreenState extends State<ImportErrorScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _gifPeriod = Duration(milliseconds: 1800);
  late final GifController _gifController;

  @override
  void initState() {
    super.initState();
    _gifController = GifController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _gifController
        ..value = 0
        ..repeat(min: 0, max: 1, period: _gifPeriod);
    });
  }

  @override
  void dispose() {
    _gifController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('No pudimos importar la receta'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        surfaceTintColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              SizedBox(
                height: 220,
                width: 220,
                child: Gif(
                  image: const AssetImage('assets/gifs/error.gif'),
                  controller: _gifController,
                  autostart: Autostart.no,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Asegúrate de que:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '• El video contiene una receta.',
                      style: TextStyle(fontSize: 15),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Los pasos e ingredientes están mencionados en el vídeo o la descripción.',
                      style: TextStyle(fontSize: 15),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
  static const Duration _cycleDuration = Duration(seconds: 4);
  static const Duration _gifPeriod = Duration(milliseconds: 1800);
  static const Duration _fadeDuration = Duration(milliseconds: 400);
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
  int _visualSequence = 0;
  bool _visualVisible = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _gifController = GifController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleVisualChange(initial: true);
      _startImport();
    });
  }

  @override
  void dispose() {
    _visualSequence++;
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

  void _scheduleVisualChange({bool initial = false}) {
    final nextMessage = _chooseMessage(initial: initial);
    final nextGif = _chooseGif(initial: initial);
    final token = ++_visualSequence;
    final imageProvider = AssetImage(nextGif);

    if (!initial) {
      setState(() => _visualVisible = false);
    }

    Future<void> loader;
    try {
      loader = precacheImage(imageProvider, context);
    } catch (_) {
      loader = Future<void>.value();
    }

    loader.then((_) {
      if (!mounted || token != _visualSequence) return;
      setState(() {
        _currentMessage = nextMessage;
        _currentGif = nextGif;
        _gifInstance++;
      });
      _restartGifPlayback();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || token != _visualSequence) return;
        setState(() => _visualVisible = true);
        _timer?.cancel();
        _timer = Timer(_cycleDuration, () {
          if (!mounted) return;
          _scheduleVisualChange();
        });
      });
    }).catchError((_) {
      if (!mounted || token != _visualSequence) return;
      setState(() {
        _currentMessage = nextMessage;
        _currentGif = 'assets/gifs/kitchen.gif';
        _gifInstance++;
      });
      _restartGifPlayback();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || token != _visualSequence) return;
        setState(() => _visualVisible = true);
        _timer?.cancel();
        _timer = Timer(_cycleDuration, () {
          if (!mounted) return;
          _scheduleVisualChange();
        });
      });
    });
  }

  Future<void> _startImport() async {
    try {
      final recipe = await widget.service.importRecipeFromUrl(widget.url);
      debugPrint('Imported recipe: ${recipe.id}');
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
    _visualSequence++;
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
              AnimatedOpacity(
                key: ValueKey('gif-$_gifInstance'),
                opacity: _visualVisible ? 1 : 0,
                duration: _fadeDuration,
                curve: Curves.easeInOut,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: SizedBox(
                    key: ValueKey('gif-$_gifInstance-$gifAsset'),
                    height: 220,
                    width: 220,
                    child: _gifController == null || _currentGif == null
                        ? const SizedBox.shrink()
                        : Gif(
                            image: AssetImage(gifAsset),
                            controller: _gifController!,
                            autostart: Autostart.no,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              AnimatedOpacity(
                opacity: _visualVisible ? 1 : 0,
                duration: _fadeDuration,
                curve: Curves.easeInOut,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: message.isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                          message,
                          key: ValueKey(message),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
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
              LoadingAnimationWidget.fourRotatingDots(
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
      await Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => ImportErrorScreen(message: errorMessage),
        ),
      );
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
