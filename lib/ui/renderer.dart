import 'dart:io';

import 'package:dart_console/dart_console.dart';

class Screen {
  Screen._();
  static final Screen instance = Screen._();

  final _con = Console();

  // ─── Dimensões ────────────────────────────────────────────────

  int get cols => _con.windowWidth > 0 ? _con.windowWidth : 80;

  int get rows => _con.windowHeight > 0 ? _con.windowHeight : 24;

  // ─── Alternate screen buffer ──────────────────────────────────

  void enterAlt() => stdout.write('\x1B[?1049h');

  void exitAlt() => stdout.write('\x1B[?1049l');

  // ─── Cursor ───────────────────────────────────────────────────

  void hideCursor() => _con.hideCursor();
  void showCursor() => _con.showCursor();

  // ─── Raw mode / input ─────────────────────────────────────────

  set rawMode(bool v) => _con.rawMode = v;

  Key readKey() => _con.readKey();

  String? readLine() => _con.readLine();

  // ─── Navegação de cursor ──────────────────────────────────────

  void clear() => stdout.write('\x1B[2J\x1B[H');

  void home() => stdout.write('\x1B[H');

  void up(int n) {
    if (n > 0) stdout.write('\x1B[${n}A');
  }

  // ─── Frame rendering ──────────────────────────────────────────

  void frame(Iterable<String> lines) {
    home();
    for (final l in lines) {
      stdout.write('\x1B[2K$l\n');
    }
    stdout.write('\x1B[J');
  }

  // ─── Escrita de linha única ────────────────────────────────────

  void writeln(String s) => stdout.write('\x1B[2K$s\n');
  void write(String s) => stdout.write(s);
  void clearLine() => stdout.write('\x1B[2K');
}
