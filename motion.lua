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
		bell.ring("already at the line start")
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
		bell.ring("already at the line end")
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
		bell.ring("Not enough lines above")
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
		bell.ring("Not enough lines below")
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

local function move_prev_line_start(number)
	bell.todo("not implemented yet")
end

local function move_to_first_non_blank()
	bell.todo("not implemented yet")
end

local function move_to_column(number)
	bell.todo("not implemented yet")
end

-- command: w
local function move_word(number)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	local last_line_index = utils.last_line_index(buf)
	if cursor.X >= length - 1 and cursor.Y >= last_line_index then
		bell.ring("no more words ahead")
		return
	end

	for _ = 1, number do
		if cursor.X >= length - 1 and cursor.Y >= last_line_index then
			break
		end
		local str = utils.utf8_sub(line, cursor.X + 1)

		local word, word_spaces, symbols, symbol_spaces = str:match("^([%w_\128-\255]*)(%s*)([^%w_\128-\255%s]*)(%s*)")
		local forward
		if #word > 0 then
			forward = utf8.RuneCount(word .. word_spaces)
		elseif #symbols > 0 then
			forward = utf8.RuneCount(symbols .. symbol_spaces)
		else
			forward = utf8.RuneCount(word_spaces)
		end
		cursor.X = cursor.X + forward

		if cursor.X > length - 1 then
			while cursor.Y < last_line_index do
				cursor.Y = cursor.Y + 1

				line = buf:Line(cursor.Y)
				length = utf8.RuneCount(line)
				local spaces = line:match("^(%s*)")
				cursor.X = utf8.RuneCount(spaces)

				if length > cursor.X then
					break
				end
			end
			cursor.X = math.min(cursor.X, length - 1)
		end
	end

	update_virtual_cursor()
end

local function move_word_loose(number)
	bell.todo("not implemented yet")
end

-- command: b
local function move_word_back(number)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	if cursor.X < 1 and cursor.Y < 1 then
		bell.ring("no more words behind")
		return
	end

	for _ = 1, number do
		if cursor.X < 1 and cursor.Y < 1 then
			break
		end
		local line = buf:Line(cursor.Y)
		local str = utils.utf8_sub(line, 1, cursor.X):reverse()

		local spaces, symbols, word = str:match("^(%s*)([^%w_\128-\255%s]*)([%w_\128-\255]*)")
		local backward
		if #symbols > 0 then
			backward = utf8.RuneCount(spaces .. symbols)
		elseif #word > 0 then
			backward = utf8.RuneCount(spaces .. word)
		else
			backward = utf8.RuneCount(spaces) + 1
		end
		cursor.X = cursor.X - backward

		if cursor.X < 0 then
			local length
			while cursor.Y > 0 do
				cursor.Y = cursor.Y - 1

				line = buf:Line(cursor.Y)
				length = utf8.RuneCount(line)
				if not line:match("^(%s*)$") then
					break
				end
			end
			cursor.X = length

			local str = utils.utf8_sub(line, 1, cursor.X):reverse() -- luacheck: ignore
			local spaces, symbols, word = str:match("^(%s*)([^%w_\128-\255%s]*)([%w_\128-\255]*)") -- luacheck: ignore
			local backward -- luacheck: ignore
			if #symbols > 0 then
				backward = utf8.RuneCount(spaces .. symbols)
			elseif #word > 0 then
				backward = utf8.RuneCount(spaces .. word)
			else
				backward = utf8.RuneCount(spaces)
			end
			cursor.X = cursor.X - backward
		end
	end

	update_virtual_cursor()
end

local function move_word_back_loose(number)
	bell.todo("not implemented yet")
end

local function move_word_end(number)
	bell.todo("not implemented yet")
end

local function move_word_end_loose(number)
	bell.todo("not implemented yet")
end

local function move_sentence(number)
	bell.todo("not implemented yet")
end

local function move_sentence_back(number)
	bell.todo("not implemented yet")
end

local function move_paragraph(number)
	bell.todo("not implemented yet")
end

local function move_paragraph_back(number)
	bell.todo("not implemented yet")
end

local function move_section(number)
	bell.todo("not implemented yet")
end

local function move_section_back(number)
	bell.todo("not implemented yet")
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
		bell.ring("line number too large: " .. number .. " > " .. last_line_index + 1)
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
M.move_prev_line_start = move_prev_line_start
M.move_to_first_non_blank = move_to_first_non_blank
M.move_to_column = move_to_column

M.move_word = move_word
M.move_word_loose = move_word_loose
M.move_word_back = move_word_back
M.move_word_back_loose = move_word_back_loose
M.move_word_end = move_word_end
M.move_word_end_loose = move_word_end_loose

M.move_sentence = move_sentence
M.move_sentence_back = move_sentence_back
M.move_paragraph = move_sentence
M.move_paragraph_back = move_sentence_back
M.move_section = move_section
M.move_section_back = move_section_back

M.goto_bottom = goto_bottom
M.goto_line = goto_line

return M
