A library for running programs either explicitly or in an OS-specific shell

## Features

- Instance method `parse` to break single string into an executable and its arguments. This was done due to the current state of `splitShell` of the package `io` is not usable, as it is hardwired to POSIX conventions: escape character is always `\`, line comment start is always `#`, strings like `ab|cd` and `ab>cd` are not split in three, etc. The flag `runInShell` indicates whether the command should be run in shell (having special characters) or not.

- Instance wrapper methods `run` and `runSync` (for `Process.run` and `Process.runSync` respectively) accept the first parameter as
the full command in a single string. The package guarantees that when the parameter `runInShell` is true, the excution result will be exactly the same as if that command would be run as a script. If this parameter is omitted, the member `runInShell` will be used. The shell is not required to be `sh` (POSIX) or `cmd.exe` (Windows). First of all, the API tries to get that from the environment variable `SHELL` (POSIX) or `COMSPEC` (Windows), then falls back onto the ones noted before. It is possible to set the shell to anything else explicitly via `setShell`.

- Methods `which` and `whichSync` to expand filename into full path if found in PATH. Under Windows, it will also try to append every extension from `PATHEXT`.

## Usage

See under the `Example` tab. All sample code files are under the sub-directory `example`.
