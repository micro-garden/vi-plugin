local M = {}

local micro = import("micro")
local utf8 = import("unicode/utf8")

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local bell = require("bell")
local mode = require("mode")
local utils = require("utils")

local virtual_cursor_x = 0

local function update_virtual_cursor()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	virtual_cursor_x = cursor.X

	cursor:StoreVisualX()
end

-- command: h
local function move_left(number)
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	if cursor.X <= 0 then
		bell.ring("already at the beginning of the line")
		return
	end
	cursor.X = math.max(cursor.X - number, 0)

	update_virtual_cursor()
end

-- command: l
local function move_right(number)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	if cursor.X >= length - 1 then
		bell.ring("already at the end of the line")
	end
	cursor.X = math.min(cursor.X + number, math.max(length - 1, 0))

	update_virtual_cursor()
end

-- command: k
local function move_up(number)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local dest_y = cursor.Y - number
	if dest_y < 0 then
		bell.ring("cannot move up to line " .. dest_y + 1)
		return
	end
	cursor.Y = dest_y

	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	cursor.X = math.min(virtual_cursor_x, math.max(length - 1, 0))
end

-- command: j
local function move_down(number)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)

	local dest_y = cursor.Y + number
	if dest_y > last_line_index then
		bell.ring("cannot move down to line " .. dest_y + 1 .. " > " .. last_line_index + 1)
		return
	end
	cursor.Y = dest_y

	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	cursor.X = math.min(virtual_cursor_x, math.max(length - 1, 0))
end

-- command: 0
local function move_line_start()
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.X = 0

	update_virtual_cursor()
end

-- command: $
local function move_line_end()
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	cursor.X = math.max(length - 1, 0)

	update_virtual_cursor()
end

-- command: \n
local function move_next_line_start(number)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)

	local dest_y = cursor.Y + number
	if dest_y > last_line_index then
		bell.ring("cannot move down to line " .. dest_y + 1 .. " > " .. last_line_index + 1)
		return
	end
	cursor.Y = dest_y

	local line = buf:Line(cursor.Y)
	local spaces = line:match("^(%s*)")
	cursor.X = utf8.RuneCount(spaces)
	update_virtual_cursor()

	micro.CurPane():Relocate()
end

-- command: w
local function move_next_word(number)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	for _ = 1, number do
		local line = buf:Line(cursor.Y)
		local length = utf8.RuneCount(line)

		if cursor.X >= length - 1 then
			local last_line_index = utils.last_line_index(buf)
			if cursor.Y >= last_line_index then
				bell.ring("no next words")
				break
			end
			cursor.Y = cursor.Y + 1

			line = buf:Line(cursor.Y)
			local spaces = line:match("^(%s*)")
			cursor.X = utf8.RuneCount(spaces)
		else
			local str = line
			local cursor_x = cursor.X
			for _ = 1, cursor_x do
				local _, size = utf8.DecodeRuneInString(str)
				str = str:sub(1 + size)
			end

			local prefix, prespaces, word, postspaces, postfix =
				str:match("^([^%w_\128-\255%s]*)(%s*)([%w_\128-\255]*)(%s*)([^%w\128-\255]*)")
			local forward = 0
			if #prefix > 0 then
				forward = utf8.RuneCount(prefix .. prespaces)
			elseif #word > 0 and #postfix > 0 then
				forward = utf8.RuneCount(prefix .. prespaces .. word .. postspaces)
			elseif #word > 0 and #postspaces > 0 then
				forward = utf8.RuneCount(prefix .. prespaces .. word .. postspaces)
			elseif #word > 0 then
				forward = utf8.RuneCount(prefix .. prespaces .. word .. postspaces) + 1
			elseif #prespaces > 0 then
				forward = utf8.RuneCount(prespaces)
			end

			cursor.X = cursor.X + forward
			local last_line_index = buf:LinesNum() - 1
			while cursor.X > length - 1 do
				if cursor.Y >= last_line_index - 1 then
					local last_line = buf:Line(last_line_index)
					local last_line_length = utf8.RuneCount(last_line)
					if last_line_length < 1 then
						break
					end
				end
				cursor.Y = cursor.Y + 1

				line = buf:Line(cursor.Y)
				length = utf8.RuneCount(line)
				local spaces = line:match("^(%s*)")
				cursor.X = cursor.X + utf8.RuneCount(spaces)

				if cursor.Y == last_line_index - 1 then
					local last_line = buf:Line(last_line_index)
					local last_line_length = utf8.RuneCount(last_line)
					if last_line_length < 1 then
						break
					end
				elseif cursor.Y >= last_line_index then
					break
				end
			end
		end
	end

	update_virtual_cursor()
end

local function move_prev_word(number)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	for _ = 1, number do
		if cursor.X < 1 and cursor.Y < 1 then
			bell.ring("no previous words")
			break
		else
			local line = buf:Line(cursor.Y)

			local str = line
			local cursor_x = cursor.X
			local start_offset = 0
			for _ = 1, cursor_x do
				local _, size = utf8.DecodeRuneInString(str)
				str = str:sub(1 + size)
				start_offset = start_offset + size
			end

			str = line:sub(1, start_offset):reverse()

			local prefix, prespaces, word, postspaces, postfix =
				str:match("^([^%w_\128-\255%s]*)(%s*)([%w_\128-\255]*)(%s*)([^%w\128-\255%s]*)")
			local backward = 0
			if cursor.X < 1 then
				backward = cursor.X + 1
			elseif #prefix > 0 then
				backward = utf8.RuneCount(prefix .. prespaces)
			elseif #word > 0 and #postfix > 0 then
				backward = utf8.RuneCount(prefix .. prespaces .. word)
			elseif #word > 0 and #postspaces > 0 then
				backward = utf8.RuneCount(prefix .. prespaces .. word)
			elseif #word > 0 then
				backward = utf8.RuneCount(prefix .. prespaces .. word)
			elseif #prespaces > 0 and #postfix > 0 then
				backward = utf8.RuneCount(prespaces .. postfix)
			elseif #prespaces > 0 then
				backward = utf8.RuneCount(prespaces) + 1
			end

			local carry = backward > 0 and cursor.X - backward < 0
			cursor.X = math.max(cursor.X - backward, 0)
			while carry do
				if cursor.Y < 1 and cursor.X < 1 then
					break
				end

				cursor.Y = cursor.Y - 1

				line = buf:Line(cursor.Y):reverse()
				local length = utf8.RuneCount(line)
				cursor.X = math.max(length - 1, 0)

				if length > 0 then
					local spaces, word, symbols = line:match("^(%s*)([%w_\128-\255]*)([^%w_\128-\255%s]*)") -- luacheck: ignore
					backward = 0
					if #word > 0 then
						backward = utf8.RuneCount(word .. spaces) - 1
					elseif #symbols > 0 then
						backward = utf8.RuneCount(symbols .. spaces) - 1
					elseif #spaces > 0 then
						backward = utf8.RuneCount(spaces) + 1
					end

					carry = backward > 0 and cursor.X - backward < 0

					cursor.X = math.max(cursor.X - backward, 0)
				end
			end
		end
	end

	update_virtual_cursor()
end

local function goto_bottom()
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	cursor.Y = utils.last_line_index(buf)
	cursor.X = 0
	update_virtual_cursor()
end

local function goto_line(number)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)
	if number - 1 > last_line_index then
		bell.ring("line number out of range: " .. number .. " > " .. last_line_index + 1)
		return
	end
	cursor.Y = number - 1
	cursor.X = 0
	update_virtual_cursor()
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
