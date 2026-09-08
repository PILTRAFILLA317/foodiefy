import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiefy/repositories/session_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemoryPkceStorage extends GotrueAsyncStorage {
  final Map<String, String> data = {};
  @override
  Future<String?> getItem({required String key}) async => data[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    data[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    data.remove(key);
  }
}

void main() {
  test(
    'registration awaiting email confirmation never becomes a session',
    () async {
      final client = SupabaseClient(
        'https://fixture.invalid',
        'fixture-public',
        authOptions: AuthClientOptions(
          pkceAsyncStorage: MemoryPkceStorage(),
          autoRefreshToken: false,
        ),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/auth/v1/signup');
          expect(
            request.url.queryParameters['redirect_to'],
            SessionRepository.redirectUrl,
          );
          expect(jsonDecode(request.body)['code_challenge'], isNotNull);
          return http.Response(
            jsonEncode({
              'user': {
                'id': '00000000-0000-4000-8000-0000000000a1',
                'aud': 'authenticated',
                'email': 'fixture@example.invalid',
                'created_at': '2026-09-08T00:00:00Z',
              },
            }),
            200,
          );
        }),
      );
      final session = SessionRepository(client);
      try {
        expect(
          await session.register('fixture@example.invalid', 'test-password'),
          isFalse,
        );
        expect(session.ownerId, isNull);
      } finally {
        session.dispose();
        await client.dispose();
      }
    },
  );
  test(
    'recovery uses the native callback and requires its session before updating',
    () async {
      var requests = 0;
      final client = SupabaseClient(
        'https://fixture.invalid',
        'fixture-public',
        authOptions: AuthClientOptions(
          pkceAsyncStorage: MemoryPkceStorage(),
          autoRefreshToken: false,
        ),
        httpClient: MockClient((request) async {
          requests++;
          expect(request.url.path, '/auth/v1/recover');
          expect(
            request.url.queryParameters['redirect_to'],
            SessionRepository.redirectUrl,
          );
          expect(jsonDecode(request.body)['code_challenge'], isNotNull);
          return http.Response('{}', 200);
        }),
      );
      final session = SessionRepository(client);
      try {
        await session.recover('fixture@example.invalid');
        expect(session.ownerId, isNull);
        await expectLater(
          session.updatePassword('new-password'),
          throwsStateError,
        );
        expect(requests, 1);
      } finally {
        session.dispose();
        await client.dispose();
      }
    },
  );
  test('unconfigured auth fails explicitly', () async {
    final session = SessionRepository(null);
    try {
      await expectLater(
        session.signIn('fixture@example.invalid', 'password'),
        throwsStateError,
      );
      expect(session.ownerId, isNull);
    } finally {
      session.dispose();
    }
  });
}
