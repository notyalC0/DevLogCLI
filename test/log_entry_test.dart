import 'package:DevLogCli/models/log_entry.dart';
import 'package:test/test.dart';

void main() {
  group('LogEntry', () {
    // ── Fixtures ────────────────────────────────────────────────────
    LogEntry makeEntry({
      int? id,
      String projeto = 'TestProject',
      String descricao = 'Descrição de teste',
      int? duracaoMinutos = 60,
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

    // ── toMap ────────────────────────────────────────────────────────
    group('toMap()', () {
      test('não inclui id por padrão', () {
        final entry = makeEntry(id: 42);
        final map = entry.toMap();
        expect(map.containsKey('id'), isFalse);
      });

      test('inclui id quando withId=true e id não é null', () {
        final entry = makeEntry(id: 42);
        final map = entry.toMap(withId: true);
        expect(map['id'], equals(42));
      });

      test('não inclui id quando withId=true mas id é null', () {
        final entry = makeEntry();
        final map = entry.toMap(withId: true);
        expect(map.containsKey('id'), isFalse);
      });

      test('mapeia todos os campos obrigatórios', () {
        final entry = makeEntry();
        final map = entry.toMap();
        expect(map['timestamp'], equals('2026-04-10T10:00:00.000'));
        expect(map['projeto'], equals('TestProject'));
        expect(map['descricao'], equals('Descrição de teste'));
        expect(map['duracao_minutos'], equals(60));
        expect(map['categoria'], equals('Feature'));
        expect(map['tipo'], equals('Código'));
      });

      test('campos nullable ficam null quando não fornecidos', () {
        final entry =
            makeEntry(duracaoMinutos: null, conteudo: null, tags: null);
        final map = entry.toMap();
        expect(map['duracao_minutos'], isNull);
        expect(map['conteudo'], isNull);
        expect(map['tags'], isNull);
      });

      test('inclui conteudo e tags quando fornecidos', () {
        final entry = makeEntry(
          conteudo: 'Este é o conteúdo',
          tags: 'sql,dart',
        );
        final map = entry.toMap();
        expect(map['conteudo'], equals('Este é o conteúdo'));
        expect(map['tags'], equals('sql,dart'));
      });
    });

    // ── fromMap ──────────────────────────────────────────────────────
    group('fromMap()', () {
      test('reconstrói todos os campos a partir do mapa', () {
        final original = makeEntry(
          id: 7,
          conteudo: 'Conteúdo rico',
          tags: 'dart,sqlite',
        );
        final map = original.toMap(withId: true);
        final restored = LogEntry.fromMap(map);

        expect(restored.id, equals(7));
        expect(restored.timestamp, equals(original.timestamp));
        expect(restored.projeto, equals(original.projeto));
        expect(restored.descricao, equals(original.descricao));
        expect(restored.duracaoMinutos, equals(original.duracaoMinutos));
        expect(restored.categoria, equals(original.categoria));
        expect(restored.tipo, equals(original.tipo));
        expect(restored.conteudo, equals(original.conteudo));
        expect(restored.tags, equals(original.tags));
      });

      test('round-trip toMap → fromMap preserva todos os campos', () {
        final entry = makeEntry(id: 1, tags: 'a,b,c', conteudo: 'texto');
        final restored = LogEntry.fromMap(entry.toMap(withId: true));
        expect(restored.toMap(withId: true), equals(entry.toMap(withId: true)));
      });

      test('aceita campos nullable como null', () {
        final map = {
          'id': 3,
          'timestamp': '2026-04-10T10:00:00.000',
          'projeto': 'X',
          'descricao': 'Y',
          'duracao_minutos': null,
          'categoria': 'Bugfix',
          'tipo': 'Código',
          'conteudo': null,
          'tags': null,
        };
        final entry = LogEntry.fromMap(map);
        expect(entry.duracaoMinutos, isNull);
        expect(entry.conteudo, isNull);
        expect(entry.tags, isNull);
      });
    });
  });
}
