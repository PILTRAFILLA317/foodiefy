import 'package:flutter/material.dart';
import 'package:gif/gif.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen>
    with TickerProviderStateMixin {
  late final GifController gifController;

  @override
  void initState() {
    super.initState();
    gifController = GifController(vsync: this);
  }

  @override
  void dispose() {
    gifController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Planes Foodiefy'),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Elige el plan que mejor se ajuste a tu cocina.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _PlanCard(
                      title: 'Plan gratuito',
                      price: '0 €/mes',
                      description:
                          'Hasta 10 recetas guardadas\nSincronización manual',
                      highlighted: false,
                      actionLabel: 'Estás en este plan',
                      onPressed: null,
                    ),
                    const SizedBox(height: 16),
                    _PlanCard(
                      title: 'Plan Pro',
                      price: '2,99 €/mes',
                      description:
                          'Recetas ilimitadas\nSincronización automática\nAcceso anticipado a nuevas funciones',
                      highlighted: true,
                      actionLabel: 'Elegir Plan Pro',
                      onPressed: () {
                        // TODO: Integrate checkout/payment flow.
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tu suscripción ayuda a un pequeño equipo a mantener Foodiefy actualizado, pagar los servidores y seguir mejorando la experiencia.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: Gif(
                        controller: gifController,
                        image: AssetImage('assets/heart.gif'),
                        onFetchCompleted: () {
                          gifController.repeat(
                            min: 0,
                            max: 1,
                            period: Duration(seconds: 2),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String description;
  final bool highlighted;
  final String actionLabel;
  final VoidCallback? onPressed;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.description,
    required this.highlighted,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = highlighted ? Colors.orange : Colors.black;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlighted
            ? Colors.orange.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted
              ? Colors.orange
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: highlighted ? 2 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: highlighted ? Colors.orange : Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
