A library for running programs either explicitly or in shell

## Features

- `ShellCmd.split` to break single string into an executable and its arguments. This was done due to the current state of `splitShell` of the package `io` is not usable, as it is hardwired to POSIX conventions: escape character is always `\`, line comment start is always `#`, strings like `ab|cd` and `ab>cd` are not split in three, etc.

- Wrappers `ShellCmd.run` and `ShellCmd.runSync` (for `Process.run` and `Process.runSync` respectively) accept the first parameter as
the full command in a single string. The package guarantees that when the parameter `runInShell` is true, the excution result will be exactly the same as if that command would be run as a script. The shell is not required to be `sh` (POSIX) or `cmd.exe` (Windows). First of all, `ShellCmd.getShell` tries to get that from the environment variable `SHELL` (POSIX) or `COMSPEC` (Windows), then falls back onto the ones noted before. It is possible to set the shell to anything else explicitly via `ShellCmd.setShell`.

- Methods `which` and `whichSync` to expand filename into full path if found in PATH. Under Windows, it will also try to append every extension from `PATHEXT`.

- `ShellCmd.extractExecutable` to remove the executable from the list of arguments and to return it separately.

## Usage

See under the `Example` tab. All sample code files are under the sub-directory `example`.
