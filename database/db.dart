import 'package:sqlite3/sqlite3.dart';

int main() {
  final dbFile = 'devlog.db';

  final db = sqlite3.open(dbFile);

  print('banco de dados $dbFile conectado com sucesso!');

  db.execute('''CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY,
    message TEXT,
    timestamp TEXT,
    
    )''');

  return 0;
}
