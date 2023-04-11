// Copyright (c) 2023, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)

import 'dart:convert';
import 'dart:io';

import 'package:charcode/charcode.dart';
import "package:path/path.dart" as p;
import 'package:string_scanner/string_scanner.dart';

/// Static API to split an arbitrary command and to execute that
///
class ShellCmd {
  /// Default shell executable and its args as a single string ([text])
  ///
  static final defaultShellCommand = (isWindows ? 'cmd.exe /c' : 'sh -c');

  /// Separator used to split directories in the PATH variable (OS-specific)
  ///
  static final dirListSeparator = (isWindows ? ';' : ':');

  /// Const: char for the character escaping (OS-specific)
  ///
  static final escapeChar = isWindows ? '^' : r'\';

  /// Const: char code for the character escaping (OS-specific)
  ///
  static final escapeCharCode = isWindows ? $circumflex : $backslash;

  /// Const: char for the character escaping (OS-specific)
  ///
  static final escapeCharEscaped = escapeChar + escapeChar;

  /// Const: Line separator (OS-specific)
  ///
  static final lineBreak = (isWindows ? '\r\n' : '\n');

  /// Const: char for the line comment start (OS-specific)
  ///
  static final lineCommentStartChar = isWindows ? '' : '#';

  /// Const: char code for the line comment start (OS-specific)
  ///
  static final lineCommentStartCharCode = isWindows ? 0 : $hash;

  /// Const: plain space char
  ///
  static const spaceChar = ' ';

  /// Const: plain space char escaped (OS-specific)
  ///
  static final spaceCharEscaped = escapeChar + spaceChar;

  /// Const: tab char
  ///
  static final tabChar = '\t';

  /// Const: plain space char escaped (OS-specific)
  ///
  static final tabCharEscaped = escapeChar + tabChar;

  /// Const: current OS is Windows
  ///
  static final isWindows = Platform.isWindows;

  /// Const: environment variable name to retrieve OS default shell
  ///
  static final shellEnvKey = (isWindows ? 'COMSPEC' : 'SHELL');

  /// Const: temporary script name as well as temporary dir prefix
  ///
  static const tempScriptName = 'shell_cmd';

  /// Actual arguments
  ///
  final args = <String>[];

  /// Program (executable) path
  ///
  var program = '';

  /// When true, running the command in shell is recommended
  ///
  var runInShell = false;

  /// Current shell
  ///
  static var shell = ShellCmd()..copyFrom(_defaultShell);

  /// Command text
  ///
  var text = '';

  /// Command text
  ///
  static var _isInitialized = false;

  /// Default shell executable and its args
  ///
  static final _defaultShell = ShellCmd(defaultShellCommand);

  /// Default constructor
  ///
  ShellCmd([String? command]) {
    parse(command);

    if (!_isInitialized) {
      _isInitialized = true;
      resetShell();
    }
  }

  static ShellCmd fromParsed(String program, List<String> args,
          {String? text}) =>
      ShellCmd()..init(text, program, args);

  /// Resets instance properties
  ///
  void clear() {
    args.clear();
    program = '';
    runInShell = false;
    text = '';
  }

  /// Copy constructor
  ///
  void copyFrom(ShellCmd that,
          {String? text, String? program, List<String>? args}) =>
      init(text ?? that.text, program ?? that.program, args ?? that.args);

  /// Under POSIX-compliant OS, does nothing and returns null.\
  /// Under Windows, creates a temporary directory (non-blocking)
  /// and returns that
  ///
  static Future<Directory> createTempDir() async =>
      await Directory.systemTemp.createTemp(tempScriptName);

  /// Under POSIX-compliant OS, does nothing and returns null.\
  /// Under Windows, creates a temporary directory (blocking)
  /// and returns that
  ///
  static Directory createTempDirSync() =>
      Directory.systemTemp.createTempSync(tempScriptName);

  /// Under POSIX-compliant OS, does nothing and returns an empty string.\
  /// Under Windows, creates a temporary folder (non-blocking) and writes
  /// [command] to an output file.\
  /// This file should be executed and deleted with the containing folder
  ///
  static Future<String> createTempScript(String? command) async {
    if ((command == null) || command.isEmpty) {
      return '';
    }

    final dir = await createTempDir();
    final path = p.join(dir.path, _getScriptName());
    final file = File(path);

    try {
      final script = _toScript(command);
      await file.writeAsString(script, flush: true);
      return path;
    } on Exception catch (_) {
      await deleteTempScript(path);
      rethrow;
    } on Error catch (_) {
      await deleteTempScript(path);
      rethrow;
    }
  }

  /// Under POSIX-compliant OS, does nothing and returns an empty string.\
  /// Under Windows, creates a temporary folder (blocking) and writes
  /// [command] to an output file.\
  /// This file should be executed and deleted with the containing folder
  ///
  static String createTempScriptSync(String? command) {
    if ((command == null) || command.isEmpty) {
      return '';
    }

    final dir = createTempDirSync();

    final scriptPath = p.join(dir.path, _getScriptName());
    final scriptFile = File(scriptPath);

    try {
      final script = _toScript(command);
      scriptFile.writeAsStringSync(script, flush: true);
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

  /// Convenience method to merge program and arguments into a single string
  ///
  static String escape(String arg) {
    final argLen = arg.length;

    if (argLen <= 0) {
      return arg;
    }

    final firstChar = arg[0];
    final lastChar = arg[argLen - 1];

    if ((argLen > 1) && (firstChar == lastChar)) {
      if ((firstChar == "'") || (firstChar == '"')) {
        return arg;
      }
    }

    final hasSpaces = arg.contains(spaceChar);
    final hasTabs = arg.contains(tabChar);

    if (!hasSpaces && !hasTabs) {
      return arg;
    }

    final hasEscapes = arg.contains(escapeChar);

    if (hasEscapes) {
      arg = arg.replaceAll(escapeChar, escapeCharEscaped);
    }

    if (hasSpaces) {
      arg = arg.replaceAll(spaceChar, spaceCharEscaped);
    }

    if (hasTabs) {
      arg = arg.replaceAll(tabChar, tabCharEscaped);
    }

    return arg;
  }

  /// Get empty process result in case of no need to run command
  ///
  static ProcessResult getEmptyResult(int exitCode, [String? error]) =>
      ProcessResult(0, exitCode, null, error);

  /// Copy constructor
  ///
  void init([String? newText, String? newProgram, List<String>? newArgs]) {
    program = newProgram ?? '';
    args.clear();

    if ((newArgs != null) && newArgs.isNotEmpty) {
      args.addAll(newArgs);
    }

    setText(newText);
  }

  /// Copy from the default shell
  ///
  static ShellCmd resetShell() {
    final shellProg =
        Platform.environment[shellEnvKey] ?? _defaultShell.program;
    return shell..copyFrom(_defaultShell, program: shellProg);
  }

  /// Split an arbitrary [command] and execute that in the non-blocking mode.
  ///
  Future<ProcessResult> run(
      {String? command,
      String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool? runInShell,
      Encoding? stdoutEncoding = systemEncoding,
      Encoding? stderrEncoding = systemEncoding}) async {
    runInShell ??= this.runInShell;
    var tempScriptPath = await _prepareRun(command, runInShell);

    if (program.isEmpty) {
      return getEmptyResult(1);
    }

    try {
      return await Process.run(program, args,
          workingDirectory: workingDirectory,
          environment: environment,
          includeParentEnvironment: includeParentEnvironment,
          runInShell: false,
          stdoutEncoding: stdoutEncoding,
          stderrEncoding: stderrEncoding);
    } finally {
      if (tempScriptPath.isNotEmpty) {
        deleteTempScriptSync(tempScriptPath);
      }
    }
  }

  /// Split an arbitrary [command] and execute that in the blocking mode.
  ///
  ProcessResult runSync(
      {String? command,
      String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool? runInShell,
      Encoding? stdoutEncoding = systemEncoding,
      Encoding? stderrEncoding = systemEncoding}) {
    runInShell ??= this.runInShell;
    var tempScriptPath = _prepareRunSync(command, runInShell);

    if (isWindows && runInShell) {
      tempScriptPath = createTempScriptSync(text);
      command = tempScriptPath;
    }

    if (program.isEmpty) {
      return getEmptyResult(1);
    }

    try {
      return Process.runSync(program, args,
          workingDirectory: workingDirectory,
          environment: environment,
          includeParentEnvironment: includeParentEnvironment,
          runInShell: false,
          stdoutEncoding: stdoutEncoding,
          stderrEncoding: stderrEncoding);
    } finally {
      if (tempScriptPath.isNotEmpty) {
        deleteTempScriptSync(tempScriptPath);
      }
    }
  }

  /// Set default OS-specific shell
  ///
  static ShellCmd setShell({String? command, bool force = false}) {
    if ((command == null) || command.isEmpty) {
      if (force || shell.program.isEmpty) {
        resetShell();
      }
    } else {
      shell.parse(command);
    }

    return shell;
  }

  /// Split an arbitrary command into separate unquoted tokens,
  /// move the first one to [program] and set [text].
  ///
  /// This method is a substantial rework of `shellSplit()` from
  /// the `io` package, as the latter is POSIX-specific and fails
  /// under Windows. That method also fails to split 'ab|cde' or
  /// 'ab>cde' into three arguments. As well as behaves wrongly
  /// when  the first quote appears inside the current token like
  /// --option="value"
  ///
  /// Populates instance members of 'this' and return is it
  ///
  void parse([String? text]) {
    clear();

    if ((text != null) && text.isNotEmpty) {
      // Should not trim command from the right, as there might happen
      // trailing escaped space
      //
      this.text = text.trimLeft();
    }

    // If command is empty, just leave
    //
    if (this.text.isEmpty) {
      return;
    }

    var hasToken = false; // not [token.isEmpty] when token gets restarted
    var isEscaped = false; // true when the escape character encountered
    var isInnerQuoted = false; // in case of something like --option="value"
    var next = 0; // next char code from command
    var prev = 0; // previous char code from comman
    var quoteLevel = 0; // 1 = single-quoted, 2 = double-quoted
    var quoteStart = -1; // position of the outer left quote character
    final scanner = StringScanner(this.text);
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

      if (next == escapeCharCode) {
        if (quoteLevel == 1) {
          hasToken = true;
          token.writeCharCode(escapeCharCode);
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

      if (next == lineCommentStartCharCode) {
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
          runInShell = true;

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
          if (next == $lf) {
            runInShell = true;
          }
          continue;
        default:
          if (isWindows) {
            switch (next) {
              case $exclamation:
              case $percent:
              case $plus:
                runInShell = true;
            }
          } else {
            switch (next) {
              case $exclamation:
              case $backquote:
              case $dollar:
              case $openBrace:
              case $closeBrace:
              case $semicolon:
                runInShell = true;
            }
          }
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

    if (args.isNotEmpty) {
      program = args[0];
      args.removeAt(0);
    } else {
      runInShell = false;
    }

    return;
  }

  /// Set [text] to the argument [newText]. If the latter is null,
  /// then merge [program] and [args] to [text].
  ///
  String setText([String? newText]) {
    if ((newText != null) && newText.isNotEmpty) {
      text = newText;
      return text;
    }

    var result = StringBuffer(escape(program));

    for (var i = 0, n = args.length; i < n; i++) {
      if (result.isNotEmpty) {
        result.write(spaceChar);
      }
      result.write(escape(args[i]));
    }

    text = result.toString();

    return text;
  }

  /// Serializer
  ///
  @override
  String toString() => text;

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

  /// Returns temporary script filename
  ///
  static String _getScriptName() =>
      (isWindows ? '$tempScriptName.bat' : tempScriptName);

  /// Non-blocking wrapper to call [__prepareRun] and to create temp
  /// script if needed.
  ///
  /// Returns path to temp script when relevant or an empty string.
  ///
  Future<String> _prepareRun(String? command, bool runInShell) async {
    var tempScriptPath = '';

    if (isWindows && runInShell) {
      tempScriptPath = await createTempScript(text);
      command = tempScriptPath;
    }

    __prepareRun(command, runInShell);

    return tempScriptPath;
  }

  /// blocking wrapper to call [__prepareRun] and to create temp
  /// script if needed.
  ///
  /// Returns path to temp script when relevant or an empty string.
  ///
  String _prepareRunSync(String? command, bool runInShell) {
    var tempScriptPath = '';

    if (isWindows && runInShell) {
      tempScriptPath = createTempScriptSync(text);
      command = tempScriptPath;
    }

    __prepareRun(command, runInShell);

    return tempScriptPath;
  }

  /// Retrieves directory list from PATH variable and fills the list of
  /// extensions with either the current extension or from PATHEXT if
  /// [fileName] has no extension under Windows
  ///
  void __prepareRun(String? command, bool runInShell) {
    final hasNewText =
        ((command != null) && command.isNotEmpty && (command != text));

    setShell();

    if (!runInShell) {
      if (hasNewText) {
        parse(command);
      }
      return;
    }

    final newText = (hasNewText ? command : text);
    copyFrom(shell);
    args.add(newText);
    setText();
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

  /// Converts command to a content of a script:/ for POSIХ-compliant OS
  /// returns command as is, for Windows, returns a simple wrapper.
  ///
  static String _toScript(String command) {
    if (command.isEmpty || !isWindows) {
      return command;
    }

    return '@$command$lineBreak@exit /B %errorlevel%$lineBreak';
  }
}
