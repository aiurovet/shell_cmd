import 'dart:io';

import 'package:shell_cmd/shell_cmd.dart';

/// A showcase for the use of the package
///
Future<void> main() async {
  print('\nOS: ${Platform.operatingSystemVersion}');
  print('\nIsWindows: ${ShellCmd.isWindows}');
  print('\nDefShell: ${ShellCmd.resetShell()}');

  final cmdWin = 'echo. & echo %CD%';
  final cmdPsx = 'echo "" && echo `pwd`';
  final cmd = ShellCmd(ShellCmd.isWindows ? cmdWin : cmdPsx);
  final result = await cmd.run(runInShell: true);
  final status =
      (result.exitCode == 0 ? 'Success' : 'Error ${result.exitCode}');

  print('\nSplit - Exe: ${cmd.program}, Args: ${cmd.args}');
  print('\nCurDir:\n$status\n${result.stdout.toString()}***');
}
