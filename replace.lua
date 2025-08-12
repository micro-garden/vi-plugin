local M = {}

local micro = import("micro")
local buffer = import("micro/buffer")
local utf8 = import("unicode/utf8")

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local mode = require("mode")
local motion = require("motion")
local edit = require("edit")
local insert = require("insert")
local utils = require("utils")

local function replace_chars(number, replay)
	insert.replace_mode()

	local pane = micro.CurPane()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)

	local n = math.min(number, length - cursor.X)

	edit.clear_kill_buffer()
	edit.insert_killed_chars(utils.utf8_sub(line, 1 + cursor.X, cursor.X + n))

	local saved_x = cursor.X
	local insert_after = cursor.X + number >= length

	for _ = 1, n do
		pane:Delete()
	end

	if replay then
		local loc = buffer.Loc(cursor.X, cursor.Y)
		insert.extend(loc, 1, replay)
	else
		mode.show()

		line = buf:Line(cursor.Y)
		length = utf8.RuneCount(line)
		cursor.X = math.min(cursor.X + 1, length - 1)

		utils.next_tick(function()
			line = buf:Line(cursor.Y)
			length = utf8.RuneCount(line)
			if insert_after then
				cursor.X = math.min(saved_x, math.max(length, 0))
			else
				cursor.X = math.min(saved_x, math.max(length - 1, 0))
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
	edit.delete_to_line_end()
	insert.insert_after_here(1, replay)
end

local function replace_lines_region(start_y, end_y, replay)
	edit.delete_lines_region(start_y, end_y)
	insert.open_here(1, replay)
end

local function replace_chars_region(start_loc, end_loc, replay)
	local insert_after = false

	if end_loc.Y > start_loc.Y and end_loc.X < 1 then
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		local line = cursor:Buf():Line(end_loc.Y - 1)
		local length = utf8.RuneCount(line)
		end_loc = buffer.Loc(length, end_loc.Y - 1)
		cursor.X = length
		cursor.Y = end_loc.Y

		insert_after = true
	end

	edit.delete_chars_region(start_loc, end_loc)

	utils.next_tick(function()
		if insert_after then
			insert.insert_after_here(1, replay)
		else
			insert.insert_here(1, replay)
		end
	end, 2)
end

M.replace_chars = replace_chars
M.replace_lines = replace_lines
M.replace_to_line_end = replace_to_line_end

M.replace_lines_region = replace_lines_region
M.replace_chars_region = replace_chars_region

return M
