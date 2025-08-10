M = {}

local micro = import("micro")
local buffer = import("micro/buffer")
local time = import("time")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/vi/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local editor = require("editor")
local mode = require("mode")
local motion = require("motion")
local insert = require("insert")
local edit = require("edit")
local replace = require("replace")
local find = require("find")
local utils = require("utils")

local command_cached = false
local command_cache = {
	["no_number"] = false,
	["number"] = 1,
	["edit"] = "",
	["no_subnum"] = true,
	["subnum"] = 1,
	["move"] = "",
}

local UNDO_MODE = 1
local REDO_MODE = 2
local undo_mode = UNDO_MODE

local function cache_command(no_number, number, edit, no_subnum, subnum, move, force_undo_mode)
	command_cache["no_number"] = no_number
	command_cache["number"] = number
	command_cache["edit"] = edit
	command_cache["no_subnum"] = no_subnum
	command_cache["subnum"] = subnum
	command_cache["move"] = move
	command_cache["undo_mode"] = force_undo_mode

	command_cached = true

	undo_mode = UNDO_MODE
end

local function get_command_cache(replay)
	return command_cache["no_number"],
		command_cache["number"],
		command_cache["edit"],
		command_cache["no_subnum"],
		command_cache["subnum"],
		command_cache["move"],
		command_cache["undo_mode"],
		replay
end

local function quit()
	mode.show()

	micro.CurPane():QuitCmd({})
end

local function repeat_command(number)
	mode.show()

	if not command_cached then
		micro.InfoBar():Error("no command cached yet")
		return
	end

	utils.after(editor.TICK_DELAY, function()
		for _ = 1, number do
			M.run(get_command_cache(true))
		end
	end)
end

local function undo(number, force_mode)
	if force_mode == UNDO_MODE then
		for _ = 1, number do
			micro.CurPane():Undo()
		end
	elseif force_mode == REDO_MODE then
		for _ = 1, number do
			micro.CurPane():Redo()
		end
	elseif undo_mode == UNDO_MODE then
		for _ = 1, number do
			micro.CurPane():Undo()
		end
		undo_mode = REDO_MODE
	elseif undo_mode == REDO_MODE then
		for _ = 1, number do
			micro.CurPane():Redo()
		end
		undo_mode = UNDO_MODE
	else -- program error
		micro.InfoBar():Error("undo: invalid undo mode = " .. undo_mode .. ", " .. force_mode)
	end
end

local function run(no_number, number, edit_part, no_subnum, subnum, move, force_undo_mode, replay)
	if edit_part == "d" and move == "$" then
		edit.delete_to_line_end()
		cache_command(false, number, edit_part, no_subnum, subnum, move, nil)
		return true
	elseif edit_part == "y" and move == "$" then
		edit.copy_to_line_end()
		cache_command(false, number, edit_part, no_subnum, subnum, move, nil)
		return true
	elseif edit_part == "c" and move == "$" then
		replace.replace_to_line_end(replay)
		cache_command(false, number, edit_part, no_subnum, subnum, move, nil)
		return true
	elseif edit_part == "d" and move:match("[jk\nG]+") then
		local start_loc, end_loc = M.get_region(number, no_subnum, subnum, move)
		edit.delete_lines_region(start_loc.Y, end_loc.Y)
		cache_command(false, number, edit_part, no_subnum, subnum, move, nil)
		return true
	elseif edit_part == "y" and move:match("[jk\nG]+") then
		local start_loc, end_loc = M.get_region(number, no_subnum, subnum, move)
		edit.copy_lines_region(start_loc.Y, end_loc.Y)
		cache_command(false, number, edit_part, no_subnum, subnum, move, nil)
		return true
	elseif edit_part == "c" and move:match("[jk\nG]+") then
		local start_loc, end_loc = M.get_region(number, no_subnum, subnum, move)
		replace.replace_lines_region(start_loc.Y, end_loc.Y, replay)
		cache_command(false, number, edit_part, no_subnum, subnum, move, nil)
		return true
	elseif edit_part == "d" and move:match("[hl0wbnN]+") then
		local start_loc, end_loc = M.get_region(number, no_subnum, subnum, move)
		edit.delete_words_region(start_loc, end_loc)
		cache_command(false, number, edit_part, no_subnum, subnum, move, nil)
		return true
	elseif edit_part == "y" and move:match("[hl0wbnN]+") then
		local start_loc, end_loc = M.get_region(number, no_subnum, subnum, move)
		edit.copy_words_region(start_loc, end_loc)
		cache_command(false, number, edit_part, no_subnum, subnum, move, nil)
		return true
	elseif edit_part == "c" and move:match("[hl0wbnN]+") then
		local start_loc, end_loc = M.get_region(number, no_subnum, subnum, move)
		replace.replace_words_region(start_loc, end_loc)
		cache_command(false, number, edit_part, no_subnum, subnum, move, nil)
		return true
	elseif edit_part == "i" then
		insert.insert_here(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "I" then
		insert.insert_line_start(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "a" then
		insert.insert_after_here(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "A" then
		insert.insert_after_line_end(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "o" then
		insert.open_below(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "O" then
		insert.open_above(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "dd" then
		edit.delete_lines(number)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "yy" then
		edit.copy_lines(number)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "Y" then
		edit.copy_lines(number)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "x" then
		edit.delete_chars(number)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "X" then
		edit.delete_chars_backward(number)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "D" then
		edit.delete_to_line_end()
		cache_command(false, 1, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "s" then
		replace.replace_chars(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "S" or edit_part == "cc" then
		replace.replace_lines(number, replay)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "C" then
		replace.replace_to_line_end(replay)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "p" then
		edit.paste_below(number)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "P" then
		edit.paste_above(number)
		cache_command(false, number, edit_part, true, 1, "", nil)
		return true
	elseif edit_part == "." then
		repeat_command(number)
		return true
	elseif edit_part == "u" then
		if replay then
			undo(number, force_undo_mode)
		else
			cache_command(false, number, edit_part, true, 1, "", undo_mode)
			undo(number, nil)
		end
		return true
	elseif edit_part == "ZZ" then
		quit()
		return true
	elseif move == "h" then
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

local function get_region(number, no_subnum, subnum, move)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local start_loc = buffer.Loc(cursor.X, cursor.Y)

	for _ = 1, number do
		run(no_subnum, subnum, "", true, 1, move)
	end

	local end_loc = buffer.Loc(cursor.X, cursor.Y)

	return start_loc, end_loc
end

M.run = run
M.get_region = get_region

return M
