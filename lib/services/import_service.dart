import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../config/app_config.dart';
import '../repositories/app_repositories.dart';

class ImportRecipeException implements Exception {
  const ImportRecipeException(this.message, {required this.code});
  final String message;
  final String code;
  @override
  String toString() => message;
}

String importError(String code) => switch (code) {
  'unauthorized' => 'Inicia sesión de nuevo para continuar.',
  'disabled' =>
    'Configura cloud para importar; el rescate local es de solo lectura.',
  'source_unavailable' =>
    'No se puede acceder a la fuente. Puedes pegar su texto o receta.',
  'quota_exceeded' =>
    'Has alcanzado la cuota o ya tienes una importación activa.',
  'budget_exhausted' =>
    'El presupuesto está agotado o el procesamiento pagado está deshabilitado.',
  'duration_limit' => 'El contenido supera el límite de duración o tamaño.',
  'visual_required_unavailable' =>
    'Falta información visual. Pega las cantidades o pasos que aparecen en pantalla.',
  'invalid_output' =>
    'No se obtuvo un borrador válido. Revisa la fuente o pega la receta.',
  'idempotency_conflict' =>
    'Este intento ya tiene otro contenido. Crea un nuevo intento.',
  'canceled' => 'Importación cancelada.',
  'invalid_request' =>
    'Revisa el enlace o el tamaño del texto (máximo 6000 bytes).',
  _ =>
    'No se pudo conectar o confirmar la respuesta. Reintenta; se conservará el mismo intento.',
};

class ImportRecipeService {
  ImportRecipeService({
    http.Client? client,
    AppConfig? config,
    String? Function()? accessToken,
    Future<void> Function()? refresh,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _client =
           client ??
           IOClient(
             HttpClient()..connectionTimeout = const Duration(seconds: 5),
           ),
       _config = config ?? AppConfig.current,
       _token = accessToken ?? (() => AppRepositories.session.accessToken),
       _refresh =
           refresh ?? (() => AppRepositories.session.refreshAccessToken());
  final http.Client _client;
  final AppConfig _config;
  final String? Function() _token;
  final Future<void> Function() _refresh;
  final Duration requestTimeout;
  void close() => _client.close();

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? key,
  }) async {
    if (_config.rescueMode || _config.apiBaseUrl == null) {
      throw ImportRecipeException(importError('disabled'), code: 'disabled');
    }
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final token = _token();
        if (token == null) {
          throw const ImportRecipeException(
            'Inicia sesión para importar.',
            code: 'unauthorized',
          );
        }
        final base = _config.apiBaseUrl!;
        final uri = Uri.parse(
          '${base.toString().replaceFirst(RegExp(r'/+$'), '')}/v1/imports$path',
        );
        final req = http.Request(method, uri)..followRedirects = false;
        req.headers.addAll({
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (key != null) 'Idempotency-Key': key,
        });
        if (body != null) req.body = jsonEncode(body);
        final response = await (() async {
          final stream = await _client.send(req);
          final bytes = <int>[];
          await for (final chunk in stream.stream) {
            if (bytes.length + chunk.length > 2 * 1024 * 1024) {
              throw const FormatException();
            }
            bytes.addAll(chunk);
          }
          return http.Response.bytes(bytes, stream.statusCode);
        })().timeout(requestTimeout);
        if (response.statusCode == 401 && attempt == 0) {
          try {
            await _refresh().timeout(requestTimeout);
          } catch (_) {
            throw ImportRecipeException(
              importError('unauthorized'),
              code: 'unauthorized',
            );
          }
          continue;
        }
        Map<String, dynamic> data;
        try {
          data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
        } catch (_) {
          if (response.statusCode >= 200 && response.statusCode < 300) {
            throw const ImportRecipeException(
              'Respuesta inválida del servidor.',
              code: 'invalid_output',
            );
          }
          data = {};
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final code = response.statusCode == 401
              ? 'unauthorized'
              : (data['error'] is Map
                        ? data['error']['code'] as String?
                        : null) ??
                    'provider_down';
          throw ImportRecipeException(importError(code), code: code);
        }
        if (data['schema_version'] != '1.0') throw const FormatException();
        return data;
      }
      throw ImportRecipeException(
        importError('unauthorized'),
        code: 'unauthorized',
      );
    } on ImportRecipeException {
      rethrow;
    } on TimeoutException {
      throw ImportRecipeException(importError('timeout'), code: 'timeout');
    } on FormatException {
      throw ImportRecipeException(
        importError('invalid_output'),
        code: 'invalid_output',
      );
    } catch (_) {
      throw ImportRecipeException(importError('network'), code: 'network');
    }
  }

  Future<String> submit(Map<String, dynamic> payload, String key) async {
    final data = await request('POST', '', body: payload, key: key);
    final id = data['job_id'];
    if (id is! String || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      throw const ImportRecipeException(
        'Identificador inválido.',
        code: 'invalid_output',
      );
    }
    return id;
  }

  Future<Map<String, dynamic>> get(String id) => request('GET', '/$id');
  Future<Map<String, dynamic>> list({String? cursor}) => request(
    'GET',
    '?limit=1${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}',
  );
  Future<Map<String, dynamic>> cancel(String id) =>
      request('POST', '/$id/cancel');
}
