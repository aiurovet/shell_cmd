// Copyright (c) 2023, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shell_cmd/shell_cmd.dart';
import 'package:test/test.dart';

/// Expect with resources (non-blocking)
///
Future<void> expRes(Directory dir, dynamic actual, dynamic expected) async {
  try {
    expect(actual, expected);
  } finally {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}

/// Expect with resources (blocking)
///
void expResSync(Directory dir, dynamic actual, dynamic expected) {
  try {
    expect(actual, expected);
  } finally {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }
}

/// Test entry point
///
void main() {
  final env = Platform.environment;
  final isWindows = Platform.isWindows;
  final e = ShellCmd.escapeChar;
  final n = ShellCmd.lineBreak;
  final q = (isWindows ? '"' : '');

  group('clear -', () {
    test('clear', () {
      final cmd = ShellCmd('abc de f');
      cmd.clear();
      expect([cmd.runInShell, cmd.program.isEmpty, cmd.args.isEmpty],
          [false, true, true]);
    });
  });
  group('copyFrom -', () {
    test('object only', () {
      final cmd = ShellCmd('abc de f');
      final shell = ShellCmd.defaultShell;
      cmd.copyFrom(shell);
      expect([cmd.source, cmd.program, cmd.args],
          [shell.source, shell.program, shell.args]);
    });
    test('with source', () {
      final cmd = ShellCmd('abc de f');
      final shell = ShellCmd.defaultShell;
      cmd.copyFrom(shell, source: 'xyz');
      expect([cmd.source, cmd.program, cmd.args],
          ['xyz', shell.program, shell.args]);
    });
    test('with program', () {
      final cmd = ShellCmd('abc de f');
      final shell = ShellCmd.defaultShell;
      cmd.copyFrom(shell, program: 'xyz');
      expect([cmd.source, cmd.program, cmd.args],
          [shell.source, 'xyz', shell.args]);
    });
    test('with args', () {
      final cmd = ShellCmd('abc de f');
      final shell = ShellCmd.defaultShell;
      cmd.copyFrom(shell, args: ['x', 'yz']);
      expect([
        cmd.source,
        cmd.program,
        cmd.args
      ], [
        shell.source,
        shell.program,
        ['x', 'yz']
      ]);
    });
  });
  group('escape -', () {
    test('empty', () {
      expect(ShellCmd.escape(''), '');
    });
    test('single escape', () {
      expect(ShellCmd.escape(e), e);
    });
    test('single space', () {
      expect(ShellCmd.escape(' '), '$e ');
    });
    test('single tab', () {
      expect(ShellCmd.escape('\t'), '$e\t');
    });
    test('a mix', () {
      expect(
          ShellCmd.escape(' a \t  bc $e\t'), '$e a$e $e\t$e $e bc$e $e$e$e\t');
    });
  });
  group('fromParsed/init -', () {
    test('empty', () {
      final cmd = ShellCmd.fromParsed('', []);
      expect([cmd.runInShell, cmd.program.isEmpty, cmd.args.isEmpty],
          [false, true, true]);
    });
    test('program only', () {
      final cmd = ShellCmd.fromParsed('ab c', []);
      expect([cmd.runInShell, cmd.program, cmd.args], [false, 'ab c', []]);
    });
    test('args only', () {
      final cmd = ShellCmd.fromParsed('', ['ab', 'c d']);
      expect([
        cmd.program,
        cmd.args
      ], [
        '',
        ['ab', 'c d']
      ]);
    });
    test('full', () {
      final cmd = ShellCmd.fromParsed('a bc', ['d e', 'f']);
      expect([
        cmd.program,
        cmd.args
      ], [
        'a bc',
        ['d e', 'f']
      ]);
    });
  });
  group('parse - OS-insensitive -', () {
    test('empty', () {
      final cmd = ShellCmd()..parse('');
      expect([cmd.runInShell, cmd.program, cmd.args], [false, '', []]);
    });
    test('single plain arg', () {
      final cmd = ShellCmd()..parse('abc');
      expect([cmd.runInShell, cmd.program, cmd.args], [false, 'abc', []]);
    });
    test('multiple plain args', () {
      final cmd = ShellCmd()..parse('abc de f');
      expect([
        cmd.runInShell,
        cmd.program,
        cmd.args
      ], [
        false,
        'abc',
        ['de', 'f']
      ]);
    });
    test('multiple single-quoted args', () {
      final cmd = ShellCmd()..parse("'ab c' ' d e ' 'f '");
      expect([
        cmd.runInShell,
        cmd.program,
        cmd.args
      ], [
        false,
        'ab c',
        [' d e ', 'f ']
      ]);
    });
    test('multiple double-quoted args', () {
      final cmd = ShellCmd()..parse('"ab c" " d e " "f "');
      expect([
        cmd.runInShell,
        cmd.program,
        cmd.args
      ], [
        false,
        'ab c',
        [' d e ', 'f ']
      ]);
    });
    test('break in 3', () {
      final cmd = ShellCmd()..parse('ab||c');
      expect([
        cmd.runInShell,
        cmd.program,
        cmd.args
      ], [
        true,
        'ab',
        ['||', 'c']
      ]);
    });
    test('break in 4', () {
      final cmd = ShellCmd()..parse('(ab c)');
      expect([
        cmd.runInShell,
        cmd.program,
        cmd.args
      ], [
        true,
        '(',
        ['ab', 'c', ')']
      ]);
    });
    test('break in 4 with surrounding spaces', () {
      final cmd = ShellCmd()..parse('[ab c]');
      expect([
        cmd.runInShell,
        cmd.program,
        cmd.args
      ], [
        true,
        '[',
        ['ab', 'c', ']']
      ]);
    });
    test('single quote in a middle', () {
      final cmd = ShellCmd()..parse("ab --opt='valu e'");
      expect([
        cmd.runInShell,
        cmd.program,
        cmd.args
      ], [
        false,
        'ab',
        ["--opt='valu e'"]
      ]);
    });
    test('double quote in a middle', () {
      final cmd = ShellCmd()..parse('ab --opt="valu e"');
      expect([
        cmd.runInShell,
        cmd.program,
        cmd.args
      ], [
        false,
        'ab',
        ['--opt="valu e"']
      ]);
    });
    test('tab between args', () {
      final cmd = ShellCmd()..parse('ab\tc');
      expect([
        cmd.runInShell,
        cmd.program,
        cmd.args
      ], [
        false,
        'ab',
        ['c']
      ]);
    });
    test('tab inside a single-quoted arg', () {
      final cmd = ShellCmd()..parse("'ab\tc'");
      expect([cmd.runInShell, cmd.program, cmd.args], [false, 'ab\tc', []]);
    });
    test('tab inside a double-quoted arg', () {
      final cmd = ShellCmd()..parse('"ab\tc"');
      expect([cmd.runInShell, cmd.program, cmd.args], [false, 'ab\tc', []]);
    });
    test(r'$ runInShell', () {
      final cmd = ShellCmd()..parse(r'ab $cd');
      expect([
        cmd.runInShell,
        cmd.program,
        cmd.args
      ], [
        !isWindows,
        'ab',
        [r'$cd']
      ]);
    });
    test(r'% runInShell', () {
      final cmd = ShellCmd()..parse(r'ab %1');
      expect([
        cmd.runInShell,
        cmd.program,
        cmd.args
      ], [
        isWindows,
        'ab',
        [r'%1']
      ]);
    });
  });
  group('parse - OS-sensitive -', () {
    final a = (e == r'\' ? r'^' : r'\');

    test('single arg with escape', () {
      final cmd = ShellCmd()..parse('ab$e c$e$e');
      expect([cmd.runInShell, cmd.program, cmd.args], [false, 'ab c$e', []]);
    });
    test('multiple escaped args', () {
      final cmd = ShellCmd()..parse('ab$e c d$e${e}e f$e ');
      expect([
        cmd.runInShell,
        cmd.program,
        cmd.args
      ], [
        false,
        'ab c',
        ['d${e}e', 'f ']
      ]);
    });
    test('single arg with non-escape', () {
      final cmd = ShellCmd()..parse('a$a${a}b$a c$a$a');
      expect([
        cmd.runInShell,
        cmd.program,
        cmd.args
      ], [
        false,
        'a$a${a}b$a',
        ['c$a$a']
      ]);
    });
    test('single-quoted with escape', () {
      final cmd = ShellCmd()..parse("'ab$e c$e$e'");
      expect(
          [cmd.runInShell, cmd.program, cmd.args], [false, 'ab$e c$e$e', []]);
    });
    test('double-quoted with escape', () {
      final cmd = ShellCmd()..parse('"ab$e c$e$e"');
      expect([cmd.runInShell, cmd.program, cmd.args], [false, 'ab c$e', []]);
    });
    test('single-quoted with non-escape', () {
      final cmd = ShellCmd()..parse("'a$a${a}b$a c$a'");
      expect([cmd.runInShell, cmd.program, cmd.args],
          [false, 'a$a${a}b$a c$a', []]);
    });
    test('double-quoted with non-escape', () {
      final cmd = ShellCmd()..parse('"a$a${a}b$a c"');
      expect(
          [cmd.runInShell, cmd.program, cmd.args], [false, 'a$a${a}b$a c', []]);
    });
    test('line continuation', () {
      final cmd = ShellCmd()..parse('ab$e\n c');
      expect([cmd.runInShell, cmd.program, cmd.args], [false, 'ab c', []]);
    });
    test('tab escaped', () {
      final cmd = ShellCmd()..parse('ab$e\tc');
      expect([cmd.runInShell, cmd.program, cmd.args], [false, 'ab\tc', []]);
    });
    test('tab escaped and single-quoted', () {
      final cmd = ShellCmd()..parse("'ab$e\tc'");
      expect([cmd.runInShell, cmd.program, cmd.args], [false, 'ab$e\tc', []]);
    });
    test('tab escaped and double-quoted', () {
      final cmd = ShellCmd()..parse('"ab$e\tc"');
      expect([cmd.runInShell, cmd.program, cmd.args], [false, 'ab\tc', []]);
    });
    test('tab inside a double-quoted arg', () {
      final cmd = ShellCmd()..parse('"ab\tc"');
      expect([cmd.runInShell, cmd.program, cmd.args], [false, 'ab\tc', []]);
    });
  });
  group('run -', () {
    test('echo', () async {
      final r = await ShellCmd('echo Abc$e def').run(runInShell: isWindows);
      expect(r.stdout.toString(), 'Abc def$n');
    });
    test('dart --version', () async {
      final r = await ShellCmd(r'dart --version').run();
      expect(r.stdout.toString().startsWith('Dart SDK version: '), true);
    });
    test('env vars', () async {
      final key = (isWindows ? r'USERPROFILE' : 'HOME');
      final cmd = ShellCmd(isWindows ? 'echo "%$key%"' : 'echo "\${$key}"');
      final r = await cmd.run(runInShell: true);
      expect(r.stdout.toString(), '$q${env[key]}$q$n');
    });
    test('env vars blocked', () {
      final key = (isWindows ? r'USERPROFILE' : 'HOME');
      final cmd =
          ShellCmd(isWindows ? 'echo %$key:~2,6%' : r'echo "\$' + key + r'"');
      final r = cmd.runSync(runInShell: true);
      expect(r.stdout.toString(), (isWindows ? '\\Users$n' : '\$$key$n'));
    });
  });
  group('shell -', () {
    test('reset -', () {
      final defArgs = ShellCmd.defaultShell.args;
      final defProg = ShellCmd.defaultShell.program;
      final expProg = env[ShellCmd.shellEnvKey] ?? defProg;
      final shell = ShellCmd.resetShell();
      expect([shell.program, shell.args], [expProg, defArgs]);
    });
    test('set - was empty and not forced', () {
      final shell = ShellCmd.shell;
      shell.clear();
      ShellCmd.setShell(command: 'abc def', force: false);

      expect([
        shell.program,
        shell.args
      ], [
        'abc',
        ['def']
      ]);
    });
    test('set - was not empty and not forced', () {
      final shell = ShellCmd.shell;
      shell.program = 'xyz';
      shell.args.clear();
      ShellCmd.setShell(command: 'abc def', force: false);

      expect([
        shell.program,
        shell.args
      ], [
        'abc',
        ['def']
      ]);
    });
    test('set - default - was empty, and not forced', () {
      final shell = ShellCmd.shell;
      final expArgs = ShellCmd.defaultShell.args;
      shell.clear();
      ShellCmd.setShell(force: false);

      expect([shell.program.isNotEmpty, shell.args], [true, expArgs]);
    });
    test('set - default - was not empty, and not forced', () {
      final shell = ShellCmd.shell;
      shell.program = 'xyz';
      shell.args.clear();
      ShellCmd.setShell(force: false);

      expect([shell.program, shell.args], ['xyz', []]);
    });
    test('set - default - was not empty, and forced', () {
      final shell = ShellCmd.shell;
      final expArgs = ShellCmd.defaultShell.args;
      shell.program = 'xyz';
      shell.args.clear();
      ShellCmd.setShell(force: true);

      expect([shell.program == 'xyz', shell.args], [false, expArgs]);
    });
  });
  group('temp script -', () {
    test('create temp dir - async', () async {
      final dir = await ShellCmd.createTempDir();
      final exists = await dir.exists();
      await expRes(dir, [
        dir.path.startsWith(p.join(Directory.systemTemp.path, 'shell_cmd')),
        exists
      ], [
        true,
        true
      ]);
    });
    test('create temp dir - sync', () {
      final dir = ShellCmd.createTempDirSync();
      final exists = dir.existsSync();
      expResSync(dir, [
        dir.path.startsWith(p.join(Directory.systemTemp.path, 'shell_cmd')),
        exists
      ], [
        true,
        true
      ]);
    });
    test('create temp script - async', () async {
      final path = await ShellCmd.createTempScript('abc de f');
      final file = File(path);
      final exists = await file.exists();
      final data = exists ? await file.readAsString() : '';
      await expRes(file.parent, [exists, data], [true, 'abc de f']);
    });
    test('create temp script - sync', () {
      final path = ShellCmd.createTempScriptSync('abc de f');
      final file = File(path);
      final exists = file.existsSync();
      final data = exists ? file.readAsStringSync() : '';
      expResSync(file.parent, [exists, data], [true, 'abc de f']);
    });
    test('delete temp script - async', () async {
      final path = await ShellCmd.createTempScript('abc de f');
      final dir = Directory(p.dirname(path));
      final existsBefore = await File(path).exists();
      await ShellCmd.deleteTempScript(path);
      final existsAfter = await dir.exists();
      expect([existsBefore, existsAfter], [true, false]);
    });
    test('delete temp script - sync', () {
      final path = ShellCmd.createTempScriptSync('abc de f');
      final dir = Directory(p.dirname(path));
      final existsBefore = File(path).existsSync();
      ShellCmd.deleteTempScriptSync(path);
      final existsAfter = dir.existsSync();
      expect([existsBefore, existsAfter], [true, false]);
    });
  });
  group('toString -', () {
    final cmd = ShellCmd();

    test('null', () {
      cmd.init();
      expect(cmd.toString(), '');
    });
    test('empty', () {
      cmd.init('');
      expect(cmd.toString(), '');
    });
    test('single arg, no space', () {
      cmd.init('abc');
      expect(cmd.toString(), 'abc');
    });
    test('single arg with spaces', () {
      cmd.init(null, 'ab c');
      expect(cmd.toString(), 'ab$e c');
    });
    test('multiple args, no space', () {
      cmd.init(null, 'abc', ['def', 'ghi']);
      expect(cmd.toString(), 'abc def ghi');
    });
    test('multiple args with escapes, spaces and tabs', () {
      cmd.init(null, 'ab c', ['d\tef', 'g h$e\t \ti']);
      expect(cmd.toString(), 'ab$e c d$e\tef g$e h$e$e$e\t$e $e\ti');
    });
  });
  group('which -', () {
    test('cmd/echo', () async {
      if (isWindows) {
        final sysRoot = env['SystemRoot'];
        final resolved =
            p.canonicalize(p.join(p.join(sysRoot!, 'system32'), 'cmd.exe'));
        expect(p.canonicalize(await ShellCmd.which(r'cmd')), resolved);
      } else {
        expect(await ShellCmd.which(r'echo'), '/usr/bin/echo');
      }
    });
  });
  group('whichSync -', () {
    test('cmd/echo', () {
      if (isWindows) {
        final sysRoot = env['SystemRoot'];
        final resolved =
            p.canonicalize(p.join(p.join(sysRoot!, 'system32'), 'cmd.exe'));
        expect(p.canonicalize(ShellCmd.whichSync(r'cmd')), resolved);
      } else {
        expect(ShellCmd.whichSync(r'echo'), '/usr/bin/echo');
      }
    });
  });
}
