import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiefy/config/app_config.dart';
import 'package:foodiefy/main.dart';
import 'package:foodiefy/repositories/app_repositories.dart';
import 'package:foodiefy/repositories/auth_errors.dart';
import 'package:foodiefy/repositories/session_repository.dart';
import 'package:foodiefy/screens/auth/account_form.dart';
import 'package:foodiefy/screens/auth/verify_email_screen.dart';
import 'package:foodiefy/screens/home_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'session_repository_test.dart' show MemoryPkceStorage;

const email = 'fixture@example.invalid';
Map<String, dynamic> user() => {
  'id': '00000000-0000-4000-8000-0000000000a1',
  'aud': 'authenticated',
  'email': email,
  'created_at': '2026-09-08T00:00:00Z',
};
Map<String, dynamic> token({bool expired = false}) {
  final exp =
      DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expired ? -60 : 3600);
  final payload = base64Url
      .encode(utf8.encode(jsonEncode({'exp': exp})))
      .replaceAll('=', '');
  return {
    'access_token': 'e30.$payload.fixture',
    'refresh_token': 'fixture-refresh',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': user(),
  };
}

void main() {
  late SupabaseClient client;
  late SessionRepository session;
  late SessionRepository previous;
  late AppConfig previousConfig;
  late List<http.Request> requests;
  late Future<http.Response> Function(http.Request) handle;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    previous = AppRepositories.session;
    previousConfig = AppConfig.current;
    AppConfig.current = AppConfig.fromValues({
      'APP_ENV': 'staging',
      'SUPABASE_URL': 'https://fixture.invalid',
      'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_fixture',
    });
    requests = [];
    handle = (request) async => http.Response(
      jsonEncode(switch (request.url.path) {
        '/auth/v1/signup' => {'user': user()},
        '/auth/v1/token' => token(),
        '/auth/v1/user' => {'user': user()},
        _ => <String, dynamic>{},
      }),
      200,
    );
    client = SupabaseClient(
      'https://fixture.invalid',
      'fixture-public',
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryPkceStorage(),
      ),
      httpClient: MockClient((request) {
        requests.add(request);
        return handle(request);
      }),
    );
    session = SessionRepository(client);
    AppRepositories.session = session;
  });
  tearDown(() async {
    AppRepositories.session = previous;
    AppConfig.current = previousConfig;
    session.dispose();
    await client.dispose();
  });

  testWidgets(
    'no session exposes only Auth; sign in opens Home; logout destroys private back stack',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(AccountForm), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'password',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(requests.single.url.queryParameters['grant_type'], 'password');
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Private draft')),
        ),
      );
      await tester.pumpAndSettle();
      final logout = Completer<http.Response>();
      handle = (_) => logout.future;
      final signingOut = session.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Private draft'), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(AccountForm), findsOneWidget);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        isFalse,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsNothing);
      logout.complete(http.Response('{}', 204));
      await signingOut;
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'signup without session shows VerifyEmail until real confirmation event',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'password',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'password',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
      await tester.pumpAndSettle();
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.text(email), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(
        requests.single.url.queryParameters['redirect_to'],
        SessionRepository.redirectUrl,
      );
      await client.auth.getSessionFromUrl(
        Uri.parse('${SessionRepository.redirectUrl}?code=fixture-confirmation'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(VerifyEmailScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'recovery callback before repository creation takes priority; update returns to Home',
    (tester) async {
      await session.recover(email);
      expect(session.recoveringPassword, isFalse);
      await client.auth.getSessionFromUrl(
        Uri.parse('${SessionRepository.redirectUrl}?code=fixture-recovery'),
      );
      session.dispose();
      session = SessionRepository(client);
      AppRepositories.session = session;
      await session.initialize();
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      expect(session.recoveringPassword, isTrue);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.text('Nueva contraseña'), findsNWidgets(2));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'new-password',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'new-password',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Nueva contraseña'));
      await tester.pumpAndSettle();
      expect(session.recoveringPassword, isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(jsonDecode(requests.last.body)['password'], 'new-password');
      await session.signOut();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('new password cannot be opened with an ordinary session', (
    tester,
  ) async {
    await session.signIn(email, 'password');
    await expectLater(session.updatePassword('new-password'), throwsStateError);
    await tester.pumpWidget(
      const MaterialApp(home: AccountForm(mode: AccountMode.newPassword)),
    );
    expect(find.byType(TextFormField), findsNothing);
    expect(requests.length, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('expired startup snapshot shows initialization, never Home', (
    tester,
  ) async {
    session.dispose();
    await client.auth.setInitialSession(jsonEncode(token(expired: true)));
    session = SessionRepository(client);
    AppRepositories.session = session;
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed logout stays in Auth and displays its translated error', (
    tester,
  ) async {
    await session.signIn(email, 'password');
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    handle = (_) async => throw http.ClientException('offline');
    await expectLater(session.signOut(), throwsA(isA<AuthException>()));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(
      find.text('No podemos conectar. Revisa tu conexión.'),
      findsOneWidget,
    );
    expect(client.auth.currentSession, isNull);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final expired in [false, true]) {
    test(
      'restored ${expired ? "expired" : "valid"} Supabase session is admitted only when valid',
      () async {
        session.dispose();
        await client.auth.setInitialSession(
          jsonEncode(token(expired: expired)),
        );
        session = SessionRepository(client);
        if (expired) {
          expect(session.status, SessionStatus.initializing);
          expect(session.ownerId, isNull);
        }
        await session.initialize();
        await Future<void>.delayed(Duration.zero);
        expect(session.status, SessionStatus.authenticated);
        expect(requests.length, expired ? 1 : 0);
        if (expired) {
          expect(
            requests.single.url.queryParameters['grant_type'],
            'refresh_token',
          );
        }
      },
    );
  }

  test('unrefreshable restored session returns to Auth', () async {
    session.dispose();
    await client.auth.setInitialSession(jsonEncode(token(expired: true)));
    session = SessionRepository(client);
    handle = (_) async => http.Response(
      '{"code":"refresh_token_not_found","msg":"Invalid Refresh Token"}',
      400,
    );
    await session.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(session.status, SessionStatus.unauthenticated);
    expect(session.accessToken, isNull);
  });

  test(
    'resend is single flight and provider rate limits remain visible',
    () async {
      final response = Completer<http.Response>();
      handle = (_) => response.future;
      final first = session.resendConfirmation(email);
      await expectLater(
        session.resendConfirmation(email),
        throwsA(isA<AuthException>()),
      );
      response.complete(
        http.Response(
          '{"code":"over_email_send_rate_limit","msg":"Email rate limit exceeded"}',
          429,
        ),
      );
      await expectLater(first, throwsA(isA<AuthException>()));
      await expectLater(
        session.resendConfirmation(email),
        throwsA(isA<AuthException>()),
      );
      expect(requests.length, 1);
      expect(
        requests.single.url.queryParameters['redirect_to'],
        SessionRepository.redirectUrl,
      );
      expect(jsonDecode(requests.single.body)['type'], 'signup');
    },
  );

  test('pending-change protection runs before logout', () async {
    await session.signIn(email, 'password');
    session.beforeSignOut = () async => throw StateError('pending');
    await expectLater(session.signOut(), throwsStateError);
    expect(session.status, SessionStatus.authenticated);
    expect(requests.length, 1);
  });

  test(
    'auth errors translate provider codes, network errors and unknown failures',
    () {
      expect(
        authErrorMessage(
          const AuthException('safe', code: 'invalid_credentials'),
        ),
        'El email o la contraseña no son correctos.',
      );
      expect(
        authErrorMessage(const AuthException('Email not confirmed')),
        'Verifica tu correo antes de iniciar sesión.',
      );
      expect(
        authErrorMessage(const AuthException('safe', statusCode: '429')),
        'Has hecho demasiados intentos. Espera un momento.',
      );
      expect(
        authErrorMessage(const SocketException('offline')),
        'No podemos conectar. Revisa tu conexión.',
      );
      expect(
        authErrorMessage(http.ClientException('offline')),
        'No podemos conectar. Revisa tu conexión.',
      );
      expect(
        authErrorMessage(StateError('private-detail')),
        contains('AUTH_UNKNOWN'),
      );
      expect(
        authErrorMessage(StateError('private-detail')),
        isNot(contains('private-detail')),
      );
    },
  );

  test('debug diagnostics keep safe originals but never arbitrary secrets', () {
    final output = <String>[];
    final oldPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) output.add(message);
    };
    try {
      logAuthError(
        const AuthException(
          'Invalid login credentials',
          code: 'invalid_credentials',
        ),
        StackTrace.current,
      );
      logAuthError(
        const AuthException(
          'password=secret access_token=secret refresh_token=secret sb_secret_fixture',
        ),
        StackTrace.current,
      );
      expect(output.join(), contains('Invalid login credentials'));
      expect(output.join(), contains('invalid_credentials'));
      expect(output.join(), isNot(contains('secret')));
    } finally {
      debugPrint = oldPrint;
    }
  });
}
