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

local bell = require("bell")
local mode = require("mode")
local move = require("move")
local utils = require("utils")

local marks = {}

--
-- Set Mark / Move to Mark
--

-- key: m{letter}
local function set(letter)
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local loc = buffer.Loc(cursor.X, cursor.Y)

	marks[letter] = loc
end

-- key: `{letter}
local function move_to(letter)
	mode.show()

	local loc = marks[letter]
	if not loc then
		bell.ring("no mark set for " .. letter)
		return
	end

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index()
	cursor.Y = math.min(loc.Y, last_line_index)

	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	cursor.X = math.min(loc.X, length - 1)

	move.update_virtual_cursor()
end

-- key: '{letter}
local function move_to_line(letter)
	mode.show()

	local loc = marks[letter]
	if not loc then
		bell.ring("no mark set for " .. letter)
		return
	end

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local last_line_index = utils.last_line_index()
	cursor.Y = math.min(loc.Y, last_line_index)

	cursor.X = 0

	move.update_virtual_cursor()
end

--
-- Move by Context
--

-- key: ``
local function back()
	bell.planned("`` (mark.back)" )
end

-- key: ''
local function back_to_line()
	bell.planned("'' (mark.back_to_line)")
end

-- Set Mark / Move to Mark
M.set = set
M.move_to = move_to
M.move_to_line = move_to_line

-- Move by Context
M.back = back
M.back_to_line = back_to_line

return M
