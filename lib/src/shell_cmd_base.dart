// Copyright (c) 2023, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)

import 'dart:convert';
import 'dart:io';

import "package:charcode/ascii.dart";
import "package:path/path.dart" as p;
import 'package:shell_cmd/src/ascii_ext.dart';
import 'package:string_scanner/string_scanner.dart';

/// Static API to split an arbitrary command and to execute that
///
class ShellCmd {
  /// Current shell executable filename or full path
  ///
  static String shell = '';

  /// Default shell executable filename or full path
  ///
  static final defaultShell = (isWindows ? 'cmd.exe' : 'sh');

  /// Separator used to split directories in the PATH variable
  ///
  static final dirListSeparator = (isWindows ? ';' : ':');

  /// Line separator
  ///
  static final lineBreak = (isWindows ? '\r\n' : '\n');

  /// Const: current OS is Windows
  ///
  static final isWindows = Platform.isWindows;

  /// Const: environment variable name to retrieve OS default shell
  ///
  static final shellEnvKey = (isWindows ? 'COMSPEC' : 'SHELL');

  /// Const: temporary folder prefix
  ///
  static const tempScriptPrefix = 'shell_cmd';

  /// Under POSIX-compliant OS, does nothing and returns null.\
  /// Under Windows, creates a temporary directory (non-blocking)
  /// and returns that
  ///
  static Future<Directory?> createTempDir() async {
    if (!isWindows) {
      return null;
    }

    return await Directory.systemTemp.createTemp(tempScriptPrefix);
  }

  /// Under POSIX-compliant OS, does nothing and returns null.\
  /// Under Windows, creates a temporary directory (blocking)
  /// and returns that
  ///
  static Directory? createTempDirSync() {
    if (!isWindows) {
      return null;
    }

    return Directory.systemTemp.createTempSync(tempScriptPrefix);
  }

  /// Under POSIX-compliant OS, does nothing and returns an empty string.\
  /// Under Windows, creates a temporary folder (non-blocking) and writes
  /// [command] to an output file.\
  /// This file should be executed and deleted with the containing folder
  ///
  static Future<String> createTempScript(String command) async {
    final dir = await createTempDir();

    if (dir == null) {
      return '';
    }

    final scriptPath = p.join(dir.path, _getScriptPrefix());
    final scriptFile = File(scriptPath);

    try {
      await scriptFile.writeAsString(_toScript(command));
      return scriptPath;
    } on Exception catch (_) {
      await deleteTempScript(scriptPath);
      rethrow;
    } on Error catch (_) {
      await deleteTempScript(scriptPath);
      rethrow;
    }
  }

  /// Under POSIX-compliant OS, does nothing and returns an empty string.\
  /// Under Windows, creates a temporary folder (blocking) and writes
  /// [command] to an output file.\
  /// This file should be executed and deleted with the containing folder
  ///
  static String createTempScriptSync(String command) {
    final dir = createTempDirSync();

    if (dir == null) {
      return '';
    }

    final scriptPath = p.join(dir.path, _getScriptPrefix());
    final scriptFile = File(scriptPath);

    try {
      scriptFile.writeAsStringSync(_toScript(command));
      return scriptPath;
    } on Exception catch (_) {
      deleteTempScriptSync(scriptPath);
      rethrow;
    } on Error catch (_) {
      deleteTempScriptSync(scriptPath);
      rethrow;
    }
  }

  /// Deletes file created by createTempScript as well as containing
  /// folder (non-blocking)
  ///
  static Future<void> deleteTempScript(String? scriptPath) async {
    if ((scriptPath == null) || scriptPath.isEmpty) {
      return;
    }

    await File(scriptPath).parent.delete(recursive: true);
  }

  /// Deletes file created by createTempScript as well as containing
  /// folder (blocking)
  ///
  static void deleteTempScriptSync(String? scriptPath) {
    if ((scriptPath == null) || scriptPath.isEmpty) {
      return;
    }

    File(scriptPath).parent.deleteSync(recursive: true);
  }

  /// Removes the first argument from [args] and returns that
  ///
  static String extractExecutable(List<String> args) {
    if (args.isEmpty) {
      return '';
    }

    final exe = args[0];

    if (args.isNotEmpty) {
      args.removeAt(0);
    }

    return exe;
  }

  /// Get current shell
  ///
  static String getShell() {
    if (shell.isNotEmpty) {
      return shell;
    }

    final env = Platform.environment;
    shell = env[shellEnvKey] ?? '';

    if (shell.isEmpty) {
      shell = defaultShell;
    }

    return shell;
  }

  /// Get empty process result in case of no need to run command
  ///
  static ProcessResult getEmptyResult(int exitCode, [String? error]) =>
      ProcessResult(0, exitCode, null, error);

  /// Split an arbitrary [command] and execute that in the non-blocking mode.
  ///
  static Future<ProcessResult> run(String command,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      List<String>? shellArgs,
      Encoding? stdoutEncoding = systemEncoding,
      Encoding? stderrEncoding = systemEncoding}) async {
    final args = <String>[];
    String? exe;

    if (isWindows && runInShell) {
      exe = await createTempScript(command);
    } else {
      exe = _prepareRun(args, command, runInShell);
    }

    if (exe.isEmpty) {
      return getEmptyResult(1);
    }

    try {
      return await Process.run(exe, args,
          workingDirectory: workingDirectory,
          environment: environment,
          includeParentEnvironment: includeParentEnvironment,
          runInShell: false,
          stdoutEncoding: stdoutEncoding,
          stderrEncoding: stderrEncoding);
    } finally {
      if (isWindows && runInShell) {
        await deleteTempScript(exe);
      }
    }
  }

  /// Split an arbitrary [command] and execute that in the blocking mode.
  ///
  static ProcessResult runSync(String command,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      List<String>? shellArgs,
      Encoding? stdoutEncoding = systemEncoding,
      Encoding? stderrEncoding = systemEncoding}) {
    final args = <String>[];
    String? exe;

    if (isWindows && runInShell) {
      exe = createTempScriptSync(command);
    } else {
      exe = _prepareRun(args, command, runInShell);
    }

    if (exe.isEmpty) {
      return getEmptyResult(1);
    }

    try {
      return Process.runSync(exe, args,
        workingDirectory: workingDirectory,
        environment: environment,
        includeParentEnvironment: includeParentEnvironment,
        runInShell: false,
        stdoutEncoding: stdoutEncoding,
        stderrEncoding: stderrEncoding);
    } finally {
      if (isWindows && runInShell) {
        deleteTempScriptSync(exe);
      }
    }
  }

  /// Set default OS-specific shell
  ///
  static String setDefaultShell({String? exe, bool force = false}) {
    if ((exe == null) || exe.isEmpty) {
      if (force || shell.isEmpty) {
        shell = getShell();
      }
    } else {
      shell = exe;
    }

    return shell;
  }

  /// Split an arbitrary command into separate unquoted tokens
  ///
  /// This method is a substantial rework of `shellSplit()` from
  /// the `io` package, as the latter is POSIX-specific and fails
  /// under Windows. That method also fails to split 'ab|cde' or
  /// 'ab>cde' into three arguments. As well as behaves wrongly
  /// when  the first quote appears inside the current token like
  /// --option="value"
  ///
  static List<String> split(String command) {
    final args = <String>[];

    // If command is empty, just leave
    //
    if (command.isEmpty) {
      return args;
    }

    // Should not trim command from the right, as there might happen
    // trailing escaped space
    //
    command = command.trimLeft();

    var hasToken = false; // not [token.isEmpty] when token gets restarted
    var isEscaped = false; // true when the escape character encountered
    var isInnerQuoted = false; // in case of something like --option="value"
    var next = 0; // next char code from command
    var prev = 0; // previous char code from comman
    var quoteLevel = 0; // 1 = single-quoted, 2 = double-quoted
    var quoteStart = -1; // position of the outer left quote character
    final scanner = StringScanner(command);
    final token = StringBuffer(); // buffer for the current arg

    while (!scanner.isDone) {
      prev = next;
      next = scanner.readChar();

      if (isEscaped) {
        hasToken = true;
        if (next != $lf) {
          isEscaped = false;
          token.writeCharCode(next);
        }
        continue;
      }

      if (next == $escape) {
        if (quoteLevel == 1) {
          hasToken = true;
          token.writeCharCode($escape);
        } else {
          isEscaped = true;
        }
        continue;
      }

      if ((quoteLevel > 0) &&
          (next != $singleQuote) &&
          (next != $doubleQuote)) {
        // Being inside a literal string, just add the non-escaped character
        token.writeCharCode(next);
        continue;
      }

      if (next == $lineCommentStart) {
        // Section 2.3: If the current character is a line comment start
        // [and the previous characters was not part of a word], it and all
        // subsequent characters up to, but excluding, the next <newline>
        // shall be discarded as a comment. The <newline> that ends the line
        // is not considered part of the comment.
        //
        if (hasToken) {
          token.writeCharCode(next);
        } else {
          while (!scanner.isDone && scanner.peekChar() != $lf) {
            scanner.readChar();
          }
        }
        continue;
      }

      switch (next) {
        case $singleQuote:
        case $doubleQuote:
          final endQuoteLevel = (next == $singleQuote ? 1 : 2);
          final oppQuoteLevel = (next == $singleQuote ? 2 : 1);

          if (quoteLevel == endQuoteLevel) {
            if (isInnerQuoted) {
              token.writeCharCode(next);
              isInnerQuoted = false;
            }
            quoteLevel = 0;
            quoteStart = -1;
            break; // go to add token
          }
          if (quoteLevel == oppQuoteLevel) {
            token.writeCharCode(next);
          } else {
            if (hasToken) {
              isInnerQuoted = true;
              token.writeCharCode(next);
            }
            quoteLevel = endQuoteLevel;
            quoteStart = scanner.position - 1;
          }
          continue;
        case $ampersand:
        case $greaterThan:
        case $lessThan:
        case $pipe:
        case $openBracket:
        case $closeBracket:
        case $openParenthesis:
        case $closeParenthesis:
          if ((next == $openParenthesis) || (next == $closeParenthesis)) {
            if ((prev == $at) || (prev == $dollar)) {
              break;
            }
          }
          if (hasToken) {
            args.add(token.toString());
            token.clear();
          }

          hasToken = true;
          token.writeCharCode(next);

          while (!scanner.isDone && scanner.scanChar(next)) {
            token.writeCharCode(next);
          }
          break;
        case $space:
        case $tab:
        case $lf:
          if (hasToken) {
            break; // go to add token
          }
          continue;
        default:
          hasToken = true;
          token.writeCharCode(next);
          continue;
      }

      args.add(token.toString());
      token.clear();
      hasToken = false;
    }

    if (quoteLevel > 0) {
      final type = (quoteLevel == 1 ? 'single' : 'double');
      scanner.error('Unmatched $type quote.', position: quoteStart, length: 1);
    }

    if (hasToken) {
      args.add(token.toString());
    }

    return args;
  }

  /// Find full path by checking [fileName] in every directory of the PATH (non-blocking).\
  /// Returns [fileName] if [alwaysFound] is true, or an empty string otherwise.
  ///
  static Future<String> which(String fileName,
      {bool alwaysFound = false}) async {
    if (fileName != p.basename(fileName)) {
      return p.canonicalize(fileName);
    }

    var dirLst = <String>[];
    var extLst = <String>[];
    var title = _prepareWhich(fileName, dirLst, extLst);

    for (final dir in dirLst) {
      for (final ext in extLst) {
        final fullPath = p.join(dir, title + ext);

        if (await File(fullPath).exists()) {
          return fullPath;
        }
      }
    }

    return '';
  }

  /// Find full path by checking [fileName] in every directory of the PATH (blocking).\
  /// If [fileName] contains directory, returns canonicalized path (lowered in Windows).\
  /// If [fileName] is found in one of the PATH directories, returns full path as
  /// a join between that directory and [fileName]. Otherwise, returns an empty string.
  ///
  static String whichSync(String fileName) {
    if (fileName != p.basename(fileName)) {
      return p.canonicalize(fileName);
    }

    var dirLst = <String>[];
    var extLst = <String>[];
    var title = _prepareWhich(fileName, dirLst, extLst);

    for (final dir in dirLst) {
      for (final ext in extLst) {
        final fullPath = p.join(dir, title + ext);

        if (File(fullPath).existsSync()) {
          return fullPath;
        }
      }
    }

    return '';
  }

  /// Converts command to script
  ///
  static String _getScriptPrefix() {
    var prefix = tempScriptPrefix;

    if (isWindows) {
      prefix += (isWindows ? '' : '.bat');
    }

    return prefix;
  }

  /// Retrieves directory list from PATH variable and fills the list of
  /// extensions with either the current extension or from PATHEXT if
  /// [fileName] has no extension under Windows
  ///
  static String _prepareRun(List<String> args, String command, bool runInShell) {
    var exe = '';
    args.clear();

    setDefaultShell();

    if (runInShell) {
      exe = getShell();
      args.add(isWindows ? '/c' : '-c');
      
      if (!isWindows) {
        args.add(command);
      }
    } else {
      args.addAll(split(command));
      exe = extractExecutable(args);
    }

    return exe;
  }

  /// Retrieves directory list from PATH variable and fills the list of
  /// extensions with either the current extension or from PATHEXT if
  /// [fileName] has no extension under Windows
  ///
  static String _prepareWhich(
      String fileName, List<String> dirLst, List<String> extLst) {
    var ext = p.extension(fileName);
    var tit = fileName.substring(0, fileName.length - ext.length);

    var env = Platform.environment;

    dirLst.clear();
    dirLst.addAll((env['PATH'] ?? '').split(dirListSeparator));

    extLst.clear();

    if (isWindows) {
      if (ext.isNotEmpty) {
        extLst.add(ext);
      }
      extLst.addAll((env['PATHEXT'] ?? '').split(dirListSeparator));
    } else {
      extLst.add(ext);
    }

    return tit;
  }

  /// Converts command to script
  ///
  static String _toScript(String command) {
    if (command.isEmpty || isWindows) {
      return command;
    }
    
    final nl = lineBreak;
    return '@echo off$nl$command${nl}exit /B %errorlevel%$nl';
  }
}
