import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

class DataBaseHelper {
  late Database db;

  static String _getPath() {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return '$home/.devlog/devlog.db';
  }

  void init() {
    final String dbFile = _getPath();
    Directory(dbFile).parent.createSync(recursive: true);
  
    db = sqlite3.open(dbFile);

    print('banco de dados $dbFile conectado com sucesso!');

    db.execute('''CREATE TABLE IF NOT EXISTS logs (
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
}
