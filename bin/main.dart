import 'dart:convert';
import 'dart:io';

import 'package:DevLogCli/ui/menu.dart';

Future<void> main(List<String> args) async {
  // Força UTF-8 no stdout/stderr para renderizar corretamente os caracteres
  // Unicode (bordas, símbolos) no Windows Terminal e PowerShell.
  stdout.encoding = utf8;
  stderr.encoding = utf8;

  await runMenu();
}
