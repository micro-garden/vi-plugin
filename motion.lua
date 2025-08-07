M = {}

local micro = import("micro")
local utf8 = import("unicode/utf8")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/vi/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local mode = require("mode")

local virtual_cursor_x = 0

local function update_virtual_cursor()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	virtual_cursor_x = cursor.Loc.X
end

local function move_left(number)
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.Loc.X = math.max(cursor.Loc.X - number, 0)

	virtual_cursor_x = cursor.Loc.X
end

local function move_right(number)
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(cursor.Loc.X + number, math.max(length - 1, 0))

	virtual_cursor_x = cursor.Loc.X
end

local function move_up(number)
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.Loc.Y = math.max(cursor.Loc.Y - number, 0)

	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(virtual_cursor_x, math.max(length - 1, 0))
end

local function move_down(number)
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local last_line_index = cursor:Buf():LinesNum() - 1
	local y = math.min(cursor.Loc.Y + number, last_line_index)
	if y == last_line_index then
		local line = cursor:Buf():Line(y)
		local length = utf8.RuneCount(line)
		if length < 1 then
			y = math.max(y - 1, 0)
		end
	end
	cursor.Loc.Y = y

	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(virtual_cursor_x, math.max(length - 1, 0))
end

local function move_line_start()
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.Loc.X = 0

	virtual_cursor_x = cursor.Loc.X
end

local function move_line_end()
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.max(length - 1, 0)

	virtual_cursor_x = cursor.Loc.X
end

local function move_next_line_start(number)
	mode.show()

	move_line_start()
	move_down(number)

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	virtual_cursor_x = cursor.Loc.X

	micro.CurPane():Relocate()
end

-- XXX incompatible with proper vi
-- using micro's Cursor.WordRight
local function move_next_word(number)
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	for _ = 1, number do
		local line = cursor:Buf():Line(cursor.Loc.Y)
		local length = utf8.RuneCount(line)

		if cursor.Loc.X == length - 1 then
			local last_line_index = cursor:Buf():LinesNum() - 1
			if cursor.Loc.Y == last_line_index - 1 then
				local line = cursor:Buf():Line(last_line_index)
				local length = utf8.RuneCount(line)
				if length < 1 then
					break -- vi error
				end
			end

			cursor.Loc.X = length
			cursor:WordRight() -- XXX micro method
		else
			cursor:WordRight() -- XXX micro method
			cursor.Loc.X = math.min(cursor.Loc.X + 1, math.max(length - 1, 0))
		end
	end

	virtual_cursor_x = cursor.Loc.X
end

-- XXX incompatible with proper vi
-- using micro's Cursor.WordLeft
local function move_prev_word(number)
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	for _ = 1, number do
		cursor:WordLeft() -- XXX micro method
	end

	virtual_cursor_x = cursor.Loc.X
end

local function goto_bottom()
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local last_line_index = cursor:Buf():LinesNum() - 1
	local line = cursor:Buf():Line(last_line_index)
	local length = utf8.RuneCount(line)
	if length < 1 then
		last_line_index = last_line_index - 1
	end
	cursor.Loc.Y = last_line_index
	cursor.Loc.X = 0
	virtual_cursor_x = cursor.Loc.X
end

local function goto_line(number)
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local last_line_index = cursor:Buf():LinesNum() - 1
	local line = cursor:Buf():Line(last_line_index)
	local length = utf8.RuneCount(line)
	if length < 1 then
		last_line_index = last_line_index - 1
	end
	if number - 1 > last_line_index then
		micro.InfoBar():Error("line number out of range: " .. number .. " > " .. last_line_index + 1)
		return
	end
	cursor.Loc.Y = number - 1
	cursor.Loc.X = 0
	virtual_cursor_x = cursor.Loc.X
end

M.update_virtual_cursor = update_virtual_cursor
M.move_left = move_left
M.move_right = move_right
M.move_up = move_up
M.move_down = move_down
M.move_line_start = move_line_start
M.move_line_end = move_line_end
M.move_next_line_start = move_next_line_start
M.move_next_word = move_next_word
M.move_prev_word = move_prev_word
M.goto_bottom = goto_bottom
M.goto_line = goto_line

return M
