abstract class Theme {
  // ─── Paleta Catppuccin-Monokai ───────────────────────────────────
  static const String text = '\x1B[38;2;202;211;245m'; // #CAD3F5 – Texto base
  static const String mauve = '\x1B[38;2;203;166;247m'; // #CBA6F7 – Bordas
  static const String pink = '\x1B[38;2;249;38;114m'; //  #F92672 – Destaques
  static const String green = '\x1B[38;2;166;226;46m'; //  #A6E22E – Sucesso
  static const String cyan = '\x1B[38;2;102;217;239m'; //  #66D9EF – Tags/Info
  static const String gold =
      '\x1B[38;2;200;150;12m'; //   #C8960C – Avisos/Tempo
  static const String reset = '\x1B[0m'; // Reset de cor

  // ─── Estilos de texto ────────────────────────────────────────────
  static String bold(String t) => '\x1B[1m$t$reset';
  static String dim(String t) => '\x1B[2m$t$reset';

  // ─── Cor arbitrária em True Color (ANSI 24-bit) ──────────────────
  /// Embrulha [text] em códigos ANSI 24-bit usando um [hexColor] no
  /// formato '#RRGGBB' ou 'RRGGBB'.
  static String color(String text, String hexColor) {
    final hex = hexColor.replaceFirst('#', '');
    final r = int.parse(hex.substring(0, 2), radix: 16);
    final g = int.parse(hex.substring(2, 4), radix: 16);
    final b = int.parse(hex.substring(4, 6), radix: 16);
    return '\x1B[38;2;$r;$g;${b}m$text\x1B[0m';
  }
}
