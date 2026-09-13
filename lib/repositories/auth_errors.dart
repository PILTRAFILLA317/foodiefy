import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

String authErrorMessage(Object error) {
  final auth = error is AuthException ? error : null;
  final message = auth?.message.toLowerCase() ?? '';
  final code = auth?.code;
  if (code == 'invalid_credentials' || message == 'invalid login credentials') {
    return 'El email o la contraseña no son correctos.';
  }
  if (code == 'email_not_confirmed' || message == 'email not confirmed') {
    return 'Verifica tu correo antes de iniciar sesión.';
  }
  if (auth?.statusCode == '429' ||
      (code?.contains('rate_limit') ?? false) ||
      message.contains('too many requests') ||
      message.contains('rate limit') ||
      message.contains('for security purposes')) {
    return 'Has hecho demasiados intentos. Espera un momento.';
  }
  if (error is SocketException ||
      error is http.ClientException ||
      error is TimeoutException ||
      error is AuthRetryableFetchException ||
      error is AuthUnknownException &&
          (error.originalError is SocketException ||
              error.originalError is http.ClientException ||
              error.originalError is TimeoutException)) {
    return 'No podemos conectar. Revisa tu conexión.';
  }
  return switch (code) {
    'weak_password' => 'Elige una contraseña más segura.',
    'same_password' => 'La nueva contraseña debe ser diferente de la anterior.',
    'email_address_invalid' ||
    'validation_failed' => 'Revisa el email y los datos introducidos.',
    'user_already_exists' ||
    'email_exists' => 'Ya existe una cuenta con ese email. Inicia sesión.',
    'otp_expired' || 'flow_state_expired' || 'flow_state_not_found' =>
      'El enlace ha caducado o ya se ha utilizado. Solicita uno nuevo.',
    _ =>
      'No se pudo completar la solicitud. Inténtalo de nuevo. (AUTH_UNKNOWN)',
  };
}

/// Arbitrary exception bodies can contain credentials or callback URLs.
/// Only known constant provider messages are retained verbatim.
void logAuthError(Object error, StackTrace stackTrace) {
  if (!kDebugMode) return;
  final auth = error is AuthException ? error : null;
  const safeMessages = {
    'Invalid login credentials',
    'Email not confirmed',
    'Email rate limit exceeded',
    'Request rate limit reached',
    'New password should be different from the old password.',
  };
  String safeCode(String? value) =>
      value != null && RegExp(r'^[a-zA-Z0-9_]{1,64}$').hasMatch(value)
      ? value
      : 'unavailable';
  debugPrint(
    'Auth type=${error.runtimeType} code=${safeCode(auth?.code)} '
    'status=${safeCode(auth?.statusCode)} '
    'message=${safeMessages.contains(auth?.message) ? auth!.message : "[detalle omitido por seguridad]"}',
  );
  debugPrintStack(stackTrace: stackTrace, maxFrames: 8);
}
