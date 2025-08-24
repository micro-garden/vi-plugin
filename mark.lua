-- Marking Commands

local micro = import("micro")
local buffer = import("micro/buffer")
local utf8 = import("unicode/utf8")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local utils = require("vi/utils")
local bell = require("vi/bell")
local mode = require("vi/mode")
local context = require("vi/context")
local move = require("vi/move")

local marks = {}

--
-- Set Mark / Move to Mark
--

-- m<letter> : Mark current cursor position labelled by <letter>.
local function set(letter)
	if #letter ~= 1 then
		bell.program_error("1 ~= #letter == " .. #letter)
		return
	end

	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local loc = buffer.Loc(cursor.X, cursor.Y)

	marks[letter] = loc
end

-- `<letter> : Move cursor to marked position labelled by <letter>.
local function move_to(letter)
	if #letter ~= 1 then
		bell.program_error("1 ~= #letter == " .. #letter)
		return
	end

	mode.show()

	local loc = marks[letter]
	if not loc then
		bell.ring("no mark set for " .. letter)
		return
	end

	context.memorize()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index()
	cursor.Y = math.min(loc.Y, last_line_index)

	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	cursor.X = math.min(loc.X, length - 1)

	move.update_virtual_cursor()
end

-- '<letter> : Move cursor to marked line labelled by <letter>.
local function move_to_line(letter)
	if #letter ~= 1 then
		bell.program_error("1 ~= #letter == " .. #letter)
		return
	end

	mode.show()

	local loc = marks[letter]
	if not loc then
		bell.ring("no mark set for " .. letter)
		return
	end

	context.pre_memorize()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local last_line_index = utils.last_line_index()
	cursor.Y = math.min(loc.Y, last_line_index)

	cursor.X = 0

	move.update_virtual_cursor()

	context.memorize()
end

--
-- Move by Context
--

-- `` : Move cursor to previous position in context.
local function back()
	mode.show()

	if not context.return_by_chars() then
		return
	end

	move.update_virtual_cursor()
end

-- '' :  Move cursor to previous line in context.
local function back_to_line()
	mode.show()

	if not context.return_by_lines() then
		return
	end

	move.update_virtual_cursor()
end

-------------
-- Exports --
-------------

local M = {}

-- Set Mark / Move to Mark
M.set = set
M.move_to = move_to
M.move_to_line = move_to_line

-- Move by Context
M.back = back
M.back_to_line = back_to_line

return M
