// Copyright (c) 2023, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shell_cmd/shell_cmd.dart';
import 'package:shell_cmd/src/ascii_ext.dart';
import 'package:test/test.dart';

/// Test entry point
///
void main() {
  final isWindows = Platform.isWindows;
  final e = String.fromCharCode($escape);
  final n = ShellCmd.lineBreak;
  final q = (isWindows ? '"' : '');

  group('extractExecutable -', () {
    test('empty', () {
      expect(ShellCmd.extractExecutable([]), '');
    });
    test('single', () {
      final args = ['a b c'];
      final exe = ShellCmd.extractExecutable(args);
      expect([exe, args], ['a b c', []]);
    });
    test('multiple', () {
      final args = ['a b c', 'd', 'e f'];
      final exe = ShellCmd.extractExecutable(args);
      expect([
        exe,
        args
      ], [
        'a b c',
        ['d', 'e f']
      ]);
    });
  });
  group('shell -', () {
    test('getShell -', () {
      final expected = Platform.environment[ShellCmd.shellEnvKey];
      expect(ShellCmd.getShell(), expected);
    });
  });
  group('run -', () {
    test('echo', () async {
      final r = await ShellCmd.run('echo Abc$e def', runInShell: isWindows);
      expect(r.stdout.toString(), '${q}Abc def$q$n');
    });
    test('dart --version', () async {
      final r = await ShellCmd.run(r'dart --version');
      expect(r.stdout.toString().startsWith('Dart SDK version: '), true);
    });
    test('env vars', () async {
      final key = (isWindows ? r'USERPROFILE' : 'HOME');
      final cmd = (isWindows ? 'echo "%$key%"' : 'echo "\${$key}"');
      final r = await ShellCmd.run(cmd, runInShell: true);
      expect(r.stdout.toString(), '${Platform.environment[key]}$n');
    });
    test('env vars blocked', () async {
      final key = (isWindows ? r'USERPROFILE' : 'HOME');
      final cmd = (isWindows ? 'echo ^%$key^%' : 'echo "\\\$$key"');
      final r = await ShellCmd.run(cmd, runInShell: true);
      expect(r.stdout.toString(), (isWindows ? '%$key%$n' : '\$$key$n'));
    });
  });
  group('split -', () {
    test('empty', () {
      expect(ShellCmd.split(''), []);
    });
    test('single plain arg', () {
      expect(ShellCmd.split('abc'), ['abc']);
    });
    test('multiple plain args', () {
      expect(ShellCmd.split('abc de f'), ['abc', 'de', 'f']);
    });
    test('multiple single-quoted args', () {
      expect(ShellCmd.split("'ab c' ' d e ' 'f '"), ['ab c', ' d e ', 'f ']);
    });
    test('multiple double-quoted args', () {
      expect(ShellCmd.split('"ab c" " d e " "f "'), ['ab c', ' d e ', 'f ']);
    });
    test('break in 3', () {
      expect(ShellCmd.split('ab||c'), ['ab', '||', 'c']);
    });
    test('break in 4', () {
      expect(ShellCmd.split('(ab c)'), ['(', 'ab', 'c', ')']);
    });
    test('break in 4 with surrounding spaces', () {
      expect(ShellCmd.split(' [ ab c]'), ['[', 'ab', 'c', ']']);
    });
    test('single quote in a middle', () {
      expect(ShellCmd.split("ab --opt='valu e'"), ['ab', "--opt='valu e'"]);
    });
    test('double quote in a middle', () {
      expect(ShellCmd.split('ab --opt="valu e"'), ['ab', '--opt="valu e"']);
    });
    test('tab between args', () {
      expect(ShellCmd.split('ab\tc'), [r'ab', r'c']);
    });
    test('tab inside a single-quoted arg', () {
      expect(ShellCmd.split("'ab\tc'"), ["ab\tc"]);
    });
    test('tab inside a double-quoted arg', () {
      expect(ShellCmd.split('"ab\tc"'), ['ab\tc']);
    });
  });
  group('split -', () {
    final e = String.fromCharCode($escape);
    final a = (e == r'\' ? r'^' : r'\');

    test('single arg with escape', () {
      expect(ShellCmd.split('ab$e c$e$e'), ['ab c$e']);
    });
    test('multiple escaped args', () {
      expect(ShellCmd.split('ab$e c d$e${e}e f$e '), ['ab c', 'd${e}e', 'f ']);
    });
    test('single arg with non-escape', () {
      expect(ShellCmd.split('a$a${a}b$a c$a$a'), ['a$a${a}b$a', 'c$a$a']);
    });
    test('single-quoted with escape', () {
      expect(ShellCmd.split("'ab$e c$e$e'"), ['ab$e c$e$e']);
    });
    test('double-quoted with escape', () {
      expect(ShellCmd.split('"ab$e c$e$e"'), ['ab c$e']);
    });
    test('single-quoted with non-escape', () {
      expect(ShellCmd.split("'a$a${a}b$a c$a'"), ['a$a${a}b$a c$a']);
    });
    test('double-quoted with non-escape', () {
      expect(ShellCmd.split('"a$a${a}b$a c"'), ['a$a${a}b$a c']);
    });
    test('line continuation', () {
      expect(ShellCmd.split('ab$e\n c'), [r'ab c']);
    });
    test('tab escaped', () {
      expect(ShellCmd.split('ab$e\tc'), ['ab\tc']);
    });
    test('tab escaped and single-quoted', () {
      expect(ShellCmd.split("'ab$e\tc'"), ['ab$e\tc']);
    });
    test('tab escaped and double-quoted', () {
      expect(ShellCmd.split('"ab$e\tc"'), ['ab\tc']);
    });
    test('tab inside a double-quoted arg', () {
      expect(ShellCmd.split('"ab\tc"'), ['ab\tc']);
    });
  });
  group('which -', () {
    test('cmd/echo', () async {
      if (isWindows) {
        final sysRoot = Platform.environment['SystemRoot'];
        final resolved = p.canonicalize(p.join(p.join(sysRoot!, 'system32'), 'cmd.exe'));
        expect(p.canonicalize(await ShellCmd.which(r'cmd')), resolved);
      } else {
        expect(await ShellCmd.which(r'echo'), '/usr/bin/echo');
      }
    });
  });
  group('whichSync -', () {
    test('cmd/echo', () {
      if (isWindows) {
        final sysRoot = Platform.environment['SystemRoot'];
        final resolved = p.canonicalize(p.join(p.join(sysRoot!, 'system32'), 'cmd.exe'));
        expect(p.canonicalize(ShellCmd.whichSync(r'cmd')), resolved);
      } else {
        expect(ShellCmd.whichSync(r'echo'), '/usr/bin/echo');
      }
    });
  });
}
