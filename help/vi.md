# vi Plugin

**vi** is a plugin that provides a simple vi-style modal editing mode.

## Usage

To enter vi mode, press `Escape` or run:

```
vi
```

When in vi **command mode**, the keybindings follow a vi-like style.
You can return to insert mode with the `i` command.

## Supported Commands

### Movement Commands

| Command          | Description                                       |
| ---------------- | ------------------------------------------------- |
| `h`              | Move left                                         |
| `l`              | Move right                                        |
| `j`              | Move down                                         |
| `k`              | Move up                                           |
| `0`              | Move to beginning of line                         |
| `$`              | Move to end of line                               |
| `w`              | Move to beginning of next word (experimental)     |
| `b`              | Move to beginning of previous word (experimental) |
| `<Enter>` / `\n` | Move to beginning of next line                    |
| `G`              | Move to the bottom of the file                    |
| `10G`            | Move to line 10                                   |

All movement commands support numeric prefixes, e.g. `3j` moves down 3 lines.

### Insert Commands

| Command | Description                                        |
| ------- | -------------------------------------------------- |
| `i`     | Enter insert mode at current cursor                |
| `I`     | Insert at the beginning of the line (after indent) |
| `a`     | Insert after the current character                 |
| `A`     | Insert at the end of the line                      |
| `o`     | Insert a new line below the current line           |
| `O`     | Insert a new line above the current line           |

### Line Operations

| Command | Description                              |
| ------- | ---------------------------------------- |
| `dd`    | Delete current line                      |
| `2dd`   | Delete 2 lines                           |
| `yy`    | Yank (copy) current line                 |
| `2yy`   | Yank 2 lines                             |
| `p`     | Paste after (insert below current line)  |
| `P`     | Paste before (insert above current line) |

### Other Commands

| Command | Description         |
| ------- | ------------------- |
| `.`     | Repeat last command |
| `ZZ`    | Quit micro          |

### vi.default Option

You can make micro start in vi command mode by default using:

```
videfault true
```

To disable it again:

```
videfault false
```

Without arguments, the `videfault` command toggles the setting.

This setting is saved globally and applies to all newly opened buffers.

## Notes

- Word movement (`w`, `b`) uses micro’s `WordRight` and `WordLeft` logic and
  may not fully match vi behavior.
- This plugin is a **proof of concept**, and not a full vi clone.
