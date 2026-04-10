import 'dart:io';

import 'package:dart_console/dart_console.dart';

/// Motor de renderização estática do terminal.
///
/// Usa a tela alternativa do xterm (`\x1B[?1049h`) para isolar
/// completamente a UI do histórico do shell — quando o app fecha,
/// o terminal volta ao estado original sem nenhuma poluição.
///
/// Uso típico:
/// ```dart
/// final scr = Screen.instance;
/// scr.enterAlt();
/// scr.hideCursor();
/// // ... renderiza frames via scr.frame(lines) ...
/// scr.exitAlt();
/// ```
class Screen {
  Screen._();
  static final Screen instance = Screen._();

  final _con = Console();

  // ─── Dimensões ────────────────────────────────────────────────

  /// Largura atual do terminal (fallback: 80).
  int get cols => _con.windowWidth  > 0 ? _con.windowWidth  : 80;

  /// Altura atual do terminal (fallback: 24).
  int get rows => _con.windowHeight > 0 ? _con.windowHeight : 24;

  // ─── Alternate screen buffer ──────────────────────────────────

  /// Entra na tela alternativa (sem scroll, sem histórico).
  /// Chame uma vez no início do app.
  void enterAlt() => stdout.write('\x1B[?1049h');

  /// Sai da tela alternativa e restaura o conteúdo anterior do terminal.
  /// Chame ao encerrar o app.
  void exitAlt() => stdout.write('\x1B[?1049l');

  // ─── Cursor ───────────────────────────────────────────────────

  void hideCursor() => _con.hideCursor();
  void showCursor() => _con.showCursor();

  // ─── Raw mode / input ─────────────────────────────────────────

  set rawMode(bool v) => _con.rawMode = v;

  Key readKey() => _con.readKey();

  String? readLine() => _con.readLine();

  // ─── Navegação de cursor ──────────────────────────────────────

  /// Limpa a tela inteira e posiciona no canto superior esquerdo.
  void clear() => stdout.write('\x1B[2J\x1B[H');

  /// Move o cursor ao topo sem limpar (overwrite in-place).
  void home() => stdout.write('\x1B[H');

  /// Sobe [n] linhas a partir da posição atual.
  void up(int n) {
    if (n > 0) stdout.write('\x1B[${n}A');
  }

  // ─── Frame rendering ──────────────────────────────────────────

  /// Renderiza um frame completo sobrescrevendo a tela do topo.
  ///
  /// Cada linha é apagada antes de ser escrita (`\x1B[2K`) para
  /// eliminar artefatos. Linhas residuais abaixo do frame são
  /// removidas com `\x1B[J`.
  void frame(Iterable<String> lines) {
    home();
    for (final l in lines) {
      stdout.write('\x1B[2K$l\n');
    }
    stdout.write('\x1B[J');
  }

  // ─── Escrita de linha única ────────────────────────────────────

  void writeln(String s) => stdout.write('\x1B[2K$s\n');
  void write(String s)   => stdout.write(s);
  void clearLine()       => stdout.write('\x1B[2K');
}
