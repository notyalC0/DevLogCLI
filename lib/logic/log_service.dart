import 'package:DevLogCli/core/database_helper.dart';

import '../models/log_entry.dart';

class LogService {
  final DataBaseHelper dataBaseHelper;
  LogService(this.dataBaseHelper);

  insert(LogEntry log) {
    final map = log.toMap();
    final columns = map.keys.join(', ');
    final placeholders = List.filled(map.length, '?').join(', ');
    final values = map.values.toList();

    dataBaseHelper.execute(
      'INSERT INTO logs ($columns) VALUES ($placeholders)',
      values,
    );
  }

  List<LogEntry> getAll() {
    final result = dataBaseHelper.select('SELECT * FROM logs');
    return result.map((row) => LogEntry.fromMap(row)).toList();
  }

  delete(int id) {
    dataBaseHelper.execute('DELETE FROM logs WHERE id = ?', [id]);
  }

  update(LogEntry log) {
    if (log.id == null)
      throw ArgumentError('LogEntry must have an id to update');
    final map = log.toMap(withId: true);
    final setClause =
        map.keys.where((k) => k != 'id').map((k) => '$k = ?').join(', ');
    final values =
        map.entries.where((e) => e.key != 'id').map((e) => e.value).toList();
    values.add(log.id); // id goes last for the WHERE clause

    dataBaseHelper.execute(
      'UPDATE logs SET $setClause WHERE id = ?',
      values,
    );
  }

  List<LogEntry> search(String query) {
    final result = dataBaseHelper.select(
      'SELECT * FROM logs WHERE descricao LIKE ? OR tags LIKE ?',
      ['%$query%', '%$query%'],
    );
    return result.map((row) => LogEntry.fromMap(row)).toList();
  }

  List<LogEntry> filter({String? projeto, String? categoria, String? tipo}) {
    final conditions = <String>[];
    final values = <dynamic>[];

    if (projeto != null) {
      conditions.add('projeto = ?');
      values.add(projeto);
    }
    if (categoria != null) {
      conditions.add('categoria = ?');
      values.add(categoria);
    }
    if (tipo != null) {
      conditions.add('tipo = ?');
      values.add(tipo);
    }

    final whereClause =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final result =
        dataBaseHelper.select('SELECT * FROM logs $whereClause', values);

    return result.map((row) => LogEntry.fromMap(row)).toList();
  }
}
