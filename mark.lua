M = {}

local micro = import("micro")
local buffer = import("micro/buffer")
local utf8 = import("unicode/utf8")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/vi/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local mode = require("mode")
local motion = require("motion")

local marks = {}

local function set(letter)
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local loc = buffer.Loc(cursor.Loc.X, cursor.Loc.Y)

	marks[letter] = loc
end

local function goto_line(letter)
	mode.show()

	loc = marks[letter]
	if not loc then
		micro.InfoBar():Error("no mark set for " .. letter)
		return
	end

	local cursor = micro.CurPane().Buf:GetActiveCursor()

	cursor.Loc.X = 0

	local last_line_index = cursor:Buf():LinesNum() - 1
	local line = cursor:Buf():Line(last_line_index)
	local length = utf8.RuneCount(line)
	if length < 1 then
		last_line_index = math.max(last_line_index - 1, 0)
	end

	cursor.Loc.Y = math.min(loc.Y, last_line_index)

	motion.update_virtual_cursor()
end

local function goto_char(letter)
	mode.show()

	loc = marks[letter]
	if not loc then
		micro.InfoBar():Error("no mark set for " .. letter)
		return
	end

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local last_line_index = cursor:Buf():LinesNum() - 1
	local line = cursor:Buf():Line(last_line_index)
	local length = utf8.RuneCount(line)
	if length < 1 then
		last_line_index = math.max(last_line_index - 1, 0)
	end

	cursor.Loc.Y = math.min(loc.Y, last_line_index)

	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)

	cursor.Loc.X = math.min(loc.X, length - 1)

	motion.update_virtual_cursor()
end

M.set = set
M.goto_line = goto_line
M.goto_char = goto_char

return M
