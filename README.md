# MiniTerminalKit

Lightweight Swift ANSI/VT100 terminal emulator with screen buffer, scrollback, and SwiftUI rendering.

MiniTerminalKit is a small Swift Package for apps that receive terminal output as streamed text chunks and want to interpret ANSI escape sequences instead of stripping them.

It is designed for iOS, iPadOS, and macOS apps that need to render shell-like output from commands such as:

- `top`
- `ping`
- `logcat`
- `ls -la`
- long-running shell commands
- progress output using `\r`
- ANSI-styled command output

## Why?

Many terminal outputs contain ANSI/VT100 escape sequences for cursor movement, screen clearing, styling, and live updates.

A simple sanitizer that removes ANSI sequences breaks commands like `top`, because `top` does not just print lines. It continuously moves the cursor, clears the screen, and redraws the visible terminal.

MiniTerminalKit uses a small parser and screen buffer to interpret those sequences.

## Features

- Swift Package
- SwiftUI-compatible
- No external dependencies
- Chunk-based `feed(_:)` API
- Stateful parser for split escape sequences across chunks
- Screen buffer with rows, columns, cursor position, and cells
- Scrollback support
- Basic ANSI/CSI support
- Cursor movement
- Clear screen / clear line
- Basic SGR styling:
  - reset
  - bold
  - inverse
  - foreground colors
  - background colors
- Optional SwiftUI `TerminalScreenView`
- Built for streamed command output

## Installation

Add MiniTerminalKit as a local Swift Package.

In Xcode:

```text
File → Add Package Dependencies...
→ Add Local...
→ Select the MiniTerminalKit folder
