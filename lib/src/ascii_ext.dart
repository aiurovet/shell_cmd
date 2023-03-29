// Copyright (c) 2023, Alexander Iurovetski
// All rights reserved under MIT license (see LICENSE file)

import 'package:charcode/charcode.dart';
import 'package:shell_cmd/shell_cmd.dart';

////////////////////////////////////////////////////////////////////////////////////////
// Platform-independent variables for specific character codes
////////////////////////////////////////////////////////////////////////////////////////

/// Escape character (platform-specific, can be changed in unit tests)
///
var $escape = getEscapeCharCode();

/// Start of a line comment (not applicable to Windows, can be changed in unit tests)
///
var $lineCommentStart = getCommentStartCharCode();

////////////////////////////////////////////////////////////////////////////////////////
// Supplementary global methods
////////////////////////////////////////////////////////////////////////////////////////

/// Returns the actual code for the comment start character depending on the 'Windows'
/// flag (default: platform-specific, useful for unit tests)
///
int getCommentStartCharCode([bool? isWindows]) =>
    isWindows ?? ShellCmd.isWindows ? 0 : $hash;

/// Returns the actual code for the escape character depending on the 'Windows'
/// flag (default: platform-specific, useful for unit tests)
///
int getEscapeCharCode([bool? isWindows]) =>
    isWindows ?? ShellCmd.isWindows ? $circumflex : $backslash;

/// Initialises all platform-specific characters (default: platform-specific,
/// useful for unit tests)
///
void setPlatformCharCodes({bool? isWindows}) {
  $lineCommentStart = getCommentStartCharCode(isWindows);
  $escape = getEscapeCharCode(isWindows);
}

////////////////////////////////////////////////////////////////////////////////////////
