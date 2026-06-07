import 'dart:async';
import 'dart:io';

import 'package:dart_console/dart_console.dart';

import '../core/theme.dart';
import '../logic/log_service.dart';
import '../models/log_entry.dart';
import 'renderer.dart';

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

  static int vis(String s) =>
      s.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '').length;

  static String rpad(String s, int width) {
    final diff = width - vis(s);
    return diff > 0 ? '$s${' ' * diff}' : s;
  }

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

  static String dottedLine([int? width]) {
    final w = (width ?? _scr.cols).clamp(20, 200);
    return Theme.dim('·' * w);
  }

  // ─── Header box ─────────────────────────────────────────────────

  static List<String> headerLines(String appName, List<StatCard> stats,
      {int? totalLogs, int? maxLogs}) {
    final w = _scr.cols;
    final inner = w - 2;
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

  // ─── Radio menu ─────────────────────────────────────────────────

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

    final totalLines = options.length * 2 + (hints != null ? 2 : 0);

    void render(bool first) {
      if (!first) _scr.up(totalLines);
      final w = _scr.cols;

      for (int i = 0; i < options.length; i++) {
        final isSel = i == selected;
        final marker = isSel
            ? '${Theme.green}▶ ◉${Theme.reset}'
            : '  ${Theme.mauve}○${Theme.reset}';
        final label = isSel
            ? '${Theme.text}${options[i]}${Theme.reset}'
            : Theme.dim(options[i]);
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
        stdout.write('\x1B[2K\n');
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

  // ─── Seletor de projeto ─────────────────────────────────────────

  static String? projectPicker(List<String> existing, {String? current}) {
    if (existing.isEmpty) {
      final novo = prompt('Nome do projeto:');
      if (novo == null || novo.trim().isEmpty) return null;
      return novo.trim();
    }

    var query = '';
    var selected = 0;
    var awaitingProjectCommand = false;
    final inputW = (_scr.cols - 8).clamp(30, 60);

    if (current != null) {
      final idx = existing.indexOf(current);
      if (idx >= 0) selected = idx;
    }

    List<String> doFilter(String q) {
      if (q.isEmpty) return existing;
      final lower = q.toLowerCase();
      return existing.where((p) => p.toLowerCase().contains(lower)).toList();
    }

    void render(List<String> filtered) {
      _scr.clear();
      stdout.writeln();

      final cursor = '${Theme.green}▌${Theme.reset}';
      final inputText = query.isEmpty
          ? Theme.dim('filtrar projetos...')
          : '${Theme.text}$query${Theme.reset}$cursor';
      final rawLen = query.isEmpty ? 19 : query.length + 1;
      final fillLen = (inputW - rawLen - 2).clamp(0, inputW);

      stdout.writeln(
          '  ${Theme.pink}◆${Theme.reset} ${Theme.text}Projeto${Theme.reset}');
      stdout.writeln();
      stdout.writeln('  ${Theme.mauve}╭${'─' * inputW}╮${Theme.reset}');
      stdout.writeln(
          '  ${Theme.mauve}│${Theme.reset} $inputText${' ' * fillLen} ${Theme.mauve}│${Theme.reset}');
      stdout.writeln('  ${Theme.mauve}╰${'─' * inputW}╯${Theme.reset}');
      stdout.writeln();
      stdout.writeln(dottedLine());
      stdout.writeln();

      if (filtered.isEmpty) {
        stdout.writeln(
          '  ${Theme.dim('Nenhum projeto encontrado — ')}${Theme.green}:a${Theme.reset}${Theme.dim(' para criar novo')}',
        );
        stdout.writeln();
      } else {
        const pageSize = 8;
        final offset = (selected - pageSize + 1).clamp(0, filtered.length);
        final end = (offset + pageSize).clamp(0, filtered.length);
        final page = filtered.sublist(offset, end);

        if (offset > 0) {
          stdout.writeln(
            '  ${Theme.dim('▲  ${offset} projeto(s) acima...')}',
          );
          stdout.writeln();
        }
        for (int i = 0; i < page.length; i++) {
          final absIdx = offset + i;
          final isSel = absIdx == selected;
          final arrow = isSel ? '${Theme.green}▶${Theme.reset}' : ' ';
          final dot = isSel
              ? '${Theme.green}●${Theme.reset}'
              : '${Theme.mauve}○${Theme.reset}';
          final label = isSel
              ? '${Theme.text}${filtered[absIdx]}${Theme.reset}'
              : Theme.dim(filtered[absIdx]);
          stdout.writeln('   $arrow $dot  $label');
          stdout.writeln();
        }
        if (end < filtered.length) {
          final remaining = filtered.length - end;
          stdout.writeln(
            '  ${Theme.dim('▼  $remaining projeto(s) abaixo...')}',
          );
          stdout.writeln();
        }
      }

      stdout.writeln(dottedLine());
      hotkeyBar({
        '↑↓': 'navegar',
        'ent': 'selecionar',
        ':a': 'novo projeto',
        'q': 'cancelar',
      });
    }

    _enterRaw();
    var filtered = doFilter(query);
    render(filtered);

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
            if (selected < filtered.length - 1) {
              selected++;
              render(filtered);
            }
            break;
          case ControlCharacter.enter:
            if (filtered.isNotEmpty) {
              _exitRaw();
              return filtered[selected];
            }
            break;
          case ControlCharacter.escape:
            _exitRaw();
            return null;
          case ControlCharacter.backspace:
            if (awaitingProjectCommand) {
              awaitingProjectCommand = false;
              break;
            }
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
        if (awaitingProjectCommand) {
          awaitingProjectCommand = false;
          final command = ':$ch';
          if (query.isEmpty && command == ':a') {
            _exitRaw();
            final novo = prompt('Nome do novo projeto:');
            if (novo == null || novo.trim().isEmpty) return null;
            return novo.trim();
          }
          if (query.isEmpty && command == ':q') {
            _exitRaw();
            return null;
          }
          query += command;
          selected = 0;
          filtered = doFilter(query);
          render(filtered);
          continue;
        }
        if (ch == 'q' && query.isEmpty) {
          _exitRaw();
          return null;
        }
        if (ch == ':' && query.isEmpty) {
          awaitingProjectCommand = true;
          continue;
        }
        query += ch;
        selected = 0;
        filtered = doFilter(query);
        render(filtered);
      }
    }

    // ignore: dead_code
    _exitRaw();
    return null;
  }

  // ─── Barra de atalhos ────────────────────────────────────────────

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

  static String? multilinePrompt(
    String question, {
    String color = Theme.pink,
    int maxLines = 15,
    String? initialValue,
  }) {
    _exitRaw();

    final lines = <String>[];
    if (initialValue != null && initialValue.isNotEmpty) {
      lines.addAll(initialValue.replaceAll('\r\n', '\n').split('\n'));
    }

    while (true) {
      _scr.clear();
      stdout.writeln();
      stdout.writeln(
        '$color◆${Theme.reset} ${Theme.text}$question${Theme.reset}',
      );
      stdout.writeln();
      stdout.writeln(
        Theme.dim(
          '  Enter = nova linha · :s = salvar · :b = voltar 1 linha · :del N = excluir linha · :q = cancelar · até $maxLines linhas',
        ),
      );
      stdout.writeln();
      stdout.writeln('${Theme.gold}Conteúdo atual:${Theme.reset}');
      if (lines.isEmpty) {
        stdout.writeln('  ${Theme.dim('(vazio)')}');
      } else {
        for (int i = 0; i < lines.length; i++) {
          stdout.writeln('  ${i + 1}. ${lines[i]}');
        }
      }
      stdout.writeln();

      if (lines.length >= maxLines) {
        stdout.write('${Theme.green}❯${Theme.reset} ');
        final command = Screen.instance.readLine();
        if (command == null) return null;
        final trimmed = command.trim();
        if (trimmed == ':q') return null;
        if (trimmed == ':s') return lines.join('\n');
        final handled = _applyMultilineCommand(lines, trimmed);
        if (handled) continue;
        stdout.writeln(
          Theme.dim(
            '  Limite de $maxLines linhas atingido. Use :s, :b, :del N ou :q.',
          ),
        );
        continue;
      }

      stdout.write(
        '${Theme.green}❯${Theme.reset} Linha ${lines.length + 1}/$maxLines: ',
      );
      final line = Screen.instance.readLine();
      if (line == null) return null;

      final trimmed = line.trim();
      if (trimmed == ':q') return null;
      if (trimmed == ':s') return lines.join('\n');
      if (_applyMultilineCommand(lines, trimmed)) continue;

      lines.add(line);
    }
  }

  static bool _applyMultilineCommand(List<String> lines, String command) {
    if (command == ':b' || command == ':back') {
      if (lines.isNotEmpty) {
        lines.removeLast();
      }
      return true;
    }

    final delMatch = RegExp(r'^:(?:del|delete)\s+(\d+)$').firstMatch(command);
    if (delMatch != null) {
      final index = int.tryParse(delMatch.group(1)!);
      if (index != null && index >= 1 && index <= lines.length) {
        lines.removeAt(index - 1);
      }
      return true;
    }

    return false;
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

  // ─── Live search ─────────────────────────────────────────────────
  // FIX P0: removido bloco if(ch == 'a') — só pertence ao projectPicker.
  // FIX P1: paginação real com offset, igual ao projectPicker.

  static void liveSearch(List<LogEntry> allEntries, LogService service) {
    if (allEntries.isEmpty) {
      info('Nenhum log registrado ainda.');
      return;
    }

    var entries = allEntries;
    var query = '';
    var selected = 0;
    final inputW = (_scr.cols - 8).clamp(30, 60);

    // P1: constante de página — quantos itens mostrar de uma vez
    const pageSize = 8;

    List<LogEntry> doFilter(String q) {
      final List<LogEntry> base;
      if (q.isEmpty) {
        base = List.from(entries);
      } else {
        final lower = q.toLowerCase();
        base = entries.where((e) {
          return e.descricao.toLowerCase().contains(lower) ||
              e.projeto.toLowerCase().contains(lower) ||
              e.categoria.toLowerCase().contains(lower) ||
              (e.tags?.toLowerCase().contains(lower) ?? false) ||
              (e.conteudo?.toLowerCase().contains(lower) ?? false);
        }).toList();
      }
      base.sort((a, b) {
        final projCmp = a.projeto.compareTo(b.projeto);
        if (projCmp != 0) return projCmp;
        return b.timestamp.compareTo(a.timestamp);
      });
      return base;
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
        // P1: calcular offset real para que 'selected' esteja sempre visível
        final clampedSelected = selected.clamp(0, filtered.length - 1);
        final offset =
            (clampedSelected - pageSize + 1).clamp(0, filtered.length);
        final end = (offset + pageSize).clamp(0, filtered.length);
        final show = filtered.sublist(offset, end);

        // Indicador de scroll acima
        if (offset > 0) {
          stdout.writeln(
            '  ${Theme.dim('▲  $offset resultado(s) acima...')}',
          );
          stdout.writeln();
        }

        String? lastProj;
        for (int i = 0; i < show.length; i++) {
          final absIdx = offset + i;
          final e = show[i];
          final isSelected = absIdx == clampedSelected;

          // Cabeçalho de projeto (agrupado)
          if (e.projeto != lastProj) {
            if (lastProj != null) stdout.writeln();
            lastProj = e.projeto;
            final projColor = isSelected ? Theme.green : Theme.mauve;
            final cnt = filtered.where((x) => x.projeto == e.projeto).length;
            final plural = cnt == 1 ? '' : 's';
            stdout.writeln(
              '  $projColor\u25c8${Theme.reset} '
              '${Theme.text}${e.projeto}${Theme.reset}  '
              '${Theme.dim('$cnt log$plural')}',
            );
          }
          _logRow(e, isSelected, indent: 2);
        }

        // Indicador de scroll abaixo
        if (end < filtered.length) {
          final remaining = filtered.length - end;
          stdout.writeln();
          stdout.writeln(
            '  ${Theme.dim('▼  $remaining resultado(s) abaixo...')}',
          );
          stdout.writeln();
        } else {
          stdout.writeln();
        }

        // Contador total
        if (filtered.length > pageSize) {
          final showing = end - offset;
          stdout.writeln(
            '  ${Theme.dim('mostrando $showing de ${filtered.length} resultados')}',
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
            // P1: navegar até o fim real da lista, não só do page
            if (selected < filtered.length - 1) {
              selected++;
              render(filtered);
            }
            break;
          case ControlCharacter.enter:
            if (filtered.isNotEmpty) {
              final realIdx = selected.clamp(0, filtered.length - 1);
              _exitRaw();
              final deleted = logDetail(filtered[realIdx], service: service);
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
        // FIX P0: 'q' com query vazia volta ao menu — sem bloco 'a' aqui.
        if (ch == 'q' && query.isEmpty) break outerLoop;

        // Qualquer outro char (incluindo 'a', 'e', 'd') vai para o query.
        query += ch;
        selected = 0;
        filtered = doFilter(query);
        render(filtered);
      }
    }

    _exitRaw();
    _scr.clear();
  }

  // ─── Heatmap de atividade ────────────────────────────────────────
  //
  // Grade de 12 semanas × 7 dias.
  // Cada célula = 1 dia. Intensidade pela cor (minutos trabalhados).
  // Navegação com ←→↑↓; info do dia selecionado exibida abaixo da grade.

  static void activityHeatmap(LogService service) {
    final activityData = service.getActivityByDay(weeks: 12);

    // Construir lista de dias: do início da semana de 12 semanas atrás até hoje
    final today = DateTime.now();
    // Início = segunda-feira da semana de 12 semanas atrás
    final daysBack = (12 * 7) - 1;
    var startDate = today.subtract(Duration(days: daysBack));
    // Recuar até a segunda-feira da semana
    while (startDate.weekday != DateTime.monday) {
      startDate = startDate.subtract(const Duration(days: 1));
    }

    // Montar grade: lista de semanas, cada semana = 7 dias (seg→dom)
    final weeks = <List<DateTime?>>[];
    var cursor = startDate;
    while (!cursor.isAfter(today)) {
      final week = <DateTime?>[];
      for (int d = 0; d < 7; d++) {
        final day = cursor.add(Duration(days: d));
        week.add(day.isAfter(today) ? null : day);
      }
      weeks.add(week);
      cursor = cursor.add(const Duration(days: 7));
    }

    // Estado de seleção: col = semana, row = dia da semana
    int selCol = weeks.length - 1;
    int selRow = today.weekday - 1; // 0=seg, 6=dom

    // Garantir que a célula inicial seja válida (não futura)
    while (selRow >= 0 && weeks[selCol][selRow] == null) {
      selRow--;
    }

    // Máximo de minutos para normalizar intensidade
    int maxMin = 1;
    for (final data in activityData.values) {
      if (data['minutos']! > maxMin) maxMin = data['minutos']!;
    }

    String _dayKey(DateTime dt) =>
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    // Retorna bloco colorido baseado na intensidade de minutos
    String _cell(DateTime? dt, bool selected) {
      if (dt == null) return '  '; // dia futuro — espaço vazio

      final key = _dayKey(dt);
      final data = activityData[key];
      final minutos = data?['minutos'] ?? 0;

      // 5 níveis de intensidade: vazio, fraco, médio, forte, máximo
      final String block;
      if (selected) {
        block = '◈◈'; // destaque de seleção
      } else if (minutos == 0) {
        block = '░░'; // sem atividade
      } else {
        final pct = minutos / maxMin;
        if (pct < 0.25) {
          block = '▒▒'; // baixo
        } else if (pct < 0.5) {
          block = '▓▓'; // médio
        } else if (pct < 0.75) {
          block = '██'; // alto
        } else {
          block = '██'; // máximo
        }
      }

      // Cor
      if (selected) return '${Theme.pink}$block${Theme.reset}';
      if (minutos == 0) return Theme.dim(block);
      final pct = minutos / maxMin;
      if (pct < 0.25) return Theme.color(block, '#2D5016');
      if (pct < 0.5) return Theme.color(block, '#4A8022');
      if (pct < 0.75) return Theme.color(block, '#6DB52E');
      return Theme.color(block, '#A6E22E');
    }

    // Renderiza a tela completa do heatmap
    void render() {
      _scr.clear();
      stdout.writeln();
      stdout.writeln(
          '  ${Theme.pink}◆${Theme.reset} ${Theme.text}Histórico de Atividade${Theme.reset}  ${Theme.dim('últimas 12 semanas')}');
      stdout.writeln();

      // Labels dos meses acima da grade
      // Detectar onde cada mês começa na grade
      final monthLine =
          StringBuffer('     '); // 5 chars de indent para os labels de dia
      String? lastMonth;
      const monthNames = [
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
      for (int c = 0; c < weeks.length; c++) {
        // Pega o primeiro dia não-nulo da semana
        DateTime? rep;
        for (final d in weeks[c]) {
          if (d != null) {
            rep = d;
            break;
          }
        }
        if (rep == null) {
          monthLine.write('   ');
          continue;
        }
        final mName = monthNames[rep.month];
        if (mName != lastMonth) {
          monthLine.write('${Theme.dim(mName)} ');
          lastMonth = mName;
        } else {
          monthLine.write('   ');
        }
      }
      stdout.writeln(monthLine.toString());
      stdout.writeln();

      // Labels dos dias da semana + grade
      const dayLabels = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
      for (int row = 0; row < 7; row++) {
        final dayLabel = Theme.dim(dayLabels[row]);
        stdout.write('  $dayLabel ');
        for (int col = 0; col < weeks.length; col++) {
          final dt = weeks[col][row];
          final isSel = col == selCol && row == selRow;
          stdout.write(_cell(dt, isSel));
          stdout.write(' ');
        }
        stdout.writeln();
      }

      stdout.writeln();

      // Legenda de intensidade
      stdout.write('  ${Theme.dim('menos ')}');
      stdout.write(Theme.dim('░░ '));
      stdout.write('${Theme.color('▒▒', '#2D5016')} ');
      stdout.write('${Theme.color('▓▓', '#4A8022')} ');
      stdout.write('${Theme.color('██', '#6DB52E')} ');
      stdout.write('${Theme.color('██', '#A6E22E')} ');
      stdout.writeln(Theme.dim(' mais'));

      stdout.writeln();
      stdout.writeln(dottedLine());
      stdout.writeln();

      // Painel de info do dia selecionado
      final selDt =
          (selRow >= 0 && selRow < 7 && selCol >= 0 && selCol < weeks.length)
              ? weeks[selCol][selRow]
              : null;

      if (selDt != null) {
        final key = _dayKey(selDt);
        final data = activityData[key];
        final logs = data?['logs'] ?? 0;
        final minutos = data?['minutos'] ?? 0;

        const wdays = [
          'Segunda',
          'Terça',
          'Quarta',
          'Quinta',
          'Sexta',
          'Sábado',
          'Domingo'
        ];
        const months2 = [
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
        final wday = wdays[selDt.weekday - 1];
        final dateStr =
            '$wday, ${selDt.day.toString().padLeft(2, '0')} ${months2[selDt.month]} ${selDt.year}';

        stdout.writeln(
            '  ${Theme.gold}◷${Theme.reset}  ${Theme.text}$dateStr${Theme.reset}');
        stdout.writeln();

        if (logs == 0) {
          stdout.writeln(
              '  ${Theme.dim('Nenhuma atividade registrada neste dia.')}');
        } else {
          final logsLabel = logs == 1 ? 'log registrado' : 'logs registrados';
          stdout.writeln(
            '  ${Theme.green}$logs${Theme.reset} ${Theme.dim(logsLabel)}'
            '   ${Theme.cyan}${_fmtDuration(minutos)}${Theme.reset} ${Theme.dim('de trabalho')}',
          );

          // Buscar logs do dia para mostrar resumo
          final dayLogs = service.getAll().where((e) {
            return e.timestamp.startsWith(key);
          }).toList();

          if (dayLogs.isNotEmpty) {
            stdout.writeln();
            final toShow = dayLogs.take(3).toList();
            for (final l in toShow) {
              final catC = _catColor(l.categoria);
              final desc = l.descricao.length > 45
                  ? '${l.descricao.substring(0, 42)}...'
                  : l.descricao;
              stdout.writeln(
                '  ${Theme.mauve}·${Theme.reset}  $catC${l.categoria}${Theme.reset}  '
                '${Theme.dim(desc)}',
              );
            }
            if (dayLogs.length > 3) {
              stdout.writeln(
                '  ${Theme.dim('  ... e mais ${dayLogs.length - 3} log(s)')}',
              );
            }
          }
        }
      } else {
        stdout.writeln(
            '  ${Theme.dim('Selecione um dia para ver os detalhes.')}');
      }

      stdout.writeln();
      stdout.writeln(dottedLine());
      hotkeyBar({'←→↑↓': 'navegar', 'ent': 'ver dia completo', 'q': 'voltar'});
    }

    _enterRaw();
    render();

    outerLoop:
    while (true) {
      final key = _scr.readKey();
      if (!key.isControl) {
        if (key.char == 'q') break outerLoop;
        continue;
      }

      switch (key.controlChar) {
        case ControlCharacter.escape:
          break outerLoop;

        case ControlCharacter.arrowLeft:
          if (selCol > 0) {
            selCol--;
            // Ajustar row se a célula for nula (futuro ou fora de range)
            while (selRow >= 0 && weeks[selCol][selRow] == null) {
              selRow--;
            }
            if (selRow < 0) selRow = 0;
            render();
          }
          break;

        case ControlCharacter.arrowRight:
          if (selCol < weeks.length - 1) {
            selCol++;
            // Ajustar row para não selecionar dia futuro
            while (selRow < 6 && weeks[selCol][selRow] == null) {
              selRow--;
            }
            if (selRow < 0) selRow = 0;
            render();
          }
          break;

        case ControlCharacter.arrowUp:
          if (selRow > 0) {
            selRow--;
            render();
          }
          break;

        case ControlCharacter.arrowDown:
          if (selRow < 6 && weeks[selCol][selRow + 1] != null) {
            selRow++;
            render();
          }
          break;

        case ControlCharacter.enter:
          // Mostrar logs completos do dia selecionado
          final selDt = weeks[selCol][selRow];
          if (selDt != null) {
            final key2 =
                '${selDt.year}-${selDt.month.toString().padLeft(2, '0')}-${selDt.day.toString().padLeft(2, '0')}';
            final dayLogs = service
                .getAll()
                .where((e) => e.timestamp.startsWith(key2))
                .toList();
            if (dayLogs.isNotEmpty) {
              _exitRaw();
              logList(dayLogs,
                  title:
                      'Logs de ${selDt.day.toString().padLeft(2, '0')}/${selDt.month.toString().padLeft(2, '0')}');
              _enterRaw();
              render();
            }
          }
          break;

        default:
          break;
      }
    }

    _exitRaw();
    _scr.clear();
  }

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

  static void _logRow(LogEntry e, bool selected, {int indent = 0}) {
    final w = _scr.cols;
    final pad = ' ' * indent;
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

    final left = '$pad $arrow $dot  $proj${Theme.dim(' · ')}$desc';
    final right = '$cat  $date$dur';
    final gap = (w - vis(left) - vis(right) - 2).clamp(1, w);

    stdout.writeln('$left${' ' * gap}$right');
    stdout.writeln();
  }

  // ─── Painel de detalhe ───────────────────────────────────────────

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
        ..._wrap(entry.descricao, 54, prefix: '  ')
            .map((l) => '${Theme.text}$l${Theme.reset}'),
        if (entry.conteudo != null && entry.conteudo!.isNotEmpty) ...[
          '',
          '${Theme.mauve}Conteúdo:${Theme.reset}',
          ..._wrap(entry.conteudo!, 54, prefix: '  ')
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
      final c = multilinePrompt(
        'Conteúdo / detalhes:',
        color: Theme.cyan,
        initialValue: e.conteudo,
      );
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

  static List<String> _wrap(
    String text,
    int maxWidth, {
    String prefix = '',
  }) {
    final availableWidth = (maxWidth - prefix.length).clamp(1, maxWidth);
    final normalized = text.replaceAll('\r\n', '\n');
    final lines = <String>[];
    for (final paragraph in normalized.split('\n')) {
      if (paragraph.isEmpty) {
        lines.add(prefix);
        continue;
      }
      final words = paragraph.split(' ');
      var current = '';
      for (final word in words) {
        if (current.isEmpty) {
          current = word;
        } else if ((current.length + 1 + word.length) <= availableWidth) {
          current += ' $word';
        } else {
          lines.add('$prefix$current');
          current = word;
        }
      }
      if (current.isNotEmpty) lines.add('$prefix$current');
    }
    return lines;
  }
}
