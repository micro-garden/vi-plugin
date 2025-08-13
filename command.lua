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
local insert = require("insert")
local edit = require("edit")
local replace = require("replace")
local mark = require("mark")
local find = require("find")
local misc = require("misc")
local utils = require("utils")

local command_cache = nil

local undo_mode = true -- true: undo, false: redo

local function cache_command(no_number, number, edit_part, no_subnum, subnum, mv, letter)
	command_cache = {}

	command_cache.no_number = no_number
	command_cache.number = number
	command_cache.edit = edit_part
	command_cache.no_subnum = no_subnum
	command_cache.subnum = subnum
	command_cache.mv = mv
	command_cache.letter = letter
end

local function get_command_cache()
	return command_cache.no_number,
		command_cache.number,
		command_cache.edit,
		command_cache.no_subnum,
		command_cache.subnum,
		command_cache.mv,
		command_cache.letter,
		true
end

local function repeat_command(number)
	mode.show()

	if not command_cache then
		bell.vi_info("nothing to repeat yet")
		return
	end

	for _ = 1, number do
		M.run(get_command_cache())
	end
end

local function undo(number, replay)
	if utils.xor(undo_mode, replay) then
		for _ = 1, number do
			micro.CurPane():Undo()
		end
	else -- redo
		for _ = 1, number do
			micro.CurPane():Redo()
		end
	end

	if not replay then
		undo_mode = not undo_mode
	end
end

local function run_edit(number, edit_part, replay)
	if edit_part == "i" then
		insert.insert_here(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "I" then
		insert.insert_line_start(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "a" then
		insert.insert_after_here(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "A" then
		insert.insert_after_line_end(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "o" then
		insert.open_below(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "O" then
		insert.open_above(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "dd" then
		edit.delete_lines(number)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "yy" then
		edit.copy_lines(number)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "Y" then
		edit.copy_lines(number)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "x" then
		edit.delete_chars(number)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "X" then
		edit.delete_chars_backward(number)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "D" then
		edit.delete_to_line_end()
		cache_command(false, 1, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "s" then
		replace.replace_chars(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "S" or edit_part == "cc" then
		replace.replace_lines(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "C" then
		replace.replace_to_line_end(replay)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "p" then
		edit.paste_below(number)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "P" then
		edit.paste_above(number)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "J" then
		edit.join_lines(number)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == ">>" then
		edit.indent_lines(number)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif edit_part == "<<" then
		edit.outdent_lines(number)
		cache_command(false, number, edit_part, true, 1, "", nil, nil)
		undo_mode = true
		return true
	else
		return false
	end
end

local function run_move(no_number, number, mv, letter)
	-- Move by Character / Move by Line
	if mv == "h" then
		move.left(number)
		return true
	elseif mv == "j" then
		move.down(number)
		return true
	elseif mv == "k" then
		move.up(number)
		return true
	elseif mv == "l" then
		move.right(number)
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
		move.to_column(number)
		return true
	end

	-- Move by Word / Move by Loose Word
	if mv == "w" then
		move.by_word(number)
		return true
	elseif mv == "b" then
		move.backward_by_word(number)
		return true
	elseif mv == "e" then
		move.to_end_of_word(number)
		return true
	elseif mv == "W" then
		move.by_loose_word(number)
		return true
	elseif mv == "B" then
		move.backward_by_loose_word(number)
		return true
	elseif mv == "E" then
		move.to_end_of_loose_word(number)
		return true
	end

	-- Move by Line
	if mv == "\n" or mv == "+" then
		move.to_non_blank_of_next_line(number)
		return true
	elseif mv == "-" then
		move.to_non_blank_of_prev_line(number)
		return true
	elseif mv == "G" then
		if no_number then
			move.to_last_line()
		else
			move.to_line(number)
		end
		return true
	end

	-- Move by Block
	if mv == ")" then
		move.by_sentence(number)
		return true
	elseif mv == "(" then
		move.backward_by_sentence(number)
		return true
	elseif mv == "}" then
		move.by_paragraph(number)
		return true
	elseif mv == "{" then
		move.backward_by_paragraph(number)
		return true
	elseif mv == "]]" then
		move.by_section(number)
		return true
	elseif mv == "[[" then
		move.backward_by_section(number)
		return true
	end

	-- Move in View
	if no_number and mv == "H" then
		move.to_top_of_view()
		return true
	elseif mv == "M" then
		move.to_middle_of_view()
		return true
	elseif no_number and mv == "L" then
		move.to_bottom_of_view()
		return true
	elseif mv == "H" then
		move.to_below_top_of_view(number)
		return true
	elseif mv == "L" then
		move.to_above_bottom_of_view(number)
		return true
	end

	-- XXX could not move to misc
	if mv == "`" and letter then
		mark.move_to(letter)
		return true
	elseif mv == "'" and letter then
		mark.move_to_line(letter)
		return true
	elseif mv == "``" then
		mark.back()
		return true
	elseif mv == "''" then
		mark.back_to_line()
		return true
	elseif mv == "/" then
		find.find()
		return true
	elseif mv == "?" then
		find.reverse_find()
		return true
	elseif mv == "n" then
		find.find_next(number)
		return true
	elseif mv == "N" then
		find.find_prev(number)
		return true
	else
		return false
	end
end

local function get_region(number, no_subnum, subnum, mv, letter, save)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local saved_x, saved_y
	if save ~= nil and save then
		saved_x, saved_y = cursor.X, cursor.Y
	end

	local start_loc = buffer.Loc(cursor.X, cursor.Y)

	for _ = 1, number do
		run_move(no_subnum, subnum, mv, letter)
	end

	local end_loc = buffer.Loc(cursor.X, cursor.Y)

	if save ~= nil and save then
		cursor.X, cursor.Y = saved_x, saved_y
	end
	return start_loc, end_loc
end

local function run_compound(number, edit_part, no_subnum, subnum, mv, letter, replay)
	local matched = false

	if edit_part == "d" and mv == "$" then
		edit.delete_to_line_end()
		matched = true
	elseif edit_part == "y" and mv == "$" then
		edit.copy_to_line_end()
		matched = true
	elseif edit_part == "c" and mv == "$" then
		replace.replace_to_line_end(replay)
		matched = true
	elseif edit_part == "d" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(number, no_subnum, subnum, mv, letter)
		edit.delete_lines_region(start_loc.Y, end_loc.Y)
		matched = true
	elseif edit_part == "y" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(number, no_subnum, subnum, mv, letter)
		edit.copy_lines_region(start_loc.Y, end_loc.Y)
		matched = true
	elseif edit_part == "c" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(number, no_subnum, subnum, mv, letter)
		replace.replace_lines_region(start_loc.Y, end_loc.Y, replay)
		matched = true
	elseif edit_part == "d" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(number, no_subnum, subnum, mv, letter)
		edit.delete_chars_region(start_loc, end_loc)
		matched = true
	elseif edit_part == "y" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(number, no_subnum, subnum, mv, letter)
		edit.copy_chars_region(start_loc, end_loc)
		matched = true
	elseif edit_part == "c" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(number, no_subnum, subnum, mv, letter)
		replace.replace_chars_region(start_loc, end_loc, replay)
		matched = true
	elseif edit_part == ">" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(1, no_subnum, subnum, mv, letter, true)
		edit.indent_region(start_loc, end_loc, number)
		matched = true
	elseif edit_part == "<" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(1, no_subnum, subnum, mv, letter, true)
		edit.outdent_region(start_loc, end_loc, number)
		matched = true
	elseif edit_part == ">" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(1, no_subnum, subnum, mv, letter, true)
		edit.indent_region(start_loc, end_loc, 1)
		matched = true
	elseif edit_part == "<" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(1, no_subnum, subnum, mv, letter, true)
		edit.outdent_region(start_loc, end_loc, 1)
		matched = true
	end

	if matched then
		cache_command(false, number, edit_part, no_subnum, subnum, mv, letter)
		undo_mode = true
		return true
	else
		return false
	end
end

local function run_misc(number, edit_part, letter, replay)
	--
	if edit_part == ":" then
		mode.prompt()
		prompt.show()
		return true
	elseif edit_part == "m" and letter then
		mark.set(letter)
		return true
	elseif edit_part == "." then
		repeat_command(number)
		return true
	elseif edit_part == "u" then
		cache_command(false, number, edit_part, true, 1, "", nil)
		undo(number, replay)
		return true
	elseif edit_part == "ZZ" then
		misc.quit()
		return true
	else
		return false
	end
end

local function run(no_number, number, edit_part, no_subnum, subnum, mv, letter, replay)
	if run_compound(number, edit_part, no_subnum, subnum, mv, letter, replay) then
		return true
	elseif run_edit(number, edit_part, replay) then
		return true
	elseif run_move(no_number, number, mv, letter) then
		return true
	elseif run_misc(number, edit_part, letter, replay) then
		return true
	else
		return false
	end
end

M.run = run

return M
