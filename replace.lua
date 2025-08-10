M = {}

local micro = import("micro")
local buffer = import("micro/buffer")
local utf8 = import("unicode/utf8")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/vi/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local editor = require("editor")
local mode = require("mode")
local motion = require("motion")
local edit = require("edit")
local insert = require("insert")
local utils = require("utils")

local function replace_chars(number, replay)
	insert.replace_mode()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)

	local saved_x = cursor.Loc.X
	local insert_after = cursor.Loc.X + number >= length

	edit.clear_deleted_words()

	local n = math.min(number, length - cursor.Loc.X)

	local str = line
	local start_offset = 0
	local cursor_x = cursor.Loc.X
	for _ = 1, cursor_x do
		local r, size = utf8.DecodeRuneInString(str)
		str = str:sub(1 + size)
		start_offset = start_offset + size
	end

	local end_offset = start_offset
	for _ = 1, n do
		local r, size = utf8.DecodeRuneInString(str)
		str = str:sub(1 + size)
		end_offset = end_offset + size
	end

	edit.insert_deleted_word(line:sub(1 + start_offset, end_offset))

	for _ = 1, n do
		micro.CurPane():Delete()
	end

	if replay then
		local loc = buffer.Loc(cursor.Loc.X, cursor.Loc.Y)
		insert.extend(loc, replace_chars, 1, replay)
	else
		mode.show()

		local line = cursor:Buf():Line(cursor.Loc.Y)
		local length = utf8.RuneCount(line)
		cursor.Loc.X = math.min(cursor.Loc.X + 1, length - 1)

		utils.after(editor.TICK_DELAY, function()
			local cursor = micro.CurPane().Buf:GetActiveCursor()
			local line = cursor:Buf():Line(cursor.Loc.Y)
			local length = utf8.RuneCount(line)
			if insert_after then
				cursor.Loc.X = math.min(saved_x, math.max(length, 0))
			else
				cursor.Loc.X = math.min(saved_x, math.max(length - 1, 0))
			end
			motion.update_virtual_cursor()

			insert.insert_here_replace(1, replay)
		end)
	end
end

local function replace_lines(number, replay)
	edit.delete_lines(number)
	insert.open_here(1, replay)
end

local function replace_to_line_end(replay)
	edit.delete_to_line_end(number)
	insert.insert_after_here(1, replay)
end

local function replace_lines_region(start_y, end_y, replay)
	edit.delete_lines_region(start_y, end_y)
	insert.open_here(1, replay)
end

local function replace_words_region(start_loc, end_loc)
	edit.delete_words_region(start_loc, end_loc)
	insert.insert_here(1, replay)
end

M.replace_chars = replace_chars
M.replace_lines = replace_lines
M.replace_to_line_end = replace_to_line_end

M.replace_lines_region = replace_lines_region
M.replace_words_region = replace_words_region

return M
