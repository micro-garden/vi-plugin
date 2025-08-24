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

local pre_memory = nil
local memory = nil

local function pre_memorize()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	pre_memory = buffer.Loc(cursor.X, cursor.Y)
end

local function memorize()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	if pre_memory then
		if cursor.Y ~= pre_memory.Y then
			memory = pre_memory
		end
	else
		memory = buffer.Loc(cursor.X, cursor.Y)
	end
	pre_memory = nil
end

local function return_by_chars()
	if not memory then
		return
	end

	local buf = micro.CurPane().Buf

	local last_line_index = utils.last_line_index(buf)
	if memory.Y > last_line_index then
		bell.ring("line " .. memory.Y + 1 .. " (> " .. last_line_index + 1 .. ") not exists")
		return
	end
	local line = buf:Line(memory.Y)
	local length = utf8.RuneCount(line)
	local last_column = math.max(length - 1, 0)
	if memory.X > last_column then
		bell.ring("column " .. memory.X + 1 .. " (> " .. length .. ") not exists")
		return
	end

	local cursor = buf:GetActiveCursor()
	local current = buffer.Loc(cursor.X, cursor.Y)

	cursor.Y = memory.Y
	cursor.X = memory.X
	--move.update_virturl_cursor()

	memory = current
end

local function return_by_lines()
	if not memory then
		return
	end

	local buf = micro.CurPane().Buf

	local last_line_index = utils.last_line_index(buf)
	if memory.Y > last_line_index then
		bell.ring("line " .. memory.Y + 1 .. " (> " .. last_line_index + 1 .. ") not exists")
		return
	end
	local line = buf:Line(memory.Y)
	local spaces = line:match("^(%s*)")
	local x = utf8.RuneCount(spaces)

	local cursor = buf:GetActiveCursor()
	local current = buffer.Loc(cursor.X, cursor.Y)

	cursor.Y = memory.Y
	cursor.X = x
	--move.update_virturl_cursor()

	memory = current
end

-------------
-- Exports --
-------------

local M = {}

M.pre_memorize = pre_memorize
M.memorize = memorize
M.return_by_chars = return_by_chars
M.return_by_lines = return_by_lines

return M
