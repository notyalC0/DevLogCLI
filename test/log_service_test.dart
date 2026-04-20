import 'package:devlogcli/core/database_helper.dart';
import 'package:devlogcli/logic/log_service.dart';
import 'package:devlogcli/models/log_entry.dart';
import 'package:test/test.dart';

DataBaseHelper _memDb() {
  final db = DataBaseHelper();
  db.initMemory();
  return db;
}

LogEntry _entry({
  int? id,
  String projeto = 'Projeto A',
  String descricao = 'Fez algo importante',
  int? duracaoMinutos = 45,
  String categoria = 'Feature',
  String tipo = 'Código',
  String? conteudo,
  String? tags,
  String? timestamp,
}) =>
    LogEntry(
      id: id,
      timestamp: timestamp ?? '2026-04-10T10:00:00.000',
      projeto: projeto,
      descricao: descricao,
      duracaoMinutos: duracaoMinutos,
      categoria: categoria,
      tipo: tipo,
      conteudo: conteudo,
      tags: tags,
    );

void main() {
  late DataBaseHelper db;
  late LogService service;

  setUp(() {
    db = _memDb();
    service = LogService(db);
  });

  tearDown(() => db.close());

  group('insert / getAll', () {
    test('banco começa vazio', () {
      expect(service.getAll(), isEmpty);
    });

    test('inserir um log retorna 1 item', () {
      service.insert(_entry());
      expect(service.getAll(), hasLength(1));
    });

    test('inserir múltiplos logs retorna todos', () {
      service.insert(_entry(projeto: 'A'));
      service.insert(_entry(projeto: 'B'));
      service.insert(_entry(projeto: 'C'));
      expect(service.getAll(), hasLength(3));
    });

    test('id é atribuído automaticamente após inserção', () {
      service.insert(_entry());
      final all = service.getAll();
      expect(all.first.id, isNotNull);
      expect(all.first.id, greaterThan(0));
    });

    test('campos nullable são preservados como null', () {
      service.insert(_entry(duracaoMinutos: null, conteudo: null, tags: null));
      final saved = service.getAll().first;
      expect(saved.duracaoMinutos, isNull);
      expect(saved.conteudo, isNull);
      expect(saved.tags, isNull);
    });
  });

  group('delete', () {
    test('remove o log pelo id', () {
      service.insert(_entry());
      final id = service.getAll().first.id!;
      service.delete(id);
      expect(service.getAll(), isEmpty);
    });

    test('não afeta outros logs ao deletar um', () {
      service.insert(_entry(projeto: 'A'));
      service.insert(_entry(projeto: 'B'));
      final idA = service.getAll().firstWhere((e) => e.projeto == 'A').id!;
      service.delete(idA);
      final remaining = service.getAll();
      expect(remaining, hasLength(1));
      expect(remaining.first.projeto, equals('B'));
    });

    test('deletar id inexistente não lança exceção', () {
      expect(() => service.delete(9999), returnsNormally);
    });
  });

  group('update', () {
    test('atualiza os campos corretamente', () {
      service.insert(_entry(projeto: 'Antes'));
      final saved = service.getAll().first;
      final updated = LogEntry(
        id: saved.id,
        timestamp: saved.timestamp,
        projeto: 'Depois',
        descricao: 'Nova descrição',
        duracaoMinutos: 90,
        categoria: 'Bugfix',
        tipo: saved.tipo,
      );
      service.update(updated);
      final refreshed = service.getAll().first;
      expect(refreshed.projeto, equals('Depois'));
      expect(refreshed.duracaoMinutos, equals(90));
    });

    test('lança ArgumentError quando id é null', () {
      expect(
        () => service.update(_entry()),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('search', () {
    setUp(() {
      service.insert(_entry(descricao: 'Implementou parser de SQL'));
      service.insert(_entry(descricao: 'Corrigiu bug no login', tags: 'auth'));
      service.insert(_entry(
        descricao: 'Estudou Dart records',
        tipo: 'Solução / Aprendizado',
        tags: 'dart,records',
      ));
    });

    test('retorna resultados por descrição', () {
      expect(service.search('parser'), hasLength(1));
    });

    test('busca é case-insensitive', () {
      expect(service.search('SQL'), hasLength(1));
      expect(service.search('sql'), hasLength(1));
    });

    test('retorna vazio para termo inexistente', () {
      expect(service.search('INEXISTENTE_XYZ'), isEmpty);
    });
  });

  group('filter', () {
    setUp(() {
      service.insert(_entry(projeto: 'Alpha', categoria: 'Feature'));
      service.insert(_entry(projeto: 'Alpha', categoria: 'Bugfix'));
      service.insert(_entry(projeto: 'Beta', categoria: 'Feature'));
    });

    test('filtra por projeto', () {
      expect(service.filter(projeto: 'Alpha'), hasLength(2));
    });

    test('filtra por categoria', () {
      expect(service.filter(categoria: 'Feature'), hasLength(2));
    });

    test('sem filtros retorna todos', () {
      expect(service.filter(), hasLength(3));
    });
  });

  group('getProjects', () {
    test('retorna vazio quando não há logs', () {
      expect(service.getProjects(), isEmpty);
    });

    test('retorna projetos distintos em ordem alfabética', () {
      service.insert(_entry(projeto: 'Zeta'));
      service.insert(_entry(projeto: 'Alpha'));
      service.insert(_entry(projeto: 'Alpha'));
      service.insert(_entry(projeto: 'Beta'));
      expect(service.getProjects(), equals(['Alpha', 'Beta', 'Zeta']));
    });
  });

  // ── getActivityByDay ──────────────────────────────────────────────
  group('getActivityByDay', () {
    test('retorna mapa vazio quando não há logs', () {
      expect(service.getActivityByDay(), isEmpty);
    });

    test('agrega logs do mesmo dia corretamente', () {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      service.insert(_entry(
        timestamp: '${dateStr}T09:00:00.000',
        duracaoMinutos: 30,
      ));
      service.insert(_entry(
        timestamp: '${dateStr}T14:00:00.000',
        duracaoMinutos: 60,
      ));

      final data = service.getActivityByDay();
      expect(data.containsKey(dateStr), isTrue);
      expect(data[dateStr]!['logs'], equals(2));
      expect(data[dateStr]!['minutos'], equals(90));
    });

    test('ignora logs mais antigos que o período', () {
      // Log de 100 dias atrás — fora das 12 semanas (84 dias)
      service.insert(_entry(
        timestamp: '2020-01-01T10:00:00.000',
        duracaoMinutos: 120,
      ));
      expect(service.getActivityByDay(), isEmpty);
    });

    test('logs sem duração contam como 0 minutos', () {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      service.insert(_entry(
        timestamp: '${dateStr}T10:00:00.000',
        duracaoMinutos: null,
      ));
      final data = service.getActivityByDay();
      expect(data[dateStr]!['minutos'], equals(0));
      expect(data[dateStr]!['logs'], equals(1));
    });

    test('dias diferentes ficam em chaves separadas', () {
      service.insert(_entry(timestamp: '2026-04-14T10:00:00.000'));
      service.insert(_entry(timestamp: '2026-04-15T10:00:00.000'));
      // Ambas dentro das 12 semanas a partir de hoje (2026-04-20)
      final data = service.getActivityByDay();
      expect(data.keys, containsAll(['2026-04-14', '2026-04-15']));
    });
  });
}
