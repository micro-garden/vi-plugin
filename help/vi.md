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

All movement commands support numeric prefixes, e.g. `3j` moves down 3 lines.

### Insert Commands

| Command | Description       |
| ------- | ----------------- |
| `i`     | Enter insert mode |

### Quit Command

| Command | Description |
| ------- | ----------- |
| `ZZ`    | Quit micro  |

## Notes

- Word movement (`w`, `b`) uses micro’s `WordRight` and `WordLeft` logic and
  may not fully match vi behavior.
- This plugin is a **proof of concept**, and not a full vi clone.
