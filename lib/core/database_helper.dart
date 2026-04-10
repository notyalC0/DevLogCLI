import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

class DataBaseHelper {
  late Database _db;

  static String _getPath() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return '$home/.devlog/devlog.db';
  }

  void init() {
    final String dbFile = _getPath();
    Directory(dbFile).parent.createSync(recursive: true);

    _db = sqlite3.open(dbFile);

    _createSchema();
  }

  void initMemory() {
    _db = sqlite3.openInMemory();
    _createSchema();
  }

  void _createSchema() {
    _db.execute('''CREATE TABLE IF NOT EXISTS logs (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp        TEXT    NOT NULL,
  projeto          TEXT    NOT NULL,
  descricao        TEXT    NOT NULL,
  duracao_minutos  INTEGER,
  categoria        TEXT    NOT NULL,
  tipo             TEXT    NOT NULL,
  conteudo         TEXT,
  tags             TEXT
);''');
  }

  void execute(String sql, [List<Object?> params = const []]) {
    _db.execute(sql, params);
  }

  List<Map<String, dynamic>> select(
    String sql, [
    List<Object?> params = const [],
  ]) {
    return _db
        .select(sql, params)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  void close() {
    _db.dispose();
  }
}
