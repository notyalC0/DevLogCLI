import 'dart:async';
import 'dart:io';

import 'package:dart_console/dart_console.dart';

import '../core/theme.dart';
import '../logic/log_service.dart';
import '../models/log_entry.dart';
import 'renderer.dart';

/// Categorias disponíveis para qualquer log de atividade.
const kCategorias = [
  'Feature',
  'Refatoração',
  'Bugfix',
  'Documentação',
  'DevOps',
  'Revisão',
  'Reunião',
  'Experimento',
  'Estudo',
];

// ─── StatCard ─────────────────────────────────────────────────────────────────

/// Métrica rápida exibida na barra de stats do header.
///
/// Dart 2.x: classe simples.
/// Dart 3+ (quando migrar): pode trocar por record inline.
class StatCard {
  final String label;
  final String value;
  final String color;
  const StatCard(
      {required this.label, required this.value, required this.color});
}

// ─── Draw ─────────────────────────────────────────────────────────────────────

abstract class Draw {
  static final _scr = Screen.instance;

  // ─── Utilitários visuais ────────────────────────────────────────

  /// Comprimento visual de [s] (ignora escape codes ANSI).
  static int vis(String s) =>
      s.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '').length;

  /// Padding à direita até [width] colunas visuais.
  static String rpad(String s, int width) {
    final diff = width - vis(s);
    return diff > 0 ? '$s${' ' * diff}' : s;
  }

  /// Centraliza [s] dentro de [width] colunas visuais.
  static String center(String s, int width) {
    final v = vis(s);
    final l = ((width - v) / 2).floor();
    final r = width - v - l;
    return '${' ' * l}$s${' ' * r}';
  }

  // ─── Raw mode ───────────────────────────────────────────────────

  static void _enterRaw() {
    _scr.rawMode = true;
    _scr.hideCursor();
  }

  static void _exitRaw() {
    _scr.rawMode = false;
    _scr.showCursor();
  }

  // ─── Separador pontilhado ───────────────────────────────────────
  //
  // Produz uma linha de pontos cobrindo toda a largura do terminal.
  // Idêntico ao separador da imagem de referência.

  static String dottedLine([int? width]) {
    final w = (width ?? _scr.cols).clamp(20, 200);
    return Theme.dim('·' * w);
  }

  // ─── Header box ─────────────────────────────────────────────────
  //
  // Estrutura (inspirada na imagem de referência):
  //
  //   ╭──────────────────────────────────────────────╮
  //   │ ◆ DEVLOG              sex, 10 abr  10:09  │  │
  //   │ ████████░░░░░  5 logs  ·  3h 20m  ·  2 proj  │
  //   ╰──────────────────────────────────────────────╯
  //
  // Retorna as linhas prontas para stdout — não escreve diretamente,
  // facilitando composição num frame completo.

  static List<String> headerLines(String appName, List<StatCard> stats,
      {int? totalLogs, int? maxLogs}) {
    final w = _scr.cols;
    final inner = w - 2; // espaço entre │ e │

    // ── Linha 1: título + datetime + divisor ──
    final now = DateTime.now();
    const days = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
    const months = [
      '',
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez'
    ];
    final dayName = days[now.weekday - 1];
    final dateFmt =
        '$dayName, ${now.day.toString().padLeft(2, '0')} ${months[now.month]}';
    final timeFmt =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final titleLeft = ' ${Theme.mauve}◆${Theme.reset} ${Theme.bold(appName)}';
    final dateRight =
        '${Theme.dim('$dateFmt  $timeFmt')}  ${Theme.mauve}│${Theme.reset}  ';
    final titleLeftVis = vis(titleLeft);
    final dateRightVis = vis(dateRight);
    final gapTitle = (inner - titleLeftVis - dateRightVis).clamp(1, inner);
    final titleLine =
        '${Theme.mauve}│${Theme.reset}$titleLeft${' ' * gapTitle}$dateRight${Theme.mauve}│${Theme.reset}';

    // ── Linha 2: barra de progresso + stats ──
    const barLen = 20;
    final n = totalLogs ?? 0;
    final maxN = (maxLogs != null && maxLogs > 0) ? maxLogs : (n > 0 ? n : 1);
    final filled = (n / maxN * barLen).round().clamp(0, barLen);
    final empty = barLen - filled;
    final bar =
        '${Theme.green}${'█' * filled}${Theme.reset}${Theme.dim('░' * empty)}';

    final statStr = stats
        .map((s) => '${s.color}${s.value}${Theme.reset} ${Theme.dim(s.label)}')
        .join('  ${Theme.dim('·')}  ');
    final statsLine = '${Theme.mauve}│${Theme.reset} $bar  $statStr';
    final statsVis = vis(statsLine);
    final statsPad = (inner - statsVis + 1).clamp(0, inner);
    final statsLineF =
        '$statsLine${' ' * statsPad}${Theme.mauve}│${Theme.reset}';

    return [
      '${Theme.mauve}╭${'─' * inner}╮${Theme.reset}',
      titleLine,
      statsLineF,
      '${Theme.mauve}╰${'─' * inner}╯${Theme.reset}',
    ];
  }

  // ─── Radio menu (redesenhado) ───────────────────────────────────
  //
  // Estilo da imagem:
  //   ▶ ◉   Opção selecionada                  hotkey
  //     ○   Opção normal                       hotkey
  //
  // Cada opção ocupa 1 linha + 1 linha em branco.

  static int radioMenu(
    List<String> options, {
    int initial = 0,
    Map<String, int>? hotkeys,
    Map<String, String>? hints,
  }) {
    assert(options.isNotEmpty);
    int selected = initial.clamp(0, options.length - 1);

    final indexToKey = <int, String>{};
    if (hotkeys != null) {
      for (final e in hotkeys.entries) {
        indexToKey[e.value] = e.key;
      }
    }

    // Cada opção = 1 linha de conteúdo + 1 linha em branco.
    // Hints = 1 linha de conteúdo + 1 linha em branco.
    final totalLines = options.length * 2 + (hints != null ? 2 : 0);

    void render(bool first) {
      if (!first) _scr.up(totalLines);
      final w = _scr.cols;

      for (int i = 0; i < options.length; i++) {
        final isSel = i == selected;

        // Marcador: "▶ ◉" ou "  ○"
        final marker = isSel
            ? '${Theme.green}▶ ◉${Theme.reset}'
            : '  ${Theme.mauve}○${Theme.reset}';

        // Label colorido para selecionado, dim para os outros
        final label = isSel
            ? '${Theme.text}${options[i]}${Theme.reset}'
            : Theme.dim(options[i]);

        // vis do marcador raw = 3 chars ("▶ ◉" ou "  ○")
        // + "  " prefix + "  " entre marker e label = 4 + 3 + 2 = ~9 prefix
        final labelVisLen = vis(options[i]) + 9;

        stdout.write('\x1B[2K');
        if (indexToKey.containsKey(i)) {
          final keyChar = indexToKey[i]!;
          final padLen = (w - labelVisLen - 2).clamp(0, w);
          stdout
              .writeln('  $marker  $label${' ' * padLen}${Theme.dim(keyChar)}');
        } else {
          stdout.writeln('  $marker  $label');
        }
        stdout.write('\x1B[2K\n'); // linha em branco
      }

      if (hints != null) {
        stdout.write('\x1B[2K');
        stdout.writeln(hotkeyBarLine(hints));
        stdout.write('\x1B[2K\n');
      }
    }

    _enterRaw();
    render(true);

    while (true) {
      final key = _scr.readKey();
      if (key.isControl) {
        switch (key.controlChar) {
          case ControlCharacter.arrowUp:
            if (selected > 0) {
              selected--;
              render(false);
            }
            break;
          case ControlCharacter.arrowDown:
            if (selected < options.length - 1) {
              selected++;
              render(false);
            }
            break;
          case ControlCharacter.enter:
            _exitRaw();
            return selected;
          case ControlCharacter.escape:
            _exitRaw();
            return -1;
          default:
            break;
        }
      } else {
        final ch = key.char.toLowerCase();
        if (hotkeys != null && hotkeys.containsKey(ch)) {
          _exitRaw();
          return hotkeys[ch]!;
        }
      }
    }
  }

  // ─── Barra de atalhos ────────────────────────────────────────────
  //
  // Estilo da imagem: "↑↓ navegar  ent confirmar  q sair"
  // Sem colchetes — chave em verde, ação em dim.

  static void hotkeyBar(Map<String, String> shortcuts) {
    stdout.writeln('\n${hotkeyBarLine(shortcuts)}\n');
  }

  static String hotkeyBarLine(Map<String, String> shortcuts) {
    final parts = shortcuts.entries
        .map(
            (e) => '${Theme.green}${e.key}${Theme.reset} ${Theme.dim(e.value)}')
        .join('  ');
    return ' $parts';
  }

  // ─── Prompt ──────────────────────────────────────────────────────

  /// Lê uma linha do usuário com echo visível.
  /// Retorna [null] se o usuário digitar `:q` (cancelar fluxo).
  static String? prompt(String question, {String color = Theme.pink}) {
    _exitRaw();
    stdout.write(
      '\n$color? ${Theme.reset}${Theme.text}$question${Theme.reset}\n'
      '${Theme.green}❯${Theme.reset} ',
    );
    final val = Screen.instance.readLine() ?? '';
    if (val.trim() == ':q') return null;
    return val;
  }

  // ─── Caixa unicode ───────────────────────────────────────────────

  static void box(String title, List<String> content) {
    final maxW = _scr.cols - 4;
    int inner = 56.clamp(0, maxW);
    for (final line in content) {
      final len = vis(line) + 4;
      if (len > inner) inner = len.clamp(0, maxW);
    }

    final titleStr = ' $title ';
    final dashes = '─' * (inner - titleStr.length - 1);
    stdout.writeln(
        '${Theme.mauve}╭─${Theme.pink}$titleStr${Theme.mauve}$dashes╮${Theme.reset}');
    stdout.writeln('${Theme.mauve}│${' ' * inner}│${Theme.reset}');
    for (final line in content) {
      stdout.writeln(
        '${Theme.mauve}│${Theme.reset}  ${rpad(line, inner - 2)}${Theme.mauve}│${Theme.reset}',
      );
    }
    stdout.writeln('${Theme.mauve}│${' ' * inner}│${Theme.reset}');
    stdout.writeln('${Theme.mauve}╰${'─' * inner}╯${Theme.reset}');
  }

  // ─── Badge ───────────────────────────────────────────────────────

  static String badge(String text) =>
      '${Theme.mauve}[${Theme.reset}${Theme.cyan}$text${Theme.reset}${Theme.mauve}]${Theme.reset}';

  static String badgeColored(String text, String color) =>
      '${Theme.mauve}[${Theme.reset}$color$text${Theme.reset}${Theme.mauve}]${Theme.reset}';

  // ─── Log list ────────────────────────────────────────────────────

  static void logList(List<LogEntry> entries, {String title = 'Resultados'}) {
    if (entries.isEmpty) {
      info('Nenhum resultado encontrado.');
      return;
    }

    int selected = 0;

    void render() {
      _scr.clear();
      stdout.writeln();
      stdout.writeln(
        '  ${Theme.pink}◆${Theme.reset} ${Theme.text}$title${Theme.reset}  '
        '${Theme.dim('(${entries.length} item${entries.length == 1 ? '' : 's'})')}',
      );
      stdout.writeln();
      stdout.writeln(dottedLine());
      stdout.writeln();
      for (int i = 0; i < entries.length; i++) {
        _logRow(entries[i], i == selected);
      }
      stdout.writeln(dottedLine());
      hotkeyBar({'↑ ↓': 'navegar', 'ent': 'detalhes', 'q': 'voltar'});
    }

    render();
    _enterRaw();

    outerLoop:
    while (true) {
      final key = _scr.readKey();
      if (key.isControl) {
        switch (key.controlChar) {
          case ControlCharacter.arrowUp:
            if (selected > 0) {
              selected--;
              render();
            }
            break;
          case ControlCharacter.arrowDown:
            if (selected < entries.length - 1) {
              selected++;
              render();
            }
            break;
          case ControlCharacter.enter:
            _exitRaw();
            logDetail(entries[selected]);
            _enterRaw();
            render();
            break;
          case ControlCharacter.escape:
            break outerLoop;
          default:
            break;
        }
      } else {
        switch (key.char.toLowerCase()) {
          case 'd':
          case 'q':
            break outerLoop;
        }
      }
    }

    _exitRaw();
    _scr.clear();
  }

  // ─── Linha de log (list + search) ────────────────────────────────
  //
  // Formato:
  //   ▶ ●  [projeto]  ·  descrição…                categoria  dd mmm
  //   (linha em branco)

  static void _logRow(LogEntry e, bool selected) {
    final w = _scr.cols;
    final arrow = selected ? '${Theme.green}▶${Theme.reset}' : ' ';
    final dot = selected
        ? '${Theme.green}●${Theme.reset}'
        : '${Theme.mauve}○${Theme.reset}';
    final proj = selected
        ? '${Theme.green}${e.projeto}${Theme.reset}'
        : '${Theme.mauve}${e.projeto}${Theme.reset}';
    final catColor = _catColor(e.categoria);
    final cat = '$catColor${e.categoria}${Theme.reset}';
    final date = Theme.dim(_formatDate(e.timestamp));
    final dur = e.duracaoMinutos != null
        ? '  ${Theme.gold}${_fmtDuration(e.duracaoMinutos!)}${Theme.reset}'
        : '';

    final rawDesc = e.descricao.length > 42
        ? '${e.descricao.substring(0, 39)}...'
        : e.descricao;
    final desc =
        selected ? '${Theme.text}$rawDesc${Theme.reset}' : Theme.dim(rawDesc);

    final left = ' $arrow $dot  $proj${Theme.dim(' · ')}$desc';
    final right = '$cat  $date$dur';
    final gap = (w - vis(left) - vis(right) - 2).clamp(1, w);

    stdout.writeln('$left${' ' * gap}$right');
    stdout.writeln(); // espaço entre itens
  }

  // ─── Live search ─────────────────────────────────────────────────

  static void liveSearch(List<LogEntry> allEntries, LogService service) {
    if (allEntries.isEmpty) {
      info('Nenhum log registrado ainda.');
      return;
    }

    var entries = allEntries; // local mutável para refresh após edit/delete
    var query = '';
    var selected = 0;
    final inputW = (_scr.cols - 8).clamp(30, 60);

    List<LogEntry> doFilter(String q) {
      if (q.isEmpty) return entries;
      final lower = q.toLowerCase();
      return entries.where((e) {
        return e.descricao.toLowerCase().contains(lower) ||
            e.projeto.toLowerCase().contains(lower) ||
            e.categoria.toLowerCase().contains(lower) ||
            (e.tags?.toLowerCase().contains(lower) ?? false) ||
            (e.conteudo?.toLowerCase().contains(lower) ?? false);
      }).toList();
    }

    void render(List<LogEntry> filtered) {
      _scr.clear();
      stdout.writeln();

      final cursor = '${Theme.green}▌${Theme.reset}';
      final inputText = query.isEmpty
          ? Theme.dim('buscar logs...')
          : '${Theme.text}$query${Theme.reset}$cursor';
      final rawLen = query.isEmpty ? 14 : query.length + 1;
      final fillLen = (inputW - rawLen - 2).clamp(0, inputW);

      stdout.writeln(
          '  ${Theme.pink}◆${Theme.reset} ${Theme.text}Busca${Theme.reset}');
      stdout.writeln();
      stdout.writeln('  ${Theme.mauve}╭${'─' * inputW}╮${Theme.reset}');
      stdout.writeln(
          '  ${Theme.mauve}│${Theme.reset} $inputText${' ' * fillLen} ${Theme.mauve}│${Theme.reset}');
      stdout.writeln('  ${Theme.mauve}╰${'─' * inputW}╯${Theme.reset}');
      stdout.writeln();
      stdout.writeln(dottedLine());
      stdout.writeln();

      if (filtered.isEmpty) {
        if (query.isNotEmpty) {
          stdout.writeln(
            '  ${Theme.dim('Nenhum resultado para ')}'
            '"${Theme.text}$query${Theme.reset}${Theme.dim('"')}',
          );
          stdout.writeln();
        }
      } else {
        final show = filtered.take(8).toList();
        for (int i = 0; i < show.length; i++) {
          _logRow(show[i], i == selected);
        }
        if (filtered.length > 8) {
          stdout.writeln(
            '  ${Theme.dim('... e mais ${filtered.length - 8} resultado(s).')}',
          );
          stdout.writeln();
        }
      }

      stdout.writeln(
        '  ${Theme.dim('↳  Enter no resultado → detalhe  ·  editar e deletar disponíveis no detalhe')}',
      );
      stdout.writeln();
      stdout.writeln(dottedLine());
      hotkeyBar({
        '↑↓': 'navegar',
        'ent': 'detalhes',
        'q': 'voltar',
      });
    }

    _enterRaw();
    var filtered = doFilter(query);
    render(filtered);

    outerLoop:
    while (true) {
      final key = _scr.readKey();
      if (key.isControl) {
        switch (key.controlChar) {
          case ControlCharacter.arrowUp:
            if (selected > 0) {
              selected--;
              render(filtered);
            }
            break;
          case ControlCharacter.arrowDown:
            final lim = filtered.length < 8 ? filtered.length : 8;
            if (selected < lim - 1) {
              selected++;
              render(filtered);
            }
            break;
          case ControlCharacter.enter:
            if (filtered.isNotEmpty) {
              _exitRaw();
              final deleted = logDetail(filtered[selected], service: service);
              if (deleted) {
                entries = service.getAll();
                filtered = doFilter(query);
                selected =
                    selected.clamp(0, (filtered.length - 1).clamp(0, 9999));
              }
              _enterRaw();
              render(filtered);
            }
            break;
          case ControlCharacter.escape:
            break outerLoop;
          case ControlCharacter.backspace:
            if (query.isNotEmpty) {
              query = query.substring(0, query.length - 1);
              selected = 0;
              filtered = doFilter(query);
              render(filtered);
            }
            break;
          default:
            break;
        }
      } else {
        final ch = key.char;
        if (ch == 'q' && query.isEmpty) break outerLoop;

        query += ch;
        selected = 0;
        filtered = doFilter(query);
        render(filtered);
      }
    }

    _exitRaw();
    _scr.clear();
  }

  // ─── Painel de detalhe ───────────────────────────────────────────

  /// Exibe o detalhe de [e]. Retorna `true` se o log foi deletado.
  static bool logDetail(LogEntry e, {LogService? service}) {
    var entry = e;

    void doRender() {
      _scr.clear();
      final catColor = _catColor(entry.categoria);
      final lines = <String>[
        '${Theme.gold}Projeto:   ${Theme.reset}${Theme.text}${entry.projeto}${Theme.reset}',
        '${Theme.gold}Data:      ${Theme.reset}${Theme.text}${_formatDate(entry.timestamp)}${Theme.reset}',
        if (entry.duracaoMinutos != null)
          '${Theme.gold}Duração:   ${Theme.reset}${Theme.text}${_fmtDuration(entry.duracaoMinutos!)}${Theme.reset}',
        '${Theme.gold}Categoria: ${Theme.reset}$catColor${entry.categoria}${Theme.reset}',
        '${Theme.gold}Tipo:      ${Theme.reset}${Theme.text}${entry.tipo}${Theme.reset}',
        '',
        '${Theme.mauve}Descrição:${Theme.reset}',
        ..._wrap('  ${entry.descricao}', 54)
            .map((l) => '${Theme.text}$l${Theme.reset}'),
        if (entry.conteudo != null && entry.conteudo!.isNotEmpty) ...[
          '',
          '${Theme.mauve}Conteúdo:${Theme.reset}',
          ..._wrap('  ${entry.conteudo!}', 54)
              .map((l) => '${Theme.text}$l${Theme.reset}'),
        ],
        if (entry.tags != null && entry.tags!.isNotEmpty) ...[
          '',
          '${Theme.cyan}Tags:${Theme.reset} ${Theme.dim(entry.tags!)}',
        ],
      ];
      stdout.writeln();
      box('Detalhe  #${entry.id}', lines);
      final hints = service != null
          ? {'q': 'voltar', 'e': 'editar', 'd': 'deletar'}
          : {'q': 'voltar'};
      hotkeyBar(hints);
    }

    doRender();
    _enterRaw();

    while (true) {
      final key = _scr.readKey();
      if (key.isControl) {
        if (key.controlChar == ControlCharacter.escape) {
          _exitRaw();
          return false;
        }
        continue;
      }
      switch (key.char.toLowerCase()) {
        case 'q':
          _exitRaw();
          return false;
        case 'e':
          if (service != null) {
            _exitRaw();
            final updated = _editFlow(entry, service);
            if (updated != null) entry = updated;
            doRender();
            _enterRaw();
          }
          break;
        case 'd':
          if (service != null) {
            _exitRaw();
            stdout.write(
              '\n${Theme.pink}? ${Theme.reset}${Theme.text}Deletar este log? '
              '${Theme.dim('(s/n)')}${Theme.reset}\n'
              '${Theme.green}❯${Theme.reset} ',
            );
            final confirm = Screen.instance.readLine() ?? '';
            if (confirm.trim().toLowerCase() == 's') {
              service.delete(entry.id!);
              success('Log #${entry.id} deletado.');
              stdout.write(
                  '\n${Theme.dim('  pressione Enter para continuar...')}');
              stdin.readLineSync();
              return true;
            }
            doRender();
            _enterRaw();
          }
          break;
      }
    }
  }

  // ─── Editar log ──────────────────────────────────────────────────

  /// Abre um fluxo de edição para [e] usando [service].
  /// Retorna o [LogEntry] atualizado, ou [null] se cancelado.
  static LogEntry? _editFlow(LogEntry e, LogService service) {
    _scr.clear();
    stdout.writeln(
      '\n${Theme.mauve}╭─ Editar #${e.id} ─────────────────────────────${Theme.reset}',
    );
    stdout
        .writeln(Theme.dim('  Vazio = manter valor atual.  :q = cancelar.\n'));

    final novoProjeto = prompt('Projeto (atual: ${e.projeto}):');
    if (novoProjeto == null) {
      warn('Edição cancelada.');
      return null;
    }

    final descPreview = e.descricao.length > 50
        ? '${e.descricao.substring(0, 47)}...'
        : e.descricao;
    final novaDesc =
        prompt('Descrição (atual: $descPreview):', color: Theme.cyan);
    if (novaDesc == null) {
      warn('Edição cancelada.');
      return null;
    }

    final durAtual = e.duracaoMinutos != null
        ? _fmtDuration(e.duracaoMinutos!)
        : 'sem duração';
    final durStr = prompt('Duração (atual: $durAtual) — vazio = manter:',
        color: Theme.gold);
    if (durStr == null) {
      warn('Edição cancelada.');
      return null;
    }
    int? novaDuracao = e.duracaoMinutos;
    if (durStr.isNotEmpty) {
      final parsed = _parseDuration(durStr);
      if (parsed != null) novaDuracao = parsed;
    }

    final currentCatIdx = kCategorias.indexOf(e.categoria);
    stdout.writeln('\n${Theme.text}  Categoria:${Theme.reset}');
    final catIdx =
        radioMenu(kCategorias, initial: currentCatIdx >= 0 ? currentCatIdx : 0);
    if (catIdx == -1) {
      warn('Edição cancelada.');
      return null;
    }

    String? novoConteudo = e.conteudo;
    String? novasTags = e.tags;
    if (e.tipo == 'Solução / Aprendizado') {
      final conteudoPreview = e.conteudo == null
          ? 'vazio'
          : (e.conteudo!.length > 40
              ? '${e.conteudo!.substring(0, 37)}...'
              : e.conteudo!);
      final c = prompt('Conteúdo (atual: $conteudoPreview) — vazio = manter:',
          color: Theme.cyan);
      if (c == null) {
        warn('Edição cancelada.');
        return null;
      }
      if (c.isNotEmpty) novoConteudo = c;

      final t = prompt(
          'Tags (atual: ${e.tags ?? 'sem tags'}) — vazio = manter:',
          color: Theme.gold);
      if (t == null) {
        warn('Edição cancelada.');
        return null;
      }
      if (t.isNotEmpty) novasTags = t;
    }

    stdout.writeln('${Theme.mauve}╰${'─' * 50}${Theme.reset}\n');

    final updated = LogEntry(
      id: e.id,
      timestamp: e.timestamp,
      projeto: novoProjeto.isEmpty ? e.projeto : novoProjeto,
      descricao: novaDesc.isEmpty ? e.descricao : novaDesc,
      duracaoMinutos: novaDuracao,
      categoria: kCategorias[catIdx],
      tipo: e.tipo,
      conteudo: novoConteudo,
      tags: novasTags,
    );
    service.update(updated);
    success('Log #${e.id} atualizado.');
    return updated;
  }

  // ─── Spinner ─────────────────────────────────────────────────────

  static Future<T> spinner<T>(Future<T> task, String message) async {
    const frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
    int i = 0;
    stdout.write('\x1B[?25l');
    final timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      stdout.write(
        '\r${Theme.gold}${frames[i % frames.length]}${Theme.reset} '
        '${Theme.text}$message${Theme.reset}   ',
      );
      i++;
    });
    late T result;
    try {
      result = await task;
    } finally {
      timer.cancel();
      stdout.write(
        '\r${Theme.green}✔${Theme.reset} '
        '${Theme.text}$message${Theme.reset}   \n',
      );
      stdout.write('\x1B[?25h');
    }
    return result;
  }

  // ─── Status ──────────────────────────────────────────────────────

  static void success(String msg) =>
      stdout.writeln('${Theme.green}✔ $msg${Theme.reset}');
  static void error(String msg) =>
      stdout.writeln('${Theme.pink}✖ $msg${Theme.reset}');
  static void info(String msg) =>
      stdout.writeln('${Theme.cyan}ℹ $msg${Theme.reset}');
  static void warn(String msg) =>
      stdout.writeln('${Theme.gold}⚠ $msg${Theme.reset}');

  // ─── Separator (compat) ──────────────────────────────────────────

  static void separator({String color = Theme.mauve}) => stdout
      .writeln('$color${'─' * (_scr.cols - 2).clamp(10, 80)}${Theme.reset}');

  // ─── Helpers privados ─────────────────────────────────────────────

  static String _catColor(String cat) {
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

  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      const months = [
        '',
        'jan',
        'fev',
        'mar',
        'abr',
        'mai',
        'jun',
        'jul',
        'ago',
        'set',
        'out',
        'nov',
        'dez'
      ];
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month]}';
    } catch (_) {
      return iso;
    }
  }

  static String _fmtDuration(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static int? _parseDuration(String s) {
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

  static List<String> _wrap(String text, int maxWidth) {
    if (text.length <= maxWidth) return [text];
    final words = text.split(' ');
    final lines = <String>[];
    var current = '';
    for (final word in words) {
      if (current.isEmpty) {
        current = word;
      } else if ((current + ' ' + word).length <= maxWidth) {
        current += ' $word';
      } else {
        lines.add(current);
        current = '    $word';
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines;
  }
}
