M = {}

local micro = import("micro")
local buffer = import("micro/buffer")
local time = import("time")

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local bell = require("bell")
local mode = require("mode")
local motion = require("motion")
local insert = require("insert")
local edit = require("edit")
local replace = require("replace")
local mark = require("mark")
local find = require("find")
local misc = require("misc")
local utils = require("utils")

local command_cache = nil

local undo_mode = true -- true: undo, false: redo

local function cache_command(no_number, number, edit, no_subnum, subnum, move, letter)
	command_cache = {}

	command_cache.no_number = no_number
	command_cache.number = number
	command_cache.edit = edit
	command_cache.no_subnum = no_subnum
	command_cache.subnum = subnum
	command_cache.move = move
	command_cache.letter = letter
end

local function get_command_cache()
	return command_cache.no_number,
		command_cache.number,
		command_cache.edit,
		command_cache.no_subnum,
		command_cache.subnum,
		command_cache.move,
		command_cache.letter,
		true
end

local function repeat_command(number)
	mode.show()

	if not command_cache then
		bell.message("no command cached yet")
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
	else
		return false
	end
end

local function run_motion(no_number, number, move, letter)
	if move == "h" then
		motion.move_left(number)
		return true
	elseif move == "j" then
		motion.move_down(number)
		return true
	elseif move == "k" then
		motion.move_up(number)
		return true
	elseif move == "l" then
		motion.move_right(number)
		return true
	elseif move == "\n" then
		motion.move_next_line_start(number)
		return true
	elseif move == "0" then
		motion.move_line_start()
		return true
	elseif move == "$" then
		motion.move_line_end()
		return true
	elseif move == "w" then
		motion.move_next_word(number)
		return true
	elseif move == "b" then
		motion.move_prev_word(number)
		return true
	elseif move == "G" then
		if no_number then
			motion.goto_bottom()
		else
			motion.goto_line(number)
		end
		return true
	elseif move == "'" and letter then
		mark.goto_line(letter)
		return true
	elseif move == "`" and letter then
		mark.goto_char(letter)
		return true
	elseif move == "/" then
		find.find()
		return true
	elseif move == "?" then
		find.reverse_find()
		return true
	elseif move == "n" then
		find.find_next(number)
		return true
	elseif move == "N" then
		find.find_prev(number)
		return true
	else
		return false
	end
end

local function get_region(number, no_subnum, subnum, move, letter)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local start_loc = buffer.Loc(cursor.X, cursor.Y)

	for _ = 1, number do
		run_motion(no_subnum, subnum, move, letter)
	end

	local end_loc = buffer.Loc(cursor.X, cursor.Y)

	return start_loc, end_loc
end

local function run_compound(number, edit_part, subnum, move, letter, replay)
	local matched = false

	if edit_part == "d" and move == "$" then
		edit.delete_to_line_end()
		matched = true
	elseif edit_part == "y" and move == "$" then
		edit.copy_to_line_end()
		matched = true
	elseif edit_part == "c" and move == "$" then
		replace.replace_to_line_end(replay)
		matched = true
	elseif edit_part == "d" and (move:match("[jk\nG]+") or move == "'" and letter) then
		local start_loc, end_loc = get_region(number, no_subnum, subnum, move, letter)
		edit.delete_lines_region(start_loc.Y, end_loc.Y)
		matched = true
	elseif edit_part == "y" and (move:match("[jk\nG]+") or move == "'" and letter) then
		local start_loc, end_loc = get_region(number, no_subnum, subnum, move, letter)
		edit.copy_lines_region(start_loc.Y, end_loc.Y)
		matched = true
	elseif edit_part == "c" and (move:match("[jk\nG]+") or move == "'" and letter) then
		local start_loc, end_loc = get_region(number, no_subnum, subnum, move, letter)
		replace.replace_lines_region(start_loc.Y, end_loc.Y, replay)
		matched = true
	elseif edit_part == "d" and (move:match("[hl0wbnN]+") or move == "`" and letter) then
		local start_loc, end_loc = get_region(number, no_subnum, subnum, move, letter)
		edit.delete_chars_region(start_loc, end_loc)
		matched = true
	elseif edit_part == "y" and (move:match("[hl0wbnN]+") or move == "`" and letter) then
		local start_loc, end_loc = get_region(number, no_subnum, subnum, move, letter)
		edit.copy_chars_region(start_loc, end_loc)
		matched = true
	elseif edit_part == "c" and (move:match("[hl0wbnN]+") or move == "`" and letter) then
		local start_loc, end_loc = get_region(number, no_subnum, subnum, move, letter)
		replace.replace_chars_region(start_loc, end_loc, replay)
		matched = true
	end

	if matched then
		cache_command(false, number, edit_part, no_subnum, subnum, move, letter)
		undo_mode = true
		return true
	else
		return false
	end
end

local function run_misc(number, edit_part, letter)
	if edit_part == "m" and letter then
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

local function run(no_number, number, edit_part, no_subnum, subnum, move, letter, replay)
	if run_compound(number, edit_part, subnum, move, letter, replay) then
		return true
	elseif run_edit(number, edit_part, replay) then
		return true
	elseif run_motion(no_number, number, move, letter) then
		return true
	elseif run_misc(number, edit_part, letter) then
		return true
	else
		return false
	end
end

M.run = run

return M
