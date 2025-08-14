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

See full list of supported and planned commands by running:

```
help vicommands
```

Followings are major implemented commands.

### Movement Commands

| Command          | Description                                  |
| ---------------- | -------------------------------------------- |
| `h`              | Move left                                    |
| `l`              | Move right                                   |
| `j`              | Move down                                    |
| `k`              | Move up                                      |
| `0`              | Move to beginning of line                    |
| `$`              | Move to end of line                          |
| `w`              | Move to beginning of next word               |
| `b`              | Move to beginning of previous word           |
| `e`              | Move to end of word                          |
| `<Enter>` / `\n` | Move to beginning of next line               |
| `+`              | Move to beginning of next line               |
| `G`              | Move to the bottom of the file               |
| `10G`            | Move to line 10                              |
| `m` + letter     | Mark current position as letter (symplified) |
| `'` + letter     | Move to marked line                          |
| ````` + letter   | Move to markd character                      |

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

### Edit Commands

| Command       | Description                              |
| ------------- | ---------------------------------------- |
| `dd`          | Delete current line                      |
| `2dd`         | Delete 2 lines                           |
| `yy` or `Y`   | Yank (copy) current line                 |
| `2yy` or `2Y` | Yank 2 lines                             |
| `x`           | Delete current character                 |
| `X`           | Delete previous character (Backspace)    |
| `D`           | Delete to line end                       |
| `p`           | Paste after (insert below current line)  |
| `P`           | Paste before (insert above current line) |
| `J`           | Join 2 lines                             |
| `>>`          | Indent current line                      |
| `<<`          | Outdent current line                     |
| `2>>`         | Indent 2 lines                           |

### Replace commands

| Command       | Description          |
| ------------- | -------------------- |
| `s`           | Replace a character  |
| `2s`          | Replace 2 characters |
| `S` or `cc`   | Replace a line       |
| `2S` or `2cc` | Replace 2 lines      |
| `C`           | Replace to line end  |
| `cw`          | Replace a word       |
| `c2w`         | Replace 2 words      |

### Search Commands

| Command | Description                                     |
| ------- | ----------------------------------------------- |
| `/`     | Start search forward using micro's find method  |
| `?`     | Start search backward using micro's find method |
| `n`     | Find next                                       |
| `N`     | Find previous                                   |

### Move + Edit

Some motion and edit commands are able to be combined.  
For example:

| Command | Description                           |
| ------- | ------------------------------------- |
| `dw`    | Delete a word                         |
| `d2w`   | Delete 2 word                         |
| `yG`    | Copy from current line to bottom line |

### Miscellaneous Commands

| Command | Description         |
| ------- | ------------------- |
| `.`     | Repeat last command |
| `ZZ`    | Quit micro          |

### Prompt Commands

| Command               | Description                  |
| --------------------- | ---------------------------- |
| `:w`                  | Write current buffer to file |
| `:q`                  | Quit (close current buffer)  |
| `:q!`                 | Force quit without saving    |
| `:e`                  | Open file                    |
| `:wa` (vim)           | Save all buffers to files    |
| `:qa` or `:qa!` (vim) | Quit all buffers             |

###

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
