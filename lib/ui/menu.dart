import 'dart:io';

import 'package:dart_console/dart_console.dart';

import '../core/database_helper.dart';
import '../core/theme.dart';
import '../logic/log_service.dart';
import '../models/log_entry.dart';
import 'components.dart';
import 'renderer.dart';

/// Ponto de entrada da UI: inicializa o banco e executa o loop de menu.
Future<void> runMenu() async {
  final scr = Screen.instance;
  final db = DataBaseHelper();
  db.init();

  final service = LogService(db);

  // Entra na tela alternativa — isola completamente a UI do histórico
  // do shell. Ao sair, o terminal volta ao estado original.
  scr.enterAlt();
  scr.hideCursor();

  bool running = true;
  while (running) {
    scr.clear();
    _printDashboard(service);

    const options = [
      ' Registrar atividade de código',
      ' Salvar aprendizado / solução',
      ' Buscar nos logs',
      ' Gerar relatório semanal',
      '󰈍 Exportar CSV',
      ' Sair',
    ];

    final choice = Draw.radioMenu(
      options,
      hotkeys: {'n': 0, 's': 1, '/': 2, 'r': 3, 'e': 4, 'q': 5},
      hints: {
        '↑↓': 'navegar',
        'ent': 'confirmar',
        '/': 'buscar',
        'r': 'relatório',
        'q': 'sair',
      },
    );

    switch (choice) {
      case 0:
        await _fluxoAtividade(service);
        break;
      case 1:
        await _fluxoAprendizado(service);
        break;
      case 2:
        _fluxoBusca(service);
        break;
      case 3:
        _fluxoRelatorio(service);
        break;
      case 4:
        _fluxoExportCSV(service);
        break;
      case 5:
        running = false;
        break;
    }
  }

  scr.clear();
  scr.showCursor();
  scr.exitAlt();

  // A mensagem de encerramento vai para o terminal real (fora do alt screen)
  stdout.writeln('\n${Theme.mauve}Até logo! DevLog encerrado.${Theme.reset}\n');
  db.close();
}

// ─── Dashboard ──────────────────────────────────────────────────────────────
//
// Layout (fiel à imagem de referência):
//
//   ╭──────────────────────────────────────────────────────────────╮
//   │ ◆ DEVLOG / notyalC              sex, 10 abr  10:09  │       │
//   │ ████████░░░░░░░░  N logs  ·  Xh Xm  ·  N projetos          │
//   ╰──────────────────────────────────────────────────────────────╯
//   ···············································
//
//   Último:  [Projeto] descrição...
//   Semana:  Feature ×2  ·  Bugfix ×1
//
//   ···············································
//
//   O QUE VAMOS REGISTRAR HOJE?
//
// (seguido pelo radioMenu interativo)

void _printDashboard(LogService service) {
  final all = service.getAll();
  final now = DateTime.now();

  // Logs da semana atual (seg–dom)
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final weekLogs = all.where((l) {
    final t = DateTime.tryParse(l.timestamp);
    return t != null &&
        !t.isBefore(DateTime(weekStart.year, weekStart.month, weekStart.day));
  }).toList();

  final totalMin = weekLogs.fold<int>(0, (s, l) => s + (l.duracaoMinutos ?? 0));
  final timeStr = _fmtDuration(totalMin);
  final projects = weekLogs
      .where((l) => l.tipo != 'Solução / Aprendizado')
      .map((l) => l.projeto)
      .toSet();

  // Stats para o header
  final stats = [
    StatCard(label: 'logs', value: '${weekLogs.length}', color: Theme.green),
    StatCard(label: 'tempo', value: timeStr, color: Theme.cyan),
    StatCard(
        label: 'projetos', value: '${projects.length}', color: Theme.mauve),
  ];

  // Header box (estilo da imagem)
  for (final line in Draw.headerLines(
    'DEVLOG / notyalC',
    stats,
    totalLogs: weekLogs.length,
    maxLogs: weekLogs.length > 0 ? (weekLogs.length * 2).clamp(1, 999) : 1,
  )) {
    stdout.writeln(line);
  }

  // Separador pontilhado
  stdout.writeln(Draw.dottedLine());
  stdout.writeln();

  // Último log registrado
  String lastStr;
  if (all.isNotEmpty) {
    final last = all.last;
    var desc = '[${last.projeto}] ${last.descricao}';
    final maxLen = Screen.instance.cols - 20;
    if (desc.length > maxLen) desc = '${desc.substring(0, maxLen - 3)}...';
    lastStr = '${Theme.text}$desc${Theme.reset}';
  } else {
    lastStr = Theme.dim('nenhum log ainda');
  }
  stdout.writeln(
    '  ${Theme.gold}◷${Theme.reset}  ${Theme.dim('Último:')}  $lastStr',
  );

  // Distribuição por categoria da semana
  final catCounts = <String, int>{};
  for (final l in weekLogs) {
    catCounts[l.categoria] = (catCounts[l.categoria] ?? 0) + 1;
  }
  final catLine = catCounts.isEmpty
      ? Theme.dim('sem logs esta semana')
      : catCounts.entries
          .map((e) =>
              '${_catColor(e.key)}${e.key}${Theme.reset} ${Theme.dim('×${e.value}')}')
          .join('  ${Theme.dim('·')}  ');
  stdout.writeln(
    '  ${Theme.gold}≡${Theme.reset}  ${Theme.dim('Semana:')}  $catLine',
  );

  // Segundo separador pontilhado
  stdout.writeln();
  stdout.writeln(Draw.dottedLine());
  stdout.writeln();

  // Subtítulo do menu
  stdout.writeln(
    '  ${Theme.dim('O QUE VAMOS REGISTRAR HOJE?')}',
  );
  stdout.writeln();
}

// ─── Fluxo: Registrar atividade de código ───────────────────────────────────

Future<void> _fluxoAtividade(LogService service) async {
  Screen.instance.clear();
  stdout.writeln(
      '\n${Theme.mauve}╭─ Nova Atividade ─────────────────────────────${Theme.reset}');
  stdout.writeln(Theme.dim('  :q = cancelar.\n'));

  final projeto = Draw.projectPicker(service.getProjects());
  if (projeto == null) {
    Draw.warn('Cancelado.');
    return;
  }

  final descricao = Draw.prompt('O que foi feito?', color: Theme.cyan);
  if (descricao == null) {
    Draw.warn('Cancelado.');
    return;
  }
  if (descricao.isEmpty) {
    Draw.warn('Descrição não pode ser vazia. Voltando ao menu.');
    _pause();
    return;
  }

  String? durStr;
  int? duracaoMinutos;
  do {
    durStr = Draw.prompt(
      'Duração (ex: 45m, 1h 30m) — vazio para pular:',
      color: Theme.gold,
    );
    if (durStr == null) {
      Draw.warn('Cancelado.');
      return;
    }
    if (durStr.isEmpty) break;
    duracaoMinutos = _parseDuration(durStr);
    if (duracaoMinutos == null)
      Draw.error('Formato inválido. Use "45m", "1h", "1h 30m".');
  } while (duracaoMinutos == null);

  stdout.writeln('\n${Theme.text}  Categoria:${Theme.reset}');
  final catIdx = Draw.radioMenu(kCategorias);
  if (catIdx == -1) {
    Draw.warn('Cancelado.');
    return;
  }

  stdout.writeln('${Theme.mauve}╰${'─' * 50}${Theme.reset}\n');

  final entry = LogEntry(
    timestamp: DateTime.now().toIso8601String(),
    projeto: projeto,
    descricao: descricao,
    duracaoMinutos: duracaoMinutos,
    categoria: kCategorias[catIdx],
    tipo: 'Código',
  );

  await Draw.spinner(
    Future.microtask(() => service.insert(entry)),
    'Salvando log no banco local...',
  );

  final all = service.getAll();
  final newId = all.isNotEmpty ? all.last.id ?? '?' : '?';
  Draw.success('Atividade registrada com sucesso! (ID: $newId)');
  _pause();
}

// ─── Fluxo: Salvar aprendizado/solução ──────────────────────────────────────

Future<void> _fluxoAprendizado(LogService service) async {
  Screen.instance.clear();
  stdout.writeln(
      '\n${Theme.mauve}╭─ Novo Aprendizado / Solução ─────────────────${Theme.reset}');
  stdout.writeln(Theme.dim('  :q = cancelar.\n'));

  final projeto = Draw.projectPicker(service.getProjects());
  if (projeto == null) {
    Draw.warn('Cancelado.');
    return;
  }

  final titulo = Draw.prompt('Título / resumo:', color: Theme.cyan);
  if (titulo == null) {
    Draw.warn('Cancelado.');
    return;
  }
  if (titulo.isEmpty) {
    Draw.warn('Título não pode ser vazio. Voltando ao menu.');
    _pause();
    return;
  }

  final conteudo = Draw.prompt(
    'Conteúdo / detalhes (Enter para encerrar):',
    color: Theme.cyan,
  );
  if (conteudo == null) {
    Draw.warn('Cancelado.');
    return;
  }

  final tags = Draw.prompt(
    'Tags separadas por vírgula (ex: sql, parser) — vazio para pular:',
    color: Theme.gold,
  );
  if (tags == null) {
    Draw.warn('Cancelado.');
    return;
  }

  stdout.writeln('${Theme.mauve}╰${'─' * 50}${Theme.reset}\n');

  final entry = LogEntry(
    timestamp: DateTime.now().toIso8601String(),
    projeto: projeto,
    descricao: titulo,
    categoria: 'Estudo',
    tipo: 'Solução / Aprendizado',
    conteudo: conteudo.isEmpty ? null : conteudo,
    tags: tags.isEmpty ? null : tags,
  );

  await Draw.spinner(
    Future.microtask(() => service.insert(entry)),
    'Salvando aprendizado no banco local...',
  );

  final all = service.getAll();
  final newId = all.isNotEmpty ? all.last.id ?? '?' : '?';
  Draw.success('Aprendizado registrado com sucesso! (ID: $newId)');
  _pause();
}

// ─── Fluxo: Busca ────────────────────────────────────────────────────────────

void _fluxoBusca(LogService service) {
  Draw.liveSearch(service.getAll(), service);
}

// ─── Fluxo: Relatório semanal ────────────────────────────────────────────────

void _fluxoRelatorio(LogService service) {
  Screen.instance.clear();

  final all = service.getAll();
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final weekLogs = all.where((l) {
    final t = DateTime.tryParse(l.timestamp);
    return t != null &&
        !t.isBefore(DateTime(weekStart.year, weekStart.month, weekStart.day));
  }).toList();

  if (weekLogs.isEmpty) {
    Draw.info('Nenhum log registrado esta semana.');
    _pause();
    return;
  }

  // Separa atividades de código e entradas de conhecimento
  final codeLogs =
      weekLogs.where((l) => l.tipo != 'Solução / Aprendizado').toList();
  final estudoLogs =
      weekLogs.where((l) => l.tipo == 'Solução / Aprendizado').toList();

  final totalMin = codeLogs.fold<int>(0, (s, l) => s + (l.duracaoMinutos ?? 0));

  final byProject = <String, int>{};
  for (final l in codeLogs) {
    byProject[l.projeto] =
        (byProject[l.projeto] ?? 0) + (l.duracaoMinutos ?? 0);
  }

  final byCat = <String, int>{};
  for (final l in codeLogs) {
    byCat[l.categoria] = (byCat[l.categoria] ?? 0) + 1;
  }

  final maxMin = byProject.values.fold(0, (a, b) => a > b ? a : b);

  // Tópicos da base de conhecimento (por tag)
  final tagCounts = <String, int>{};
  for (final l in estudoLogs) {
    for (final raw in (l.tags ?? '').split(',')) {
      final tag = raw.trim();
      if (tag.isNotEmpty) tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
    }
  }

  stdout.writeln();
  final lines = <String>[
    '${Theme.gold}Período:      ${Theme.reset}${Theme.text}Semana atual${Theme.reset}',
    '${Theme.gold}Total de logs:${Theme.reset}${Theme.text} ${weekLogs.length}${Theme.reset}  '
        '${Theme.dim('(${codeLogs.length} atividades · ${estudoLogs.length} estudos)')}',
    if (codeLogs.isNotEmpty)
      '${Theme.gold}Tempo (código):${Theme.reset}${Theme.text} ${_fmtDuration(totalMin)}${Theme.reset}',
    '',
    if (byProject.isNotEmpty) ...[
      '${Theme.mauve}Por projeto:${Theme.reset}',
      for (final e in byProject.entries) ...[
        '  ${Theme.text}${e.key}${Theme.reset}',
        '  ${_miniBar(e.value, maxMin)}  ${Theme.green}${_fmtDuration(e.value)}${Theme.reset}',
      ],
      '',
    ],
    if (byCat.isNotEmpty) ...[
      '${Theme.mauve}Por categoria:${Theme.reset}',
      for (final e in byCat.entries)
        '  ${_catColor(e.key)}${e.key}${Theme.reset}: '
            '${Theme.cyan}${e.value} log${e.value == 1 ? '' : 's'}${Theme.reset}',
      '',
    ],
    '${Theme.gold}◆ Base de conhecimento:${Theme.reset}',
    if (estudoLogs.isEmpty)
      '  ${Theme.dim('nenhum estudo esta semana')}'
    else ...[
      '  ${Theme.cyan}+${estudoLogs.length} entrada${estudoLogs.length == 1 ? '' : 's'} '
          'adicionada${estudoLogs.length == 1 ? '' : 's'}${Theme.reset}',
      if (tagCounts.isNotEmpty) ...[
        '',
        '  ${Theme.dim('Tópicos:')}',
        for (final e in tagCounts.entries)
          '  ${Theme.gold}·${Theme.reset}  ${Theme.text}${e.key}${Theme.reset}'
              '${e.value > 1 ? ' ${Theme.dim('×${e.value}')}' : ''}',
      ],
    ],
  ];

  Draw.box('Relatório Semanal', lines);
  Draw.hotkeyBar({'q': 'voltar'});

  Screen.instance.rawMode = true;
  Screen.instance.hideCursor();
  while (true) {
    final key = Screen.instance.readKey();
    if (key.isControl && key.controlChar == ControlCharacter.escape) break;
    if (!key.isControl &&
        (key.char == 'q' || key.char == '\n' || key.char == '\r')) break;
  }
  Screen.instance.rawMode = false;
  Screen.instance.showCursor();
}

/// Mini barra de progresso de texto para o relatório.
String _miniBar(int value, int max) {
  const barWidth = 20;
  final filled = max > 0 ? (value / max * barWidth).round() : 0;
  final empty = barWidth - filled;
  return '${Theme.green}${'█' * filled}${Theme.reset}${Theme.dim('░' * empty)}';
}

// ─── Fluxo: Exportar CSV ─────────────────────────────────────────────────────

void _fluxoExportCSV(LogService service) {
  Screen.instance.clear();
  final all = service.getAll();
  if (all.isEmpty) {
    Draw.warn('Nenhum log para exportar.');
    _pause();
    return;
  }

  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  final outPath = '$home/.devlog/devlog_export.csv';

  final buf = StringBuffer();
  buf.writeln(
      'id,timestamp,projeto,descricao,duracao_minutos,categoria,tipo,conteudo,tags');
  for (final l in all) {
    buf.writeln([
      l.id,
      l.timestamp,
      _csvCell(l.projeto),
      _csvCell(l.descricao),
      l.duracaoMinutos ?? '',
      _csvCell(l.categoria),
      _csvCell(l.tipo),
      _csvCell(l.conteudo ?? ''),
      _csvCell(l.tags ?? ''),
    ].join(','));
  }

  File(outPath).writeAsStringSync(buf.toString());
  Draw.success('CSV exportado → $outPath (${all.length} registros)');
  _pause();
}

String _csvCell(String s) {
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

// ─── Helpers ────────────────────────────────────────────────────────────────

/// Aguarda um Enter ou tecla antes de retornar ao menu.
/// Mantém a tela visível para o usuário ler o resultado.
void _pause() {
  stdout.write('\n${Theme.dim('  pressione Enter para continuar...')}');
  stdin.readLineSync();
}

String _catColor(String cat) {
  switch (cat.toLowerCase()) {
    case 'feature':
      return Theme.cyan;
    case 'bugfix':
      return Theme.pink;
    case 'estudo':
      return Theme.gold;
    case 'revisão':
    case 'revisao':
      return Theme.gold;
    case 'refatoração':
    case 'refatoracao':
      return Theme.mauve;
    case 'reunião':
    case 'reuniao':
      return Theme.mauve;
    case 'documentação':
    case 'documentacao':
      return Theme.text;
    case 'devops':
      return Theme.green;
    case 'experimento':
      return Theme.pink;
    default:
      return Theme.text;
  }
}

String _fmtDuration(int totalMinutes) {
  if (totalMinutes == 0) return '0m';
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

int? _parseDuration(String s) {
  s = s.trim().toLowerCase();
  final rHM = RegExp(r'^(\d+)h\s*(\d+)m$');
  final rH = RegExp(r'^(\d+)h$');
  final rM = RegExp(r'^(\d+)m$');
  final mHM = rHM.firstMatch(s);
  if (mHM != null)
    return int.parse(mHM.group(1)!) * 60 + int.parse(mHM.group(2)!);
  final mH = rH.firstMatch(s);
  if (mH != null) return int.parse(mH.group(1)!) * 60;
  final mM = rM.firstMatch(s);
  if (mM != null) return int.parse(mM.group(1)!);
  return null;
}
