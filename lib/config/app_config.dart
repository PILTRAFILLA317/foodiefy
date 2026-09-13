import 'dart:convert';
import 'package:flutter/foundation.dart';

enum AppEnvironment { local, staging, production }

class ConfigurationException implements Exception {
  const ConfigurationException(this.message);
  final String message;
}

class AppConfig {
  const AppConfig._({
    required this.environment,
    required this.rescueMode,
    this.apiBaseUrl,
    this.supabaseUrl,
    this.supabasePublicKey,
  });

  final AppEnvironment environment;
  final bool rescueMode;
  final Uri? apiBaseUrl;
  final Uri? supabaseUrl;
  final String? supabasePublicKey;

  static AppConfig current = const AppConfig._(
    environment: AppEnvironment.local,
    rescueMode: false,
  );

  factory AppConfig.fromEnvironment() => AppConfig.fromValues(const {
    'APP_ENV': String.fromEnvironment('APP_ENV', defaultValue: 'local'),
    'LOCAL_RESCUE': String.fromEnvironment(
      'LOCAL_RESCUE',
      defaultValue: 'false',
    ),
    'API_BASE_URL': String.fromEnvironment('API_BASE_URL'),
    'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
    'SUPABASE_PUBLISHABLE_KEY': String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
    'SUPABASE_ANON_KEY': String.fromEnvironment('SUPABASE_ANON_KEY'),
  }, release: kReleaseMode);

  factory AppConfig.fromValues(
    Map<String, String> values, {
    bool release = false,
  }) {
    final name = values['APP_ENV'] ?? 'local';
    final environment = AppEnvironment.values
        .where((e) => e.name == name)
        .firstOrNull;
    if (environment == null) {
      throw const ConfigurationException(
        'APP_ENV debe ser local, staging o production.',
      );
    }
    final rescue = values['LOCAL_RESCUE'] ?? 'false';
    if (rescue != 'true' && rescue != 'false') {
      throw const ConfigurationException('LOCAL_RESCUE debe ser true o false.');
    }
    if (release && environment == AppEnvironment.local ||
        rescue == 'true' && environment != AppEnvironment.local) {
      throw const ConfigurationException(
        'El modo de rescate solo está permitido en desarrollo local.',
      );
    }
    Uri? parseUrl(String key) {
      final raw = values[key]?.trim() ?? '';
      if (raw.isEmpty) return null;
      final uri = Uri.tryParse(raw);
      if (uri == null ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          (uri.scheme != 'https' &&
              !(uri.scheme == 'http' &&
                  environment == AppEnvironment.local &&
                  !release &&
                  _isLocalHost(uri.host)))) {
        throw ConfigurationException(
          '$key requiere HTTPS; HTTP solo se permite en direcciones locales de desarrollo.',
        );
      }
      return uri;
    }

    final api = parseUrl('API_BASE_URL');
    final supabase = parseUrl('SUPABASE_URL');
    final key = (values['SUPABASE_PUBLISHABLE_KEY']?.trim().isNotEmpty ?? false)
        ? values['SUPABASE_PUBLISHABLE_KEY']!.trim()
        : values['SUPABASE_ANON_KEY']?.trim();
    if (key != null && key.isNotEmpty && !_isPublicKey(key)) {
      throw const ConfigurationException(
        'Supabase requiere una clave pública publishable o anon; nunca un secreto de servidor.',
      );
    }
    if (rescue == 'false' && (supabase == null || key == null || key.isEmpty)) {
      throw const ConfigurationException(
        'Falta la configuración de acceso de Foodiefy. Revisa la configuración de la aplicación.',
      );
    }
    return AppConfig._(
      environment: environment,
      rescueMode: rescue == 'true',
      apiBaseUrl: api,
      supabaseUrl: supabase,
      supabasePublicKey: key,
    );
  }

  static bool _isPublicKey(String key) {
    if (key.startsWith('sb_publishable_')) {
      return key.length > 'sb_publishable_'.length;
    }
    try {
      final parts = key.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }

  static bool _isLocalHost(String host) {
    if (host == 'localhost' || host == '::1') return true;
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((n) => n == null || n < 0 || n > 255)) {
      return false;
    }
    return parts[0] == 127 ||
        parts[0] == 10 ||
        parts[0] == 192 && parts[1] == 168 ||
        parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31;
  }
}
