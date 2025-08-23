# Planned Commands for vi Plugin for micro

Implementation status:

* (**Done**): Already implemented.
* (***Buggy***): Already implemented, but has some bugs.
* (*Partially*): Partially implemented.
* (Planned): Not implemented yet, but planned.
* (Stalled): Tried to implement, but not functional yet.
* (Out of Scope): Not planned to implement.

Command categories:

* Motion
* Marking
* View
* Search
* Character Finding
* Insertion
* Operator (Copy / Delte / Change)
* Editing
* Miscellaneous
* Prompt

## Motion Commands

### Move by Character / Move by Line

* `h` (**Done**)  
  Move cursor left by character. (`move.left`)
* `j` (**Done**)  
  Move cursor down by line. (`move.down`)
* `k` (**Done**)  
  Move cursor up by line. (`move.up`)
* `l` (**Done**)  
  Move cursor right by character. (`move.right`)

### Move in Line

* `0` (**Done**)  
  Move cursor to start of current line. (`move.to_start`)
* `$` (**Done**)  
  Move cursor to end of current line. (`move.to_end`)
* `^` (**Done**)  
  Move cursor to first non-blank character of current line. (`move.to_non_blank`)
* `<num>|` (**Done**)  
  Move cursor to column `<num>` of current line. (`move.to_column`)  
  (Note: Proper vi's column number is visual-based, but this plugins' is
  rune-based.)

### Move by Word / Move by Loose Word

* `w` (**Done**)  
  Move cursor forward by word. (`move.by_word`)
* `b` (**Done**)  
  Move cursor backward by word. (`move.backward_by_word`)
* `e` (**Done**)  
  Move cursor to end of word. (`move.to_end_of_word`)
* `W` (**Done**)  
  Move cursor forward by loose word. (`move.by_loose_word`)
* `B` (**Done**)  
  Move cursor backward by loose word. (`move.backward_by_loose_word`)
* `E` (**Done**)  
  Move cursor to end of loose word. (`move.to_end_of_loose_word`)

### Move by Line

* `Enter`, `+` (**Done**)  
  Move cursor to first non-blank character of next line. (`move.to_non_blank_of_next_line`)
* `-` (**Done**)  
  Move cursor to first non-blank character of previous line. (`move.to_non_blank_of_prev_line`)
* `G` (**Done**)  
  Move cursor to last line. (`move.to_last_line`)
* `<num>G` (**Done**)  
  Move cursor to line `<num>`. (`move.to_line`)

### Move by Block

* `)` (**Done**)  
  Move cursor forward by sentence. (`move.by_sentence`)
* `(` (**Done**)  
  Move cursor backward by sentence. (`move.backward_by_sentence`)
* `}` (Planned)  
  Move cursor forward by paragraph. (`move.by_paragraph`)
* `{` (Planned)  
  Move cursor backward by paragraph. (`move.backward_by_paragraph`)
* `]]` (Planned)  
  Move cursor forward by section. (`move.by_section`)
* `[[` (Planned)  
  Move cursor backward by section. (`move.backward_by_section`)

### Move in View

* `H` (Planned)  
  Move cursor to top of view. (`move.to_top_of_view`)
* `M` (Planned)  
  Move cursor to middle of view. (`move.to_middle_of_view`)
* `L` (Planned)  
  Move cursor to bottom of view. (`move.to_bottom_of_view`)
* `<num>H` (Planned)  
  Move cursor below `<num>` lines from top of view. (`move.to_below_top_of_view`)
* `<num>L` (Planned)  
  Move cursor above `<num>` lines from bottom of view. (`move.to_above_bottom_of_view`)

## Marking Commands

### Set Mark / Move to Mark

* `m<letter>` (**Done**)  
  Mark current cursor position labelled by `<letter>`. (`mark.set`)
* `Backquote <letter>` (**Done**)  
  Move cursor to marked position labelled by `<letter>`. (`mark.move_to`)
* `'<letter>` (**Done**)  
  Move cursor to marked line labelled by `<letter>`. (`mark.move_to_line`)

### Move by Context

* `Backquote Backquote` (Planned)  
  Move cursor to previous position in context. (`mark.back`)
* `''` (Planned)  
  Move cursor to previous line in context. (`mark.back_to_line`)

## View Commands

### Scroll by View Height / Scroll by Line

* `Ctrl-f` (Out of Scope)  
  Scroll down by view height. (`view.down`)
* `Ctrl-b` (Out of Scope)  
  Scroll up by view height. (`view.up`)
* `Ctrl-d` (Out of Scope)  
  Scroll down by half view height. (`view.down_half`)
* `Ctrl-u` (Out of Scope)  
  Scroll up by half view height. (`view.up_half`)
* `Ctrl-y` (Out of Scope)  
  Scroll down by line. (`view.down_line`)
* `Ctrl-e` (Out of Scope)  
  Scroll up by line. (`view.up_line`)

### Reposition

* `z Enter` (Planned)  
  Reposition cursor line to top of view. (`view.to_top`)
* `z.` (Planned)  
  Reposition cursor line middle of view. (`view.to_middle`)
* `z-` (Planned)  
  Reposition cursor line bottom of view. (`view.to_bottom`)

### Redraw

* `Ctrl-l` (Out of Scope)
  Redraw view. (`view.redraw`)

## Search Commands

* `/<pattern> Enter` (*Partially*)  
  Search `<pattern>` forward. (`search.forward`)
* `?<pattern> Enter` (*Partially*)  
  Search `<pattern>` backward. (`search.backward`)
* `n` (*Partially*)  
  Search next match. (`search.next_match`)
* `N` (*Partially*)  
  Search previous match. (`search.prev_match`)
* `/ Enter` (Planned)  
  Repeat last search forward. (`search.repeat_forward`)
* `? Enter` (Planned)  
  Repeat last search backward. (`search.repeat_backward`)

## Character Finding Commands

* `f<letter>` (Planned)  
  Find character `<letter>` forward in current line. (`find.forward`)
* `F<letter>` (Planned)  
  Find character `<letter>` backward in current line. (`find.backward`)
* `t<letter>` (Planned)  
  Find before character `<letter>` forward in current line. (`find.before_forward`)
* `T<letter>` (Planned)  
  Find before character `<letter>` backward in current line. (`find.before_backward`)
* `;` (Planned)  
  Find next match. (`find.next_match`)
* `,` (Planned)  
  Find previous match. (`find.prev_match`)

## Insertion Commands

### Enter Insert Mode

* `i` (**Done**)  
  Switch to insert mode before cursor. (`insert.before`)
* `a` (**Done**)  
  Switch to insert mode after cursor. (`insert.after`)
* `I` (**Done**)  
  Switch to insert mode before first non-blank character of current line. (`insert.before_non_blank`)
* `A` (**Done**)  
  Switch to insert mode after end of current line. (`insert.after_end`)
* `R` (Out of Scope)  
  Switch to replace (overwrite) mode. (`insert.overwrite`)

### Open Line

* `o` (***Buggy***)  
  Open a new line **below** and switch to insert mode. (`insert.open_below`)
* `O` (***Buggy***)  
  Open a new line **above** and switch to insert mode. (`insert.open_above`)

## Operator Commands (Copy / Delte / Change)

### Copy (Yank)

* `yy`, `Y` (**Done**)  
  Copy current line. (`operator.copy_line`)
* `y<mv>` (**Done**)  
  Copy region from current cursor to destination of motion `<mv>`. (`operator.copy_region`, `operator.copy_line_region`)
* `yw` (**Done**)  
  Copy word. (`operator.copy_word`)
* `y$` (**Done**)  
  Copy to end of current line. (`operator.copy_to_end`)
* `"<reg>yy` (Planned)  
  Copy current line into register `<reg>`. (`operator.copy_line_into_reg`)

### Paste (Put)

* `p` (**Done**)  
  Paste after cursor. (`operator.paste`)
* `P` (**Done**)  
  Paste before cursor. (`operator.paste_before`)
* `"<reg>p` (Planned)  
  Paste from register `<reg>`. (`operator.paste_from_reg`)

### Delete

* `x` (**Done**)  
  Delete character under cursor. (`operator.delete`)
* `X` (**Done**)  
  Delete character before cursor. (`operator.delete_before`)
* `dd` (**Done**)  
  Delete current line. (`operator.delete_line`)
* `d<mv>` (**Done**)  
  Delete region from current cursor to destination of motion `<mv>`. (`operator.delete_region`, `operator.delete_line_region`)
* `dw` (**Done**)  
  Delete word. (`operator.delete_word`)
* `d$`, `D` (**Done**)  
  Delete to end of current line. (`operator.delete_to_end`)

### Change / Substitute

* `cc` (**Done**)  
  Change current line. (`operator.change_line`)
* `c<mv>` (**Done**)  
  Change region from current cursor to destination of motion `<mv>`. (`operator.change_region`, `operator.change_line_region`)
* `cw` (***Buggy***)  
  Change word. (`operator.change_word`)
* `C` (**Done**)  
  Change to end of current line. (`operator.change_to_end`)
* `s` (***Buggy***)  
  Substitute one character under cursor. (`operator.subst`)
* `S` (**Done**)  
  Substtute current line (equals `cc`). (`operator.subst_line`)

## Editing Commands

* `r` (Planned)  
  Replace single character under cursor. (`edit.replace`)
* `J` (**Done**)  
  Join current line with next line. (`edit.join`)
* `>>` (**Done**)  
  Indent current line. (`edit.indent`)
* `<<` (**Done**)  
  Outdent current line. (`edit.outdent`)
* `> <mv>` (**Done**)  
  Indent region from current cursor to destination of motion `<mv>`. (`edit.indent_region`)
* `< <mv>` (**Done**)  
  Outdent region from current cursor to destination of motion `<mv>`. (`edit.outdent_region`)

## Miscellaneous Commands

* `Ctrl-g` (Out of Scope)  
  Show info such as current cursor position. (`misc.show_info`)
* `.` (**Done**)  
  Repeat last edit. (`misc.repeat`)
* `u` (Stalled)  
  Undo. (`misc.undo`)
* `U` (Planned)  
  Restore current line to previous state. (`misc.restore`)
* `ZZ` (**Done**)  
  Save and quit. (`misc.save_and_quit`)

## Prompt Commands 

### Move

* `:<num> Enter` (Planned)  
  Move cursor to line `<num>`. (`prompt.move_to_line`)

### File

* `:wq Enter` (Planned)  
  Save current file and quit. (`prompt.save_and_quit`)
* `:w Enter` (**Done**)  
  Save current file. (`prompt.save`)
* `:w! Enter` (Out of Scope)  
  Force save current file.(`prompt.force_save`)
* `:q Enter` (**Done**)  
  Quit editor. (`prompt.quit`)
* `:q! Enter` (**Done**)  
  Force quit editor. (`prompt.force_quit`)
* `:e Enter` (**Done**)  
  Open file. (`prompt.open`)
* `:e! Enter` (Planned)  
  Force open file. (`prompt.force_open`)
* `:r Enter` (Out of Scope)  
  Read file and insert to current buffer. (`prompt.read`)
* `:n Enter` (Planned)  
  Switch to next buffer (tab). (`prompt.next`)
* `:prev Enter` (Planned)  
  Switch to previous buffer (tab). (`prompt.prev`) (extension)

### Utility

* `:sh Enter` (Planned)  
  Execute shell. (`prompt.shell`)

### From Vim

* `:wa Enter` (**Done**)  
  Save all files. (`prompt.save_all`)
* `:qa Enter` (*Partially*)  
  Close all files and quit editor. (`prompt.quit_all`)
* `:qa! Enter` (*Partially*)  
  Force close all files and quit editor. (`prompt.force_quit_all`)
