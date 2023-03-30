import 'dart:io';

import 'package:shell_cmd/shell_cmd.dart';

Future<void> main() async {
  print('\nOS: ${Platform.operatingSystemVersion}');
  print('\nIsWindows: ${ShellCmd.isWindows}');
  print('\nDefShell: ${ShellCmd.getShell()}');

  final cmd = (ShellCmd.isWindows ? 'echo. & echo %CD%' : 'echo "" && echo `pwd`');
  final r = await ShellCmd.run(cmd, runInShell: true);

  print('\nSplit: ${ShellCmd.split(cmd)}');
  print('\nCurDir:\n${r.exitCode == 0 ? 'Success' : 'Error ${r.exitCode}'}\n${r.stdout.toString()}***');
}
