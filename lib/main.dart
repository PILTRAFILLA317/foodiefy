import 'screens/import_recipe_screen.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'config/cloud_runtime.dart';
import 'repositories/app_repositories.dart';
import 'screens/auth/account_form.dart';
import 'repositories/session_repository.dart';
import 'repositories/auth_errors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FoodiefyBootstrap());
}

class FoodiefyBootstrap extends StatefulWidget {
  const FoodiefyBootstrap({super.key});
  @override
  State<FoodiefyBootstrap> createState() => _FoodiefyBootstrapState();
}

class _FoodiefyBootstrapState extends State<FoodiefyBootstrap> {
  late final Future<void> _ready = _initialize();
  Future<void> _initialize() async {
    final config = AppConfig.fromEnvironment();
    AppConfig.current = config;
    if (!config.rescueMode) {
      await Supabase.initialize(
        url: config.supabaseUrl.toString(),
        anonKey: config.supabasePublicKey!,
        // Auth diagnostics go through our safe mapper, never raw SDK logging.
        debug: false,
      );
      CloudRuntime.client = Supabase.instance.client;
    }
    await AppRepositories.initialize();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        logAuthError(
          snapshot.error!,
          snapshot.stackTrace ?? StackTrace.current,
        );
        return const ConfigurationErrorApp(
          message:
              'No se pudo iniciar Foodiefy. Revisa la configuración de la aplicación.',
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Iniciando Foodiefy',
              ),
            ),
          ),
        );
      }
      return const MyApp();
    },
  );
}

class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      appBar: AppBar(title: const Text('Configuración de Foodiefy')),
      body: Padding(padding: const EdgeInsets.all(24), child: Text(message)),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _shownOwner;
  SessionStatus? _shownStatus;
  GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppRepositories.session,
      builder: (context, _) {
        final owner = AppRepositories.session.ownerId;
        final status = AppRepositories.session.status;
        if (_shownOwner != owner || _shownStatus != status) {
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
          _shownOwner = owner;
          _shownStatus = status;
          _navigator = GlobalKey<NavigatorState>();
        }
        return MaterialApp(
          key: ValueKey('$owner:$status'),
          navigatorKey: _navigator,
          title: 'Foodiefy',
          builder: (context, child) => AppConfig.current.rescueMode
              ? Banner(
                  message: 'RESCATE LOCAL',
                  location: BannerLocation.topEnd,
                  child: child ?? const SizedBox.shrink(),
                )
              : status != SessionStatus.authenticated ||
                    AppRepositories.shares == null
              ? child ?? const SizedBox.shrink()
              : ListenableBuilder(
                  listenable: AppRepositories.shares!,
                  builder: (context, _) => Column(
                    children: [
                      if (AppRepositories.shares!.pending != null)
                        Material(
                          color: Colors.orange.shade50,
                          child: SafeArea(
                            bottom: false,
                            child: ListTile(
                              title: const Text('Enlace compartido pendiente'),
                              subtitle: const Text(
                                'Ábrelo para elegir e importar. Aún no se ha procesado.',
                              ),
                              trailing: const Icon(Icons.link),
                              onTap: () => _navigator.currentState?.push(
                                MaterialPageRoute(
                                  builder: (_) => const ImportRecipeScreen(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Expanded(child: child ?? const SizedBox.shrink()),
                    ],
                  ),
                ),
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
          home: const AuthGate(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

/// All normal routes live inside the navigator replaced on access/owner changes.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    if (AppConfig.current.rescueMode) return const HomeScreen();
    return switch (AppRepositories.session.status) {
      SessionStatus.initializing => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Recuperando sesión',
          ),
        ),
      ),
      SessionStatus.unauthenticated => const AccountForm(
        mode: AccountMode.login,
      ),
      SessionStatus.passwordRecovery => const AccountForm(
        mode: AccountMode.newPassword,
      ),
      SessionStatus.authenticated => const HomeScreen(),
    };
  }
}
