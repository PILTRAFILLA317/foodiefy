import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'config/cloud_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final config = AppConfig.fromEnvironment();
    AppConfig.current = config;
    if (!config.rescueMode) {
      await Supabase.initialize(
        url: config.supabaseUrl.toString(),
        anonKey: config.supabasePublicKey!,
      );
      CloudRuntime.client = Supabase.instance.client;
    }
    runApp(const MyApp());
  } on ConfigurationException catch (error) {
    runApp(ConfigurationErrorApp(message: error.message));
  } catch (_) {
    runApp(
      const ConfigurationErrorApp(
        message:
            'No se pudo inicializar cloud. Revisa la configuración o usa LOCAL_RESCUE=true con APP_ENV=local.',
      ),
    );
  }
}

class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Configuración de Foodiefy')),
      body: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Foodiefy',
      builder: (context, child) => AppConfig.current.rescueMode
          ? Banner(
              message: 'RESCATE LOCAL',
              location: BannerLocation.topEnd,
              child: child ?? const SizedBox.shrink(),
            )
          : child ?? const SizedBox.shrink(),
      theme: ThemeData(
        primarySwatch: Colors.orange,
        secondaryHeaderColor: Colors.deepOrange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.black,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.black),
          floatingLabelStyle: TextStyle(color: Colors.black),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
