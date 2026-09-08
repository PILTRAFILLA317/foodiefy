import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CloudGateway {
  Future<Map<String, dynamic>> snapshot(String owner);
  Future<Map<String, dynamic>> mutate(
    String owner,
    String operation,
    String kind,
    Map<String, dynamic> payload,
  );
  Future<void> upload(String owner, String path, Uint8List bytes, String mime);
  Future<String> imageUrl(String owner, String path);
}

class SupabaseGateway implements CloudGateway {
  SupabaseGateway(this.client);
  final SupabaseClient client;
  void _check(String owner) {
    if (client.auth.currentSession?.user.id != owner) {
      throw StateError('La sesión ha cambiado.');
    }
  }

  @override
  Future<Map<String, dynamic>> snapshot(String owner) async {
    _check(owner);
    final data = await client
        .rpc('library_snapshot_v1')
        .timeout(const Duration(seconds: 20));
    _check(owner);
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<Map<String, dynamic>> mutate(
    String owner,
    String operation,
    String kind,
    Map<String, dynamic> payload,
  ) async {
    _check(owner);
    final data = await client
        .rpc(
          'cloud_mutation_v1',
          params: {
            'p_operation_id': operation,
            'p_kind': kind,
            'p_payload': payload,
          },
        )
        .timeout(const Duration(seconds: 20));
    _check(owner);
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<void> upload(
    String owner,
    String path,
    Uint8List bytes,
    String mime,
  ) async {
    _check(owner);
    if (!path.startsWith('$owner/')) {
      throw StateError('Ruta de imagen no válida.');
    }
    await client.storage
        .from('recipe-images')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: mime),
        )
        .timeout(const Duration(seconds: 30));
    _check(owner);
  }

  @override
  Future<String> imageUrl(String owner, String path) async {
    _check(owner);
    if (!path.startsWith('$owner/')) {
      throw StateError('Ruta de imagen no válida.');
    }
    final url = await client.storage
        .from('recipe-images')
        .createSignedUrl(path, 3600)
        .timeout(const Duration(seconds: 10));
    _check(owner);
    return url;
  }
}
