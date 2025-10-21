import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gif/gif.dart';

import 'package:foodiefy/utils/lottie_rules.dart';

String _normalizeStepText(String input) {
  var normalized = input.toLowerCase();
  const replacements = {
    'á': 'a',
    'ä': 'a',
    'à': 'a',
    'â': 'a',
    'é': 'e',
    'ë': 'e',
    'è': 'e',
    'ê': 'e',
    'í': 'i',
    'ï': 'i',
    'ì': 'i',
    'î': 'i',
    'ó': 'o',
    'ö': 'o',
    'ò': 'o',
    'ô': 'o',
    'ú': 'u',
    'ü': 'u',
    'ù': 'u',
    'û': 'u',
    'ñ': 'n',
  };

  replacements.forEach((original, replacement) {
    normalized = normalized.replaceAll(original, replacement);
  });

  return normalized;
}

final _random = Random();

String _selectLottieForStep(String stepText, {String? previousAsset}) {
  final normalized = _normalizeStepText(stepText);
  final tokens = normalized
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.isNotEmpty)
      .toList();
  final tokenSet = tokens.toSet();

  final matchedAssets = <String>{};

  bool matchesKeyword(String keyword) {
    final normalizedKeyword = _normalizeStepText(
      keyword,
    ).replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    final parts = normalizedKeyword
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return false;
    }

    if (parts.length == 1) {
      return tokenSet.contains(parts.first);
    }

    final window = parts.length;
    for (var i = 0; i <= tokens.length - window; i++) {
      var matches = true;
      for (var j = 0; j < window; j++) {
        if (tokens[i + j] != parts[j]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return true;
      }
    }

    return false;
  }

  for (final rule in lottieRules) {
    final hasMatch = rule.keywords.any(matchesKeyword);
    if (hasMatch) {
      // print('Rule matched: ${rule.asset}');
      matchedAssets.add(rule.asset);
    }
  }
  // print('Step matched: $stepText');

  if (matchedAssets.isNotEmpty) {
    final candidates = matchedAssets
        .where((asset) => asset != previousAsset)
        .toList();

    if (candidates.isNotEmpty) {
      return candidates[_random.nextInt(candidates.length)];
    }

    final allMatches = matchedAssets.toList();
    return allMatches[_random.nextInt(allMatches.length)];
  }

  final fallbackCandidates = fallbackAnimations
      .where((asset) => asset != previousAsset)
      .toList();

  if (fallbackCandidates.isNotEmpty) {
    return fallbackCandidates[_random.nextInt(fallbackCandidates.length)];
  }

  return fallbackAnimations.isNotEmpty
      ? fallbackAnimations[_random.nextInt(fallbackAnimations.length)]
      : defaultAnimationAsset;
}

List<String> _computeLottieSequence(List<String> steps) {
  final assets = <String>[];
  String? previous;

  for (final step in steps) {
    final asset = _selectLottieForStep(step, previousAsset: previous);
    assets.add(asset);
    previous = asset;
  }

  return assets;
}

class StepDetailScreen extends StatefulWidget {
  final List<String> steps;
  final int initialIndex;

  const StepDetailScreen({
    super.key,
    required this.steps,
    required this.initialIndex,
  });

  @override
  State<StepDetailScreen> createState() => _StepDetailScreenState();
}

class _StepDetailScreenState extends State<StepDetailScreen>
    with SingleTickerProviderStateMixin {
  late int currentIndex;
  late List<String> _selectedAssets;
  late GifController _gifController;
  static const Duration _defaultGifLoop = Duration(milliseconds: 2000);
  bool _isGifReady = false;
  int _gifInstance = 0;

  void _prepareForNewAsset() {
    _gifController.stop();
    _gifController.value = 0;
  }

  void _restartPlayback({bool immediate = false}) {
    void start() {
      if (!mounted || _selectedAssets.isEmpty || !_isGifReady) return;
      _gifController.stop();
      _gifController.value = 0;
      _gifController.repeat(min: 0, max: 1, period: _defaultGifLoop);
    }

    if (immediate) {
      start();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => start());
    }
  }

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _selectedAssets = _computeLottieSequence(widget.steps);
    _gifController = GifController(vsync: this);
    _prepareForNewAsset();
  }

  @override
  void didUpdateWidget(covariant StepDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.steps, widget.steps)) {
      setState(() {
        _selectedAssets = _computeLottieSequence(widget.steps);
        if (currentIndex >= widget.steps.length) {
          currentIndex = widget.steps.isEmpty ? 0 : widget.steps.length - 1;
        }
        _isGifReady = false;
        _gifInstance++;
      });
      _prepareForNewAsset();
    }
  }

  void _goToPrevious() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        _isGifReady = false;
        _gifInstance++;
      });
      _prepareForNewAsset();
    }
  }

  void _goToNext() {
    if (currentIndex < widget.steps.length - 1) {
      setState(() {
        currentIndex++;
        _isGifReady = false;
        _gifInstance++;
      });
      _prepareForNewAsset();
    }
  }

  @override
  void dispose() {
    _gifController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stepText = widget.steps[currentIndex];
    final lottieAsset = _selectedAssets[currentIndex];
  
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Paso ${currentIndex + 1} de ${widget.steps.length}'),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${currentIndex + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              stepText,
              style: const TextStyle(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    key: ValueKey('$lottieAsset-$_gifInstance'),
                    height: 220,
                    width: 220,
                    child: AnimatedOpacity(
                      opacity: _isGifReady ? 1 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Gif(
                        key: ValueKey(_gifInstance),
                        image: AssetImage(lottieAsset),
                        controller: _gifController,
                        autostart: Autostart.no,
                        placeholder: (context) => const SizedBox.shrink(),
                        onFetchCompleted: () {
                          if (!mounted) return;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            final alreadyReady = _isGifReady;
                            if (!alreadyReady) {
                              setState(() {
                                _isGifReady = true;
                              });
                            }
                            _restartPlayback(immediate: true);
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 160,
                  height: 60,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      disabledForegroundColor: Colors.white70,
                    ),
                    onPressed: currentIndex > 0 ? _goToPrevious : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Anterior'),
                  ),
                ),
                SizedBox(
                  width: 160,
                  height: 60,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey,
                        disabledForegroundColor: Colors.white70,
                      ),
                      onPressed: currentIndex < widget.steps.length - 1
                          ? _goToNext
                          : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Siguiente'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
