import '../repositories/app_repositories.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:uuid/uuid.dart';

import '../config/app_config.dart';
import '../models/recipe.dart';

class ImportRecipeService {
  ImportRecipeService({
    http.Client? client,
    String? Function()? accessToken,
    AppConfig? config,
    this.requestTimeout = const Duration(seconds: 30),
    Duration connectionTimeout = const Duration(seconds: 5),
  }) : _client =
           client ??
           IOClient(HttpClient()..connectionTimeout = connectionTimeout),
       _config = config ?? AppConfig.current,
       _accessToken =
           accessToken ??
           (() => AppRepositories
               .session
               .client
               ?.auth
               .currentSession
               ?.accessToken);

  final String? Function() _accessToken;
  final http.Client _client;
  final AppConfig _config;
  final Duration requestTimeout;

  void close() => _client.close();

  Future<Recipe> importRecipeFromUrl(String url) async {
    if (_config.rescueMode) {
      throw ImportRecipeException(
        'Importación cloud deshabilitada en rescate local.',
        code: 'disabled',
      );
    }
    final token = _accessToken();
    if (token == null) {
      throw ImportRecipeException(
        'Inicia sesión antes de importar.',
        code: 'unauthorized',
      );
    }
    final source = Uri.tryParse(url);
    if (source == null ||
        source.host.isEmpty ||
        source.userInfo.isNotEmpty ||
        !['http', 'https'].contains(source.scheme)) {
      throw ImportRecipeException(
        'Ingresa un enlace HTTP(S) válido.',
        code: 'invalid_url',
      );
    }
    try {
      final base = _config.apiBaseUrl!;
      final uri = base.replace(
        path:
            '${base.path.replaceFirst(RegExp(r"/+$"), "")}/api/analyze-recipe',
      );
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'url': url}),
          )
          .timeout(requestTimeout);
      if (response.statusCode != 200) {
        final code = switch (response.statusCode) {
          401 || 403 => 'unauthorized',
          429 => 'rate_limited',
          503 => 'unavailable',
          _ => 'http_error',
        };
        throw ImportRecipeException(
          'La API no pudo importar la receta (HTTP ${response.statusCode}).',
          code: code,
        );
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw ImportRecipeException(
          'La API devolvió un formato inválido.',
          code: 'invalid_payload',
        );
      }
      if (body['success'] == false) {
        throw ImportRecipeException(
          'El servidor no pudo extraer la receta.',
          code: 'remote_failure',
        );
      }
      final data = body['recipe'];
      if (body['success'] != true ||
          data is! Map<String, dynamic> ||
          data['titulo'] is! String ||
          (data['titulo'] as String).trim().isEmpty ||
          !_validList(data['ingredientes']) ||
          !_validList(data['pasos'])) {
        throw ImportRecipeException(
          'La API devolvió una receta incompleta.',
          code: 'invalid_payload',
        );
      }
      return _mapRecipeFromApi(data, sourceUrl: url);
    } on ImportRecipeException {
      rethrow;
    } on TimeoutException {
      _client.close();
      throw ImportRecipeException(
        'La solicitud agotó el tiempo de espera.',
        code: 'timeout',
      );
    } on SocketException {
      throw ImportRecipeException(
        'No se pudo conectar con la API.',
        code: 'network',
      );
    } on http.ClientException {
      throw ImportRecipeException(
        'No se pudo conectar con la API.',
        code: 'network',
      );
    } on FormatException {
      throw ImportRecipeException(
        'La API devolvió JSON inválido.',
        code: 'invalid_json',
      );
    } on TypeError {
      throw ImportRecipeException(
        'La API devolvió campos inválidos.',
        code: 'invalid_payload',
      );
    }
  }

  bool _validList(dynamic value) =>
      value is List &&
      value.isNotEmpty &&
      value.every((entry) => entry is String && entry.trim().isNotEmpty);

  Recipe _mapRecipeFromApi(Map<String, dynamic> recipe, {String? sourceUrl}) {
    // A new local recipe owns its identity; provider IDs are not local IDs.
    final id = const Uuid().v4();
    final title = recipe['titulo'] as String? ?? 'Receta importada';
    final description = recipe['descripcion'] as String?;
    final ingredients = _stringListFromDynamic(recipe['ingredientes']);
    final steps = _stringListFromDynamic(recipe['pasos']);
    final prepTimeText = recipe['tiempo_preparacion'] as String?;
    final prepTime = _parsePrepTime(prepTimeText);
    final imageUrl = recipe['imagen'] as String?;
    final originalUrl = recipe['url'] as String?;
    final uploader = recipe['uploader'] as String?;
    final platform = recipe['platform'] as String?;
    final thumbnail = recipe['thumbnail'] as String?;
    final finalQuantity =
        recipe['cantidad_final'] as String? ?? 'No especificado';
    final macronutrients = _parseMacronutrients(
      recipe['macronutrientes'] as Map<String, dynamic>?,
    );

    return Recipe(
      id: id,
      title: title,
      description: description,
      ingredients: ingredients,
      steps: steps,
      imagePath: imageUrl ?? thumbnail,
      originalVideoUrl: originalUrl,
      sourceUrl: sourceUrl ?? originalUrl,
      isImported: true,
      isPublic: false,
      prepTimeMinutes: prepTime,
      prepTimeText: prepTimeText,
      uploader: uploader,
      platform: platform,
      thumbnailUrl: thumbnail,
      finalQuantity: finalQuantity,
      macronutrients: macronutrients,
      createdAt: DateTime.now(),
    );
  }

  List<String> _stringListFromDynamic(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return const [];
  }

  int? _parsePrepTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final match = RegExp(r'(\d{1,3})').firstMatch(value);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  RecipeMacronutrients? _parseMacronutrients(Map<String, dynamic>? data) {
    if (data == null) return null;
    try {
      final macros = RecipeMacronutrients.fromJson(data);
      return macros.hasAnyValue ? macros : null;
    } catch (_) {
      return null;
    }
  }
}

class ImportRecipeException implements Exception {
  ImportRecipeException(this.message, {required this.code});
  final String message;
  final String code;
  @override
  String toString() => message;
}
