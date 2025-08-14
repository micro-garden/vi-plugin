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

--
-- Move by Character / Move by Line
--

-- key: h
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

-- key: j
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

-- key: k
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

-- key: l
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

-- key: 0
local function to_start_of_line()
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.X = 0

	update_virtual_cursor()
end

-- key: $
local function to_end_of_line()
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	cursor.X = math.max(length - 1, 0)

	update_virtual_cursor()
end

-- key: ^
local function to_non_blank_of_line()
	bell.planned("^ (move.to_non_blank_of_line)")
end

-- key: <num>|
local function to_column(num)
	bell.planned("<num>| (move.to_column)")
end

--
-- Move by Word / Move by Loose Word
--

-- key: w
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

-- key: b
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

-- key: e
local function to_end_of_word(num)
	bell.planned("e (move.to_end_of_word)")
end

-- key: W
local function by_loose_word(num)
	bell.planned("W (move.by_loose_word)")
end

-- key: B
local function backward_by_loose_word(num)
	bell.planned("B (move.backward_by_loose_word)")
end

-- key: E
local function to_end_of_loose_word(num)
	bell.planned("E (move.to_end_of_loose_word)")
end

--
-- Move by Line
--

-- key: Enter, +
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

-- key: -
local function to_non_blank_of_prev_line(num)
	bell.planned("- (move.to_non_blank_of_prev_line)")
end

-- key: G
local function to_last_line()
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	cursor.Y = utils.last_line_index(buf)
	cursor.X = 0
	update_virtual_cursor()
end

-- key: <num>G
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

-- key: )
local function by_sentence(num)
	bell.planned(") (move.by_sentence)")
end

-- key: (
local function backward_by_sentence(num)
	bell.planned("( (move.backward_by_sentence)")
end

-- key: }
local function by_paragraph(num)
	bell.planned("} (move.by_paragraph)")
end

-- key: {
local function backward_by_paragraph(num)
	bell.planned("{ (move.backward_by_paragraph)")
end

-- key: ]]
local function by_section(num)
	bell.planned("]] (move.by_section)")
end

-- key: [[
local function backward_by_section(num)
	bell.planned("[[ (move.backward_by_section)")
end

--
-- Move in View
--

-- key: H
local function to_top_of_view()
	bell.planned("H (move.to_top_of_view)")
end

-- key: M
local function to_middle_of_view()
	bell.planned("M (move.to_middle_of_view)")
end

-- key: L
local function to_bottom_of_view()
	bell.planned("L (move.to_bottom_of_view)")
end

-- key: <num>H
local function to_below_top_of_view(num)
	bell.planned("<num>H (to_below_top_of_view)")
end

-- key: <num>L
local function to_above_bottom_of_view(num)
	bell.planned("<num>L (to_bottom_of_view)")
end

--
M.update_virtual_cursor = update_virtual_cursor

-- Move by Character / Move by line
M.left = left
M.down = down
M.up = up
M.right = right

-- Move in Line
M.to_start_of_line = to_start_of_line
M.to_end_of_line = to_end_of_line
M.to_non_blank_of_line = to_non_blank_of_line
M.to_column = to_column

-- Move by Word / Move by Loose Word
M.by_word = by_word
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
