## 0.2.5

- Website changed

## 0.2.4

- Bugfix: `shell` must be variable, and `defaultShell` should be private

## 0.2.3

- Bugfix: `shell` must be initialised automatically
- Bugfix: if SHELL/COMSPEC is undefined, `shell` should be a copy of `defaultShell`
- Removed unused `shellArgs` from `run` and `runSync`

## 0.2.2

- Breaking: renamed `source` to `text` and `setSource` to `setText`.
- Added another `runSync` test.

## 0.2.1

- Refactored `tempScriptPrefix` into `tempScriptName`.
- Improved the documentation.
- Upgraded dependencies.

## 0.2.0

- Removed`split()` and `ascii_ext.dart`
- Use `parse()` only (no split, full parsing).
- Added boolean member `runInShell` which suggests when running in shell is necessary: any special character is present.

## 0.1.0

- Initial version.
