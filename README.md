A library for running programs either explicitly or in shell

## Features

- `ShellCmd.split` to break single string into an executable and its arguments. Unfortunately, the current state of `splitShell` of the package `io` is not usable, as it is hardwired with POSIX-compliant OSes (Linux, macOS, Android, iOS): escape character is always `\`, line comment start is always `#`, strings like `ab|cd` and `ab>cd` are not split in three.

- Wrappers `ShellCmd.run` and `ShellCmd.runSync` (for `Process.run` and `Process.runSync` respectively) accept the first parameter as
the full command in a single string. The package guarantees that when `runInShell` is true, the excution result under a POSIX-compliant OS will be exactly the same as if run in a shell script. The default shell is not required to be `sh` (POSIX) or `cmd.exe` (Windows). First of all, `ShellCmd.getDefaultShell` tries to get that from the environment variable `SHELL`, then from `COMSPEC` (under Windows), and only then tries the ones noted above. You can even set the default shell to anything you pefrer via `ShellCmd.setDefaultShell` or by changing `SHELL` variable.

- Methods `which` and `whichSync` to expand filename into full path if found in PATH. Under Windows, it will also try to append every extension from `PATHEXT`.

- `ShellCmd.extractExecutable` to remove the executable from the list of arguments and return separately.

## Usage

See under the `Example` tab. All sample code files are under the sub-directory `example`.
