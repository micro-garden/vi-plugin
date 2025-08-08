M = {}

local micro = import("micro")
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

local command_cached = false
local command_cache = {
	["no_number"] = false,
	["number"] = 1,
	["edit"] = "",
	["move"] = "",
}

local function cache_command(no_number, number, edit, move)
	command_cache["no_number"] = no_number
	command_cache["number"] = number
	command_cache["edit"] = edit
	command_cache["move"] = move

	command_cached = true
end

local function get_command_cache()
	return command_cache["no_number"], command_cache["number"], command_cache["edit"], command_cache["move"]
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

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(editor.TICK_DELAY, function()
			for _ = 1, number do
				M.run(get_command_cache())
			end
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(editor.TICK_DELAY, function()
			for _ = 1, number do
				M.run(get_command_cache())
			end
		end)
	end
end

local function undo(number)
	for _ = 1, number do
		micro.CurPane():Undo()
	end
end

local function redo(number)
	for _ = 1, number do
		micro.CurPane():Redo()
	end
end

local function run(no_number, number, edit_part, move)
	if edit_part == "i" then
		insert.insert_here()
		cache_command(false, number, edit_part, "")
		return true
	elseif edit_part == "I" then
		insert.insert_line_start()
		cache_command(false, number, edit_part, "")
		return true
	elseif edit_part == "a" then
		insert.insert_after_here()
		cache_command(false, number, edit_part, "")
		return true
	elseif edit_part == "A" then
		insert.insert_after_line_end()
		cache_command(false, number, edit_part, "")
		return true
	elseif edit_part == "o" then
		insert.open_below()
		cache_command(false, number, edit_part, "")
		return true
	elseif edit_part == "O" then
		insert.open_above()
		cache_command(false, number, edit_part, "")
		return true
	elseif edit_part == "dd" then
		edit.delete_lines(number)
		cache_command(false, number, edit_part, "")
		return true
	elseif edit_part == "yy" then
		edit.copy_lines(number)
		cache_command(false, number, edit_part, "")
		return true
	elseif edit_part == "Y" then
		edit.copy_lines(number)
		cache_command(false, number, edit_part, "")
		return true
	elseif edit_part == "x" then
		edit.delete_chars(number)
		cache_command(false, number, edit_part, "")
		return true
	elseif edit_part == "X" then
		edit.delete_chars_backward(number)
		cache_command(false, number, edit_part, "")
		return true
	elseif edit_part == "p" then
		edit.paste_below(number)
		cache_command(false, number, edit_part, "")
		return true
	elseif edit_part == "P" then
		edit.paste_above(number)
		cache_command(false, number, edit_part, "")
		return true
	elseif edit_part == "." then
		repeat_command(number)
		return true
	elseif edit_part == "u" then
		undo(number)
		return true
	elseif edit_part == "U" then
		redo(number)
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
	elseif edit_part == "ZZ" then
		quit()
		return true
	else
		return false
	end
end

M.run = run

return M
