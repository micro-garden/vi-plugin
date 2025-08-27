# Planned Commands for vi Plugin for micro

Implementation status:

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

* `h`  
  Move cursor left by character. (`move.left`)
* `j`  
  Move cursor down by line. (`move.down`)
* `k`  
  Move cursor up by line. (`move.up`)
* `l`  
  Move cursor right by character. (`move.right`)

### Move in Line

* `0`  
  Move cursor to start of current line. (`move.to_start`)
* `$`  
  Move cursor to end of current line. (`move.to_end`)
* `^`  
  Move cursor to first non-blank character of current line. (`move.to_non_blank`)
* `<num>|`  
  Move cursor to column `<num>` of current line. (`move.to_column`)  
  (Note: Proper vi's column number is visual-based, but this plugins' is
  rune-based.)

### Move by Word / Move by Loose Word

* `w`  
  Move cursor forward by word. (`move.by_word`)
* `b`  
  Move cursor backward by word. (`move.backward_by_word`)
* `e`  
  Move cursor to end of word. (`move.to_end_of_word`)
* `W`  
  Move cursor forward by loose word. (`move.by_loose_word`)
* `B`  
  Move cursor backward by loose word. (`move.backward_by_loose_word`)
* `E`  
  Move cursor to end of loose word. (`move.to_end_of_loose_word`)

### Move by Line

* `Enter`, `+`  
  Move cursor to first non-blank character of next line. (`move.to_non_blank_of_next_line`)
* `-`  
  Move cursor to first non-blank character of previous line. (`move.to_non_blank_of_prev_line`)
* `G`  
  Move cursor to last line. (`move.to_last_line`)
* `<num>G`  
  Move cursor to line `<num>`. (`move.to_line`)

### Move by Block

* `)`  
  Move cursor forward by sentence. (`move.by_sentence`)
* `(`  
  Move cursor backward by sentence. (`move.backward_by_sentence`)
* `}`  
  Move cursor forward by paragraph. (`move.by_paragraph`)
* `{`  
  Move cursor backward by paragraph. (`move.backward_by_paragraph`)  
  (Note: Proper vi respects nroff/troff directives, but this plugin doesn't.)
* `]]`  
  Move cursor forward by section. (`move.by_section`)
  (Note: Proper vi respects nroff/troff directives, but this plugin doesn't.)
* `[[`  
  Move cursor backward by section. (`move.backward_by_section`)
  (Note: Proper vi respects nroff/troff directives, but this plugin doesn't.)

### Move in View

* `H`  
  Move cursor to top of view. (`move.to_top_of_view`)
* `M`  
  Move cursor to middle of view. (`move.to_middle_of_view`)
* `L`  
  Move cursor to bottom of view. (`move.to_bottom_of_view`)
* `<num>H`  
  Move cursor below `<num>` lines from top of view. (`move.to_below_top_of_view`)
* `<num>L`  
  Move cursor above `<num>` lines from bottom of view. (`move.to_above_bottom_of_view`)

## Marking Commands

### Set Mark / Move to Mark

* `m<letter>`  
  Mark current cursor position labelled by `<letter>`. (`mark.set`)
* `Backquote <letter>`  
  Move cursor to marked position labelled by `<letter>`. (`mark.move_to`)
* `'<letter>`  
  Move cursor to marked line labelled by `<letter>`. (`mark.move_to_line`)

### Move by Context

* `Backquote Backquote`  
  Move cursor to previous position in context. (`mark.back`)
* `''`  
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

* `z Enter`  
  Reposition cursor line to top of view. (`view.to_top`)
* `z.`  
  Reposition cursor line middle of view. (`view.to_middle`)
* `z-`  
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

* `f<letter>`  
  Find character `<letter>` forward in current line. (`find.forward`)
* `F<letter>`  
  Find character `<letter>` backward in current line. (`find.backward`)
* `t<letter>`  
  Find before character `<letter>` forward in current line. (`find.before_forward`)
* `T<letter>`  
  Find before character `<letter>` backward in current line. (`find.before_backward`)
* `;`  
  Find next match. (`find.next_match`)
* `,`  
  Find previous match. (`find.prev_match`)

## Insertion Commands

### Enter Insert Mode

* `i`  
  Switch to insert mode before cursor. (`insert.before`)
* `a`  
  Switch to insert mode after cursor. (`insert.after`)
* `I`  
  Switch to insert mode before first non-blank character of current line. (`insert.before_non_blank`)
* `A`  
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

* `yy`, `Y`  
  Copy current line. (`operator.copy_line`)
* `y<mv>`  
  Copy region from current cursor to destination of motion `<mv>`. (`operator.copy_region`, `operator.copy_line_region`)
* `yw`  
  Copy word. (`operator.copy_word`)
* `y$`  
  Copy to end of current line. (`operator.copy_to_end`)
* `"<reg>yy` (Planned)  
  Copy current line into register `<reg>`. (`operator.copy_line_into_reg`)

### Paste (Put)

* `p`  
  Paste after cursor. (`operator.paste`)
* `P`  
  Paste before cursor. (`operator.paste_before`)
* `"<reg>p` (Planned)  
  Paste from register `<reg>`. (`operator.paste_from_reg`)

### Delete

* `x`  
  Delete character under cursor. (`operator.delete`)
* `X`  
  Delete character before cursor. (`operator.delete_before`)
* `dd`  
  Delete current line. (`operator.delete_line`)
* `d<mv>`  
  Delete region from current cursor to destination of motion `<mv>`. (`operator.delete_region`, `operator.delete_line_region`)
* `dw`  
  Delete word. (`operator.delete_word`)
* `d$`, `D`  
  Delete to end of current line. (`operator.delete_to_end`)

### Change / Substitute

* `cc`  
  Change current line. (`operator.change_line`)
* `c<mv>`  
  Change region from current cursor to destination of motion `<mv>`. (`operator.change_region`, `operator.change_line_region`)
* `cw`  
  Change word. (`operator.change_word`)
* `C`  
  Change to end of current line. (`operator.change_to_end`)
* `s`  
  Substitute one character under cursor. (`operator.subst`)
* `S`  
  Substtute current line (equals `cc`). (`operator.subst_line`)

## Editing Commands

* `r`  
  Replace single character under cursor. (`edit.replace`)
* `J`  
  Join current line with next line. (`edit.join`)
* `>>`  
  Indent current line. (`edit.indent`)
* `<<`  
  Outdent current line. (`edit.outdent`)
* `> <mv>`  
  Indent region from current cursor to destination of motion `<mv>`. (`edit.indent_region`)
* `< <mv>`  
  Outdent region from current cursor to destination of motion `<mv>`. (`edit.outdent_region`)

## Miscellaneous Commands

* `Ctrl-g` (Out of Scope)  
  Show info such as current cursor position. (`misc.show_info`)
* `.`  
  Repeat last edit. (`misc.repeat`)
* `u` (Stalled)  
  Undo. (`misc.undo`)
* `U` (*Partially*)  
  Restore current line to previous state. (`misc.restore`)
* `ZZ`  
  Save and quit. (`misc.save_and_quit`)

## Prompt Commands 

### Move

* `:<num> Enter`  
  Move cursor to line `<num>`. (`prompt.move_to_line`)

### File

* `:wq Enter`  
  Save current file and quit. (`prompt.save_and_quit`)
* `:w Enter`  
  Save current file. (`prompt.save`)
* `:w! Enter` (Out of Scope)  
  Force save current file.(`prompt.force_save`)
* `:q Enter`  
  Quit editor. (`prompt.quit`)
* `:q! Enter`  
  Force quit editor. (`prompt.force_quit`)
* `:e Enter`  
  Open file. (`prompt.open`)
* `:e! Enter` (Planned)  
  Force open file. (`prompt.force_open`)
* `:r Enter` (Out of Scope)  
  Read file and insert to current buffer. (`prompt.read`)
* `:n Enter`  
  Switch to next buffer (tab). (`prompt.next`)
* `:prev Enter`  
  Switch to previous buffer (tab). (`prompt.prev`) (extension)

### Utility

* `:sh Enter` (*Partially*)  
  Execute shell. (`prompt.shell`)  
  (Note: Only Unix-like OSes are supported.)

### From Vim

* `:wa Enter`  
  Save all files. (`prompt.save_all`)
* `:qa Enter` (*Partially*)  
  Close all files and quit editor. (`prompt.quit_all`)
* `:qa! Enter` (*Partially*)  
  Force close all files and quit editor. (`prompt.force_quit_all`)
