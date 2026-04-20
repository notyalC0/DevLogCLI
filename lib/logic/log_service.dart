import 'package:devlogcli/core/database_helper.dart';

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
    values.add(log.id);

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

  List<String> getProjects() {
    final result = dataBaseHelper.select(
      'SELECT DISTINCT projeto FROM logs ORDER BY projeto ASC',
    );
    return result.map((row) => row['projeto'] as String).toList();
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

  // Retorna Map<'YYYY-MM-DD', {logs: int, minutos: int}> das últimas N semanas
  Map<String, Map<String, int>> getActivityByDay({int weeks = 12}) {
    final now = DateTime.now();
    final since = now.subtract(Duration(days: weeks * 7));
    final sinceStr =
        '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';

    final result = dataBaseHelper.select(
      '''SELECT
           substr(timestamp, 1, 10) AS day,
           COUNT(*) AS total_logs,
           COALESCE(SUM(duracao_minutos), 0) AS total_minutos
         FROM logs
         WHERE substr(timestamp, 1, 10) >= ?
         GROUP BY substr(timestamp, 1, 10)
         ORDER BY day ASC''',
      [sinceStr],
    );

    final map = <String, Map<String, int>>{};
    for (final row in result) {
      map[row['day'] as String] = {
        'logs': (row['total_logs'] as int),
        'minutos': (row['total_minutos'] as int),
      };
    }
    return map;
  }
}
