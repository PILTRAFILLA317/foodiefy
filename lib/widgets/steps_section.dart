import 'package:flutter/material.dart';

class StepsExpandableOverlay extends StatefulWidget {
  final List<String> steps;

  const StepsExpandableOverlay({super.key, required this.steps});

  @override
  State<StepsExpandableOverlay> createState() => _StepsExpandableOverlayState();
}

class _StepsExpandableOverlayState extends State<StepsExpandableOverlay> {
  final Map<int, GlobalKey> cardKeys = {};

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.steps.length; i++) {
      cardKeys[i] = GlobalKey();
    }
  }

  void _expandCard(int index) {
    final renderBox =
        cardKeys[index]!.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    final originalRect = Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );

    Rect rect = originalRect;
    bool isExpanded = false;

    entry = OverlayEntry(
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void closeCard() {
              // 🔹 Paso 1: cambiar rect a originalRect
              setState(() {
                rect = originalRect;
                isExpanded = false;
              });

              // 🔹 Paso 2: esperar a que se pinte el cambio y luego quitar overlay
              Future.delayed(const Duration(milliseconds: 400), () {
                entry.remove();
              });
            }

            // 🔹 Animación de apertura
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!isExpanded) {
                setState(() {
                  rect = Rect.fromLTWH(
                    0,
                    0,
                    MediaQuery.of(context).size.width,
                    MediaQuery.of(context).size.height,
                  );
                  isExpanded = true;
                });
              }
            });

            return Stack(
              children: [
                // Fondo oscurecido
                AnimatedOpacity(
                  opacity: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: GestureDetector(
                    onTap: closeCard,
                    child: Container(color: Colors.black),
                  ),
                ),

                // Tarjeta animada
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  top: rect.top,
                  left: rect.left,
                  width: rect.width,
                  height: rect.height,
                  child: Material(
                    color: Colors.white,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
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
                                      fontSize: 24,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                widget.steps[index],
                                style: const TextStyle(fontSize: 24),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton(
                                onPressed: closeCard,
                                child: const Text('Cerrar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
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
              'Preparación (${widget.steps.length} pasos)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...widget.steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;

          return GestureDetector(
            onTap: () => _expandCard(index), // 🔹 Aquí se usa
            child: Card(
              key: cardKeys[index],
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
}
