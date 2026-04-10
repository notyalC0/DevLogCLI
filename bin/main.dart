import 'dart:convert';
import 'dart:io';

import 'package:DevLogCli/ui/menu.dart';

Future<void> main(List<String> args) async {
  stdout.encoding = utf8;
  stderr.encoding = utf8;
  await runMenu();
}
