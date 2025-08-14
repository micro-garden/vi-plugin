local M = {}

local micro = import("micro")
local buffer = import("micro/buffer")

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local bell = require("bell")
local mode = require("mode")
local prompt = require("prompt")
local move = require("move")
local mark = require("mark")
local view = require("view")
local search = require("search")
local find = require("find")
local insert = require("insert")
local edit = require("edit")
local replace = require("replace")
local misc = require("misc")
local utils = require("utils")

local command_cache = nil

local undo_mode = true -- true: undo, false: redo

local function cache_command(no_num, num, op, no_subnum, subnum, mv, letter)
	command_cache = {}

	command_cache.no_num = no_num
	command_cache.num = num
	command_cache.op = op
	command_cache.no_subnum = no_subnum
	command_cache.subnum = subnum
	command_cache.mv = mv
	command_cache.letter = letter
end

local function get_command_cache()
	return command_cache.no_num,
		command_cache.num,
		command_cache.op,
		command_cache.no_subnum,
		command_cache.subnum,
		command_cache.mv,
		command_cache.letter,
		true
end

local function repeat_command(num)
	mode.show()

	if not command_cache then
		bell.vi_info("nothing to repeat yet")
		return
	end

	for _ = 1, num do
		M.run(get_command_cache())
	end
end

local function undo(num, replay)
	if utils.xor(undo_mode, replay) then
		for _ = 1, num do
			micro.CurPane():Undo()
		end
	else -- redo
		for _ = 1, num do
			micro.CurPane():Redo()
		end
	end

	if not replay then
		undo_mode = not undo_mode
	end
end

local function run_edit(num, op, replay)
	if op == "i" then
		insert.before(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "a" then
		insert.after(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "I" then
		insert.before_non_blank(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "A" then
		insert.after_end_of_line(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "R" then
		insert.overwrite(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "o" then
		insert.open_below(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "O" then
		insert.open_above(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "dd" then
		edit.delete_lines(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "yy" then
		edit.copy_lines(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "Y" then
		edit.copy_lines(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "x" then
		edit.delete_chars(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "X" then
		edit.delete_chars_backward(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "D" then
		edit.delete_to_line_end()
		cache_command(false, 1, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "s" then
		replace.replace_chars(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "S" or op == "cc" then
		replace.replace_lines(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "C" then
		replace.replace_to_line_end(replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "p" then
		edit.paste_below(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "P" then
		edit.paste_above(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "J" then
		edit.join_lines(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == ">>" then
		edit.indent_lines(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "<<" then
		edit.outdent_lines(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	else
		return false
	end
end

local function run_move(no_num, num, mv, letter)
	-- Move by Character / Move by Line
	if mv == "h" then
		move.left(num)
		return true
	elseif mv == "j" then
		move.down(num)
		return true
	elseif mv == "k" then
		move.up(num)
		return true
	elseif mv == "l" then
		move.right(num)
		return true
	end

	-- Move in Line
	if mv == "0" then
		move.to_start_of_line()
		return true
	elseif mv == "$" then
		move.to_end_of_line()
		return true
	elseif mv == "^" then
		move.to_non_blank_of_line()
		return true
	elseif mv == "|" then
		move.to_column(num)
		return true
	end

	-- Move by Word / Move by Loose Word
	if mv == "w" then
		move.by_word(num)
		return true
	elseif mv == "b" then
		move.backward_by_word(num)
		return true
	elseif mv == "e" then
		move.to_end_of_word(num)
		return true
	elseif mv == "W" then
		move.by_loose_word(num)
		return true
	elseif mv == "B" then
		move.backward_by_loose_word(num)
		return true
	elseif mv == "E" then
		move.to_end_of_loose_word(num)
		return true
	end

	-- Move by Line
	if mv == "\n" or mv == "+" then
		move.to_non_blank_of_next_line(num)
		return true
	elseif mv == "-" then
		move.to_non_blank_of_prev_line(num)
		return true
	elseif mv == "G" then
		if no_num then
			move.to_last_line()
		else
			move.to_line(num)
		end
		return true
	end

	-- Move by Block
	if mv == ")" then
		move.by_sentence(num)
		return true
	elseif mv == "(" then
		move.backward_by_sentence(num)
		return true
	elseif mv == "}" then
		move.by_paragraph(num)
		return true
	elseif mv == "{" then
		move.backward_by_paragraph(num)
		return true
	elseif mv == "]]" then
		move.by_section(num)
		return true
	elseif mv == "[[" then
		move.backward_by_section(num)
		return true
	end

	-- Move in View
	if no_num and mv == "H" then
		move.to_top_of_view()
		return true
	elseif mv == "M" then
		move.to_middle_of_view()
		return true
	elseif no_num and mv == "L" then
		move.to_bottom_of_view()
		return true
	elseif mv == "H" then
		move.to_below_top_of_view(num)
		return true
	elseif mv == "L" then
		move.to_above_bottom_of_view(num)
		return true
	end

	-- XXX could not move to misc
	-- Move to Mark / Move by Context
	if mv == "`" and letter then
		if letter == "`" then
			mark.back()
		else
			mark.move_to(letter)
		end
		return true
	elseif mv == "'" and letter then
		if letter == "'" then
		mark.back_to_line()
		else
			mark.move_to_line(letter)
		end
		return true
	end
end

local function run_view(op, mv)
	-- Reposition
	if op == "z" and mv == "\n" then
		view.to_top()
		return true
	elseif op == "z." then
		view.to_middle()
		return true
	elseif op == "z" and mv == "-" then
		view.to_bottom()
		return true
	else
		return false
	end
end

local function run_search(mv, num)
	if mv == "/\n" then -- not works
		search.repeat_forward()
		return true
	elseif mv == "?\n" then -- not works
		search.repeat_backward()
		return true
	elseif mv == "/" then
		search.forward()
		return true
	elseif mv == "?" then
		search.backward()
		return true
	elseif mv == "n" then
		search.next_match(num)
		return true
	elseif mv == "N" then
		search.prev_match(num)
		return true
	else
		return false
	end
end

local function run_find(mv, num, letter)
	if mv == "f" and letter then
		find.forward(num, letter)
		return true
	elseif mv == "F" and letter then
		find.backward(num, letter)
		return true
	elseif mv == "t" and letter then
		find.before_forward(num, letter)
		return true
	elseif mv == "T" and letter then
		find.before_backward(num, letter)
		return true
	elseif mv == ";" then
		find.next_match(num)
		return true
	elseif mv == "," then
		find.prev_match(num)
		return true
	else
		return false
	end
end

local function get_region(num, no_subnum, subnum, mv, letter, save)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local saved_x, saved_y
	if save ~= nil and save then
		saved_x, saved_y = cursor.X, cursor.Y
	end

	local start_loc = buffer.Loc(cursor.X, cursor.Y)

	for _ = 1, num do
		run_move(no_subnum, subnum, mv, letter)
	end

	local end_loc = buffer.Loc(cursor.X, cursor.Y)

	if save ~= nil and save then
		cursor.X, cursor.Y = saved_x, saved_y
	end
	return start_loc, end_loc
end

local function run_compound(num, op, no_subnum, subnum, mv, letter, replay)
	local matched = false

	if op == "d" and mv == "$" then
		edit.delete_to_line_end()
		matched = true
	elseif op == "y" and mv == "$" then
		edit.copy_to_line_end()
		matched = true
	elseif op == "c" and mv == "$" then
		replace.replace_to_line_end(replay)
		matched = true
	elseif op == "d" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(num, no_subnum, subnum, mv, letter)
		edit.delete_lines_region(start_loc.Y, end_loc.Y)
		matched = true
	elseif op == "y" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(num, no_subnum, subnum, mv, letter)
		edit.copy_lines_region(start_loc.Y, end_loc.Y)
		matched = true
	elseif op == "c" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(num, no_subnum, subnum, mv, letter)
		replace.replace_lines_region(start_loc.Y, end_loc.Y, replay)
		matched = true
	elseif op == "d" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(num, no_subnum, subnum, mv, letter)
		edit.delete_chars_region(start_loc, end_loc)
		matched = true
	elseif op == "y" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(num, no_subnum, subnum, mv, letter)
		edit.copy_chars_region(start_loc, end_loc)
		matched = true
	elseif op == "c" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(num, no_subnum, subnum, mv, letter)
		replace.replace_chars_region(start_loc, end_loc, replay)
		matched = true
	elseif op == ">" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(1, no_subnum, subnum, mv, letter, true)
		edit.indent_region(start_loc, end_loc, num)
		matched = true
	elseif op == "<" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(1, no_subnum, subnum, mv, letter, true)
		edit.outdent_region(start_loc, end_loc, num)
		matched = true
	elseif op == ">" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(1, no_subnum, subnum, mv, letter, true)
		edit.indent_region(start_loc, end_loc, 1)
		matched = true
	elseif op == "<" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(1, no_subnum, subnum, mv, letter, true)
		edit.outdent_region(start_loc, end_loc, 1)
		matched = true
	end

	if matched then
		cache_command(false, num, op, no_subnum, subnum, mv, letter)
		undo_mode = true
		return true
	else
		return false
	end
end

local function run_misc(num, op, letter, replay)
	--
	if op == ":" then
		mode.prompt()
		prompt.show()
		return true
	elseif op == "m" and letter then
		mark.set(letter)
		return true
	elseif op == "." then
		repeat_command(num)
		return true
	elseif op == "u" then
		cache_command(false, num, op, true, 1, "", nil)
		undo(num, replay)
		return true
	elseif op == "ZZ" then
		misc.quit()
		return true
	else
		return false
	end
end

local function run(no_num, num, op, no_subnum, subnum, mv, letter, replay)
	if run_compound(num, op, no_subnum, subnum, mv, letter, replay) then
		return true
	elseif run_edit(num, op, replay) then
		return true
	elseif run_find(mv, num, letter) then
		return true
	elseif run_search(mv, num) then
		return true
	elseif run_view(op, mv) then
		return true
	elseif run_move(no_num, num, mv, letter) then
		return true
	elseif run_misc(num, op, letter, replay) then
		return true
	else
		return false
	end
end

M.run = run

return M
