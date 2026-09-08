import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

/// Small SQL cache; cloud responses only. Quarantine is a separate database/file.
class LocalCache extends GeneratedDatabase {
  LocalCache(super.executor);
  static Future<LocalCache> open() async {
    final directory = await getApplicationSupportDirectory();
    return LocalCache(
      NativeDatabase.createInBackground(
        File('${directory.path}/cloud-cache.sqlite'),
      ),
    );
  }

  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(
        'CREATE TABLE cache (owner_id TEXT NOT NULL, cache_key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(owner_id, cache_key))',
      );
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA secure_delete = ON');
    },
  );

  Future<Map<String, dynamic>?> read(String owner, String key) async {
    final row = await customSelect(
      'SELECT value FROM cache WHERE owner_id=? AND cache_key=?',
      variables: [Variable(owner), Variable(key)],
    ).getSingleOrNull();
    return row == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(row.read<String>('value')));
  }

  Future<void> write(String owner, String key, Map<String, dynamic> value) =>
      customStatement(
        'INSERT OR REPLACE INTO cache(owner_id,cache_key,value) VALUES(?,?,?)',
        [owner, key, jsonEncode(value)],
      );
  Future<void> remove(String owner, String key) => customStatement(
    'DELETE FROM cache WHERE owner_id=? AND cache_key=?',
    [owner, key],
  );
  Future<void> clearOwner(String owner) =>
      customStatement('DELETE FROM cache WHERE owner_id=?', [owner]);
  Future<void> retainOnly(String? owner) => owner == null
      ? customStatement('DELETE FROM cache')
      : customStatement('DELETE FROM cache WHERE owner_id<>?', [owner]);
}
