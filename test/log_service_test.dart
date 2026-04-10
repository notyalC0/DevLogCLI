import 'package:DevLogCli/core/database_helper.dart';
import 'package:DevLogCli/logic/log_service.dart';
import 'package:DevLogCli/models/log_entry.dart';
import 'package:test/test.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

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
}) =>
    LogEntry(
      id: id,
      timestamp: '2026-04-10T10:00:00.000',
      projeto: projeto,
      descricao: descricao,
      duracaoMinutos: duracaoMinutos,
      categoria: categoria,
      tipo: tipo,
      conteudo: conteudo,
      tags: tags,
    );

// ── Testes ───────────────────────────────────────────────────────────────────

void main() {
  late DataBaseHelper db;
  late LogService service;

  setUp(() {
    db = _memDb();
    service = LogService(db);
  });

  tearDown(() => db.close());

  // ── insert + getAll ───────────────────────────────────────────────
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

    test('campos conteudo e tags são preservados', () {
      service.insert(_entry(
        tipo: 'Solução / Aprendizado',
        conteudo: 'Descobri que X',
        tags: 'dart,sqlite',
      ));
      final saved = service.getAll().first;
      expect(saved.conteudo, equals('Descobri que X'));
      expect(saved.tags, equals('dart,sqlite'));
    });
  });

  // ── delete ────────────────────────────────────────────────────────
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

  // ── update ────────────────────────────────────────────────────────
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
      expect(refreshed.descricao, equals('Nova descrição'));
      expect(refreshed.duracaoMinutos, equals(90));
      expect(refreshed.categoria, equals('Bugfix'));
    });

    test('lança ArgumentError quando id é null', () {
      expect(
        () => service.update(_entry()),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('atualiza conteudo e tags em log de aprendizado', () {
      service.insert(_entry(
        tipo: 'Solução / Aprendizado',
        conteudo: 'Antes',
        tags: 'tag1',
      ));
      final saved = service.getAll().first;
      service.update(LogEntry(
        id: saved.id,
        timestamp: saved.timestamp,
        projeto: saved.projeto,
        descricao: saved.descricao,
        categoria: saved.categoria,
        tipo: saved.tipo,
        conteudo: 'Depois',
        tags: 'tag1,tag2',
      ));
      final refreshed = service.getAll().first;
      expect(refreshed.conteudo, equals('Depois'));
      expect(refreshed.tags, equals('tag1,tag2'));
    });
  });

  // ── search ────────────────────────────────────────────────────────
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
      final results = service.search('parser');
      expect(results, hasLength(1));
      expect(results.first.descricao, contains('parser'));
    });

    test('busca é case-insensitive', () {
      expect(service.search('SQL'), hasLength(1));
      expect(service.search('sql'), hasLength(1));
    });

    test('retorna resultados por tag', () {
      final results = service.search('auth');
      expect(results, hasLength(1));
      expect(results.first.tags, equals('auth'));
    });

    test('retorna vazio para termo inexistente', () {
      expect(service.search('INEXISTENTE_XYZ'), isEmpty);
    });

    test('termo vago retorna vários resultados', () {
      expect(service.search('a'), isNotEmpty);
    });
  });

  // ── filter ────────────────────────────────────────────────────────
  group('filter', () {
    setUp(() {
      service.insert(_entry(projeto: 'Alpha', categoria: 'Feature'));
      service.insert(_entry(projeto: 'Alpha', categoria: 'Bugfix'));
      service.insert(_entry(projeto: 'Beta', categoria: 'Feature'));
      service.insert(_entry(
        projeto: 'Gamma',
        categoria: 'Estudo',
        tipo: 'Solução / Aprendizado',
      ));
    });

    test('filtra por projeto', () {
      final results = service.filter(projeto: 'Alpha');
      expect(results, hasLength(2));
      expect(results.every((e) => e.projeto == 'Alpha'), isTrue);
    });

    test('filtra por categoria', () {
      final results = service.filter(categoria: 'Feature');
      expect(results, hasLength(2));
      expect(results.every((e) => e.categoria == 'Feature'), isTrue);
    });

    test('filtra por tipo', () {
      final results = service.filter(tipo: 'Solução / Aprendizado');
      expect(results, hasLength(1));
      expect(results.first.projeto, equals('Gamma'));
    });

    test('combina projeto + categoria', () {
      final results = service.filter(projeto: 'Alpha', categoria: 'Feature');
      expect(results, hasLength(1));
    });

    test('sem filtros retorna todos', () {
      expect(service.filter(), hasLength(4));
    });

    test('filtro sem match retorna lista vazia', () {
      expect(service.filter(projeto: 'Inexistente'), isEmpty);
    });
  });

  // ── getProjects ───────────────────────────────────────────────────
  group('getProjects', () {
    test('retorna vazio quando não há logs', () {
      expect(service.getProjects(), isEmpty);
    });

    test('retorna projetos distintos em ordem alfabética', () {
      service.insert(_entry(projeto: 'Zeta'));
      service.insert(_entry(projeto: 'Alpha'));
      service.insert(_entry(projeto: 'Alpha')); // duplicado
      service.insert(_entry(projeto: 'Beta'));

      final projects = service.getProjects();
      expect(projects, equals(['Alpha', 'Beta', 'Zeta']));
    });

    test('reflete inserções subsequentes', () {
      service.insert(_entry(projeto: 'P1'));
      expect(service.getProjects(), hasLength(1));
      service.insert(_entry(projeto: 'P2'));
      expect(service.getProjects(), hasLength(2));
    });

    test('projetos deletados não aparecem se não há mais logs deles', () {
      service.insert(_entry(projeto: 'Temporario'));
      final id =
          service.getAll().firstWhere((e) => e.projeto == 'Temporario').id!;
      service.delete(id);
      expect(service.getProjects(), isEmpty);
    });
  });
}
