-- Motion Commands

local micro = import("micro")
local utf8 = import("unicode/utf8")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local utils = require("vi/utils")
local bell = require("vi/bell")
local mode = require("vi/mode")

local virtual_cursor_x = 0

--
local function update_virtual_cursor()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	virtual_cursor_x = cursor.X

	cursor:StoreVisualX()
end

--
-- Move by Character / Move by Line
--

-- h : Move cursor left by character.
local function left(num)
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	if cursor.X <= 0 then
		bell.ring("already at the line start")
		return
	end
	cursor.X = math.max(cursor.X - num, 0)

	update_virtual_cursor()
end

-- j : Move cursor down by line.
local function down(num)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)

	local dest_y = cursor.Y + num
	if dest_y > last_line_index then
		bell.ring("Not enough lines below")
		return
	end
	cursor.Y = dest_y

	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	cursor.X = math.min(virtual_cursor_x, math.max(length - 1, 0))
end

-- k : Move cursor up by line.
local function up(num)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local dest_y = cursor.Y - num
	if dest_y < 0 then
		bell.ring("Not enough lines above")
		return
	end
	cursor.Y = dest_y

	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	cursor.X = math.min(virtual_cursor_x, math.max(length - 1, 0))
end

-- l : Move cursor right by character.
local function right(num)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	if cursor.X >= length - 1 then
		bell.ring("already at the line end")
	end
	cursor.X = math.min(cursor.X + num, math.max(length - 1, 0))

	update_virtual_cursor()
end

--
-- Move in Line
--

-- 0 : Move cursor to start of current line.
local function to_start()
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.X = 0

	update_virtual_cursor()
end

-- $ : Move cursor to end of current line.
local function to_end()
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	cursor.X = math.max(length - 1, 0)

	update_virtual_cursor()
end

-- ^ : Move cursor to first non-blank character of current line.
local function to_non_blank()
	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local spaces = line:match("^(%s*)")
	local x = utf8.RuneCount(spaces)
	local length = utf8.RuneCount(line)
	if x >= length then
		x = math.max(x - 1, 0)
	end
	cursor.X = x
	update_virtual_cursor()
end

-- <num>| : Move cursor to column <num> of current line.
-- XXX Column is rune-based, not visual-based.
local function to_column(num)
	if num < 1 then
		bell.fatal("to_column: 1 > num = " .. num)
	end

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	local max_x = math.max(length - 1, 0)
	cursor.X = math.max(math.min(num - 1, max_x), 0)
	update_virtual_cursor()
end

--
-- Move by Word / Move by Loose Word
--

-- w : Move cursor forward by word.
local function by_word(num)
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

	for _ = 1, num do
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

-- internal use
-- (g) : Move cursor forward by word to be used by cw command.
local function by_word_for_change(num)
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

	for _ = 1, num do
		if cursor.X >= length - 1 and cursor.Y >= last_line_index then
			break
		end
		local str = utils.utf8_sub(line, cursor.X + 1)

		local word, word_spaces, symbols, _ = str:match("^([%w_\128-\255]*)(%s*)([^%w_\128-\255%s]*)(%s*)")
		local forward
		if #word > 0 then
			forward = utf8.RuneCount(word)
		elseif #symbols > 0 then
			forward = utf8.RuneCount(symbols)
		else
			forward = utf8.RuneCount(word_spaces)
		end

		local end_of_line = cursor.X >= length
		cursor.X = cursor.X + forward

		--if cursor.X > length - 1 then
		if end_of_line then
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

-- b : Move cursor backward by word.
local function backward_by_word(num)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	if cursor.X < 1 and cursor.Y < 1 then
		bell.ring("no more words behind")
		return
	end

	for _ = 1, num do
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

-- internal use
-- (none) : Move cursor forward by one word.
local function one_word()
	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	local last_line_index = utils.last_line_index(buf)

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

-- e : Move cursor to end of word.
local function to_end_of_word(num)
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

	local str = utils.utf8_sub(line, cursor.X + 1)
	local word, _, symbols, _ = str:match("^([%w_\128-\255]*)(%s*)([^%w_\128-\255%s]*)(%s*)")
	if #word == 1 or #symbols == 1 then
		one_word()
	end

	for _ = 1, num do
		if cursor.X >= length - 1 and cursor.Y >= last_line_index then
			break
		end
		str = utils.utf8_sub(line, cursor.X + 1)

		word, _, symbols, _ = str:match("^([%w_\128-\255]*)(%s*)([^%w_\128-\255%s]*)(%s*)")
		local forward
		if #word > 0 then
			forward = utf8.RuneCount(word) - 1
		elseif #symbols > 0 then
			forward = utf8.RuneCount(symbols) - 1
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

-- W : Move cursor forward by loose word.
local function by_loose_word(num)
	bell.planned("W (move.by_loose_word)")
end

-- B : Move cursor backward by loose word.
local function backward_by_loose_word(num)
	bell.planned("B (move.backward_by_loose_word)")
end

-- E : Move cursor to end of loose word.
local function to_end_of_loose_word(num)
	bell.planned("E (move.to_end_of_loose_word)")
end

--
-- Move by Line
--

-- Enter, + :  Move cursor to first non-blank character of next line.
local function to_non_blank_of_next_line(num)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)

	local dest_y = cursor.Y + num
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

-- - : Move cursor to first non-blank character of previous line.
local function to_non_blank_of_prev_line(num)
	bell.planned("- (move.to_non_blank_of_prev_line)")
end

-- G : Move cursor to last line.
local function to_last_line()
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	cursor.Y = utils.last_line_index(buf)
	cursor.X = 0
	update_virtual_cursor()
end

-- <num>G : Move cursor to line <num>.
local function to_line(num)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)
	if num - 1 > last_line_index then
		bell.ring("line number too large: " .. num .. " > " .. last_line_index + 1)
		return
	end
	cursor.Y = num - 1
	cursor.X = 0
	update_virtual_cursor()
end

--
-- Move by Block
--

-- ) : Move cursor forward by sentence.
local function by_sentence(num)
	bell.planned(") (move.by_sentence)")
end

-- ( : Move cursor backward by sentence.
local function backward_by_sentence(num)
	bell.planned("( (move.backward_by_sentence)")
end

-- } : Move cursor forward by paragraph.
local function by_paragraph(num)
	bell.planned("} (move.by_paragraph)")
end

-- { : Move cursor backward by paragraph.
local function backward_by_paragraph(num)
	bell.planned("{ (move.backward_by_paragraph)")
end

-- ]] : Move cursor forward by section.
local function by_section(num)
	bell.planned("]] (move.by_section)")
end

-- [[ : Move cursor backward by section.
local function backward_by_section(num)
	bell.planned("[[ (move.backward_by_section)")
end

--
-- Move in View
--

-- H : Move cursor to top of view.
local function to_top_of_view()
	bell.planned("H (move.to_top_of_view)")
end

-- M : Move cursor to middle of view.
local function to_middle_of_view()
	bell.planned("M (move.to_middle_of_view)")
end

-- L : Move cursor to bottom of view.
local function to_bottom_of_view()
	bell.planned("L (move.to_bottom_of_view)")
end

-- <num>H : Move cursor below <num> lines from top of view.
local function to_below_top_of_view(num)
	bell.planned("<num>H (to_below_top_of_view)")
end

-- <num>L : Move cursor above <num> lines from bottom of view.
local function to_above_bottom_of_view(num)
	bell.planned("<num>L (to_bottom_of_view)")
end

-------------
-- Exports --
-------------

local M = {}

-- internal use
M.update_virtual_cursor = update_virtual_cursor

-- Move by Character / Move by line
M.left = left
M.down = down
M.up = up
M.right = right

-- Move in Line
M.to_start = to_start
M.to_end = to_end
M.to_non_blank = to_non_blank
M.to_column = to_column

-- Move by Word / Move by Loose Word
M.by_word = by_word
M.by_word_for_change = by_word_for_change
M.backward_by_word = backward_by_word
M.to_end_of_word = to_end_of_word
M.by_loose_word = by_loose_word
M.backward_by_loose_word = backward_by_loose_word
M.to_end_of_loose_word = to_end_of_loose_word

-- Move by Line
M.to_non_blank_of_next_line = to_non_blank_of_next_line
M.to_non_blank_of_prev_line = to_non_blank_of_prev_line
M.to_last_line = to_last_line
M.to_line = to_line

-- Move by Block
M.by_sentence = by_sentence
M.backward_by_sentence = backward_by_sentence
M.by_paragraph = by_paragraph
M.backward_by_paragraph = backward_by_paragraph
M.by_section = by_section
M.backward_by_section = backward_by_section

-- Move in View
M.to_top_of_view = to_top_of_view
M.to_middle_of_view = to_middle_of_view
M.to_bottom_of_view = to_bottom_of_view
M.to_below_top_of_view = to_below_top_of_view
M.to_above_bottom_of_view = to_above_bottom_of_view

return M
