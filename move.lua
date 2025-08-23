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
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

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
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

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
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

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
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

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
		bell.program_error("1 > num == " .. num)
		return
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
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

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
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

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

		local word, word_spaces, symbols = str:match("^([%w_\128-\255]*)(%s*)([^%w_\128-\255%s]*)")
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
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

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

			str = utils.utf8_sub(line, 1, cursor.X):reverse()
			spaces, symbols, word = str:match("^(%s*)([^%w_\128-\255%s]*)([%w_\128-\255]*)")
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
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

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
	local word, _, symbols = str:match("^([%w_\128-\255]*)(%s*)([^%w_\128-\255%s]*)")
	if #word == 1 or #symbols == 1 then
		one_word()
		line = buf:Line(cursor.Y)
		length = utf8.RuneCount(line)
	end

	for _ = 1, num do
		if cursor.X >= length - 1 and cursor.Y >= last_line_index then
			break
		end
		str = utils.utf8_sub(line, cursor.X + 1)

		word, _, symbols = str:match("^([%w_\128-\255]*)(%s*)([^%w_\128-\255%s]*)")
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
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

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

		local word, spaces = str:match("^([^%s]*)(%s*)")
		local forward
		if #word > 0 then
			forward = utf8.RuneCount(word .. spaces)
		else
			forward = utf8.RuneCount(spaces)
		end
		cursor.X = cursor.X + forward

		if cursor.X > length - 1 then
			while cursor.Y < last_line_index do
				cursor.Y = cursor.Y + 1

				line = buf:Line(cursor.Y)
				length = utf8.RuneCount(line)
				spaces = line:match("^(%s*)")
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
-- (none) : Move cursor forward by loose word to be used by cW command.
local function by_loose_word_for_change(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

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

		local word, spaces = str:match("^([^%s]*)(%s*)")
		local forward
		if #word > 0 then
			forward = utf8.RuneCount(word)
		else
			forward = utf8.RuneCount(spaces)
		end

		local end_of_line = cursor.X >= length
		cursor.X = cursor.X + forward

		if end_of_line then
			while cursor.Y < last_line_index do
				cursor.Y = cursor.Y + 1

				line = buf:Line(cursor.Y)
				length = utf8.RuneCount(line)
				spaces = line:match("^(%s*)")
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

-- B : Move cursor backward by loose word.
local function backward_by_loose_word(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

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

		local spaces, word = str:match("^(%s*)([^%s]*)")
		local backward
		if #word > 0 then
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

			str = utils.utf8_sub(line, 1, cursor.X):reverse()
			spaces, word = str:match("^(%s*)([^%s]*)")
			if #word > 0 then
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
-- (none) : Move cursor forward by one loose word.
local function one_loose_word()
	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	local last_line_index = utils.last_line_index(buf)

	local str = utils.utf8_sub(line, cursor.X + 1)

	local word, spaces = str:match("^([^%s]*)(%s*)")
	local forward
	if #word > 0 then
		forward = utf8.RuneCount(word .. spaces)
	else
		forward = utf8.RuneCount(spaces)
	end
	cursor.X = cursor.X + forward

	if cursor.X > length - 1 then
		while cursor.Y < last_line_index do
			cursor.Y = cursor.Y + 1

			line = buf:Line(cursor.Y)
			length = utf8.RuneCount(line)
			spaces = line:match("^(%s*)")
			cursor.X = utf8.RuneCount(spaces)

			if length > cursor.X then
				break
			end
		end
		cursor.X = math.min(cursor.X, length - 1)
	end
end

-- E : Move cursor to end of loose word.
local function to_end_of_loose_word(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

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
	local word = str:match("^([^%s]*)")
	if #word == 1 then
		one_loose_word()
		line = buf:Line(cursor.Y)
		length = utf8.RuneCount(line)
	end

	for _ = 1, num do
		if cursor.X >= length - 1 and cursor.Y >= last_line_index then
			break
		end
		str = utils.utf8_sub(line, cursor.X + 1)

		local spaces
		spaces, word = str:match("^(%s*)([^%s]*)")
		local forward = 0
		if #word > 0 then
			forward = utf8.RuneCount(spaces .. word) - 1
		elseif #spaces > 0 then
			forward = utf8.RuneCount(spaces)
		end
		cursor.X = cursor.X + forward

		if cursor.X > length - 1 then
			while cursor.Y < last_line_index do
				cursor.Y = cursor.Y + 1

				line = buf:Line(cursor.Y)
				length = utf8.RuneCount(line)
				spaces = line:match("^(%s*)")
				cursor.X = utf8.RuneCount(spaces)

				str = utils.utf8_sub(line, cursor.X + 1)
				word = str:match("^([^%s]*)")
				if #word == 1 then
					one_loose_word()
				end

				if length > cursor.X then
					break
				end
			end
			cursor.X = math.min(cursor.X, length - 1)
		end
	end

	update_virtual_cursor()
end

--
-- Move by Line
--

-- Enter, + :  Move cursor to first non-blank character of next line.
local function to_non_blank_of_next_line(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

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
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	--local last_line_index = utils.last_line_index(buf)

	local dest_y = cursor.Y - num
	if dest_y < 0 then
		bell.ring("cannot move up to line " .. dest_y + 1 .. " < " .. 1)
		return
	end
	cursor.Y = dest_y

	local line = buf:Line(cursor.Y)
	local spaces = line:match("^(%s*)")
	cursor.X = utf8.RuneCount(spaces)
	update_virtual_cursor()

	micro.CurPane():Relocate()
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
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

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
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)

	if cursor.X >= length - 1 and cursor.Y >= last_line_index then
		bell.ring("no more sentences ahead")
		return
	end

	line = utils.utf8_sub(line, cursor.X + 1)
	for _ = 1, num do
		local found = false

		while line:match("^%s*$") do
			if cursor.Y < last_line_index then
				cursor.Y = cursor.Y + 1
				line = buf:Line(cursor.Y)
				length = utf8.RuneCount(line)
				cursor.X = 0
				found = true
			else
				break
			end
		end

		if not found then
			while true do
				if line:match(".-[%.?!][\"')%]]*\t%s*") then
					break
				end
				if line:match(".-[%.?!][\"')%]]*%s%s+") then
					break
				end
				if line:match(".-[%.?!][\"')%]]*$") then
					break
				end

				if cursor.Y < last_line_index then
					cursor.Y = cursor.Y + 1
					line = buf:Line(cursor.Y)
					length = utf8.RuneCount(line)
					cursor.X = 0
				else
					cursor.X = length - 1
					break
				end

				if line:match("^%s*$") then
					break
				end
			end
		end

		if not found then
			local sentence, spaces = line:match("(.-[%.?!][\"')%]]*)(\t%s*)")
			if not sentence then
				sentence, spaces = line:match("(.-[%.?!][\"')%]]*)(%s%s+)")
			end
			if sentence then
				cursor.X = cursor.X + utf8.RuneCount(sentence .. spaces)
				line = line:sub(1 + #sentence + #spaces)
				found = true
				if cursor.X >= length then
					if cursor.Y < last_line_index then
						cursor.Y = cursor.Y + 1
						line = buf:Line(cursor.Y)
						length = utf8.RuneCount(line) -- luacheck: ignore
						cursor.X = 0
					else
						cursor.X = length - 1
					end
					break
				end
			end
		end

		if not found then
			local sentence = line:match("(.-[%.?!][\"')%]]*)$")
			if sentence then
				if cursor.Y < last_line_index then
					cursor.Y = cursor.Y + 1
					line = buf:Line(cursor.Y)
					length = utf8.RuneCount(line)
					cursor.X = 0
				else
					cursor.X = length - 1
				end
				found = true -- luacheck: ignore
			end
		end
	end

	update_virtual_cursor()
end

-- ( : Move cursor backward by sentence.
local function backward_by_sentence(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()

	local line = buf:Line(cursor.Y)
	for _ = 1, num do
		local found = false

		if buf:Line(cursor.Y):match("[^%s]") and cursor.X < 1 then
			if cursor.Y > 0 then
				cursor.Y = cursor.Y - 1
				line = buf:Line(cursor.Y)
				local length = utf8.RuneCount(line)
				cursor.X = math.max(length - 1, 0)
				found = true
			end
		else
			while line:match("^%s*$") do
				if cursor.Y > 0 then
					cursor.Y = cursor.Y - 1
					line = buf:Line(cursor.Y)
					local length = utf8.RuneCount(line)
					cursor.X = math.max(length - 1, 0)
					found = true
				else
					break
				end
			end
		end

		if not found then
			while true do
				if line:match(".-[%.?!][\"')%]]*%s+") then
					break
				end
				if line:match(".-[%.?!][\"')%]]*$") then
					break
				end

				if cursor.X < 1 and cursor.Y > 0 then
					cursor.Y = cursor.Y - 1
					line = buf:Line(cursor.Y)
					local length = utf8.RuneCount(line)
					cursor.X = math.max(length - 1, 0)
				else
					cursor.X = 0
					break
				end
			end
		end

		cursor.X = math.max(cursor.X - 1, 0)
		line = utils.utf8_sub(line, 1, cursor.X + 1)
		while line:match("[%.?!%s]$") do
			cursor.X = math.max(cursor.X - 1, 0)
			line = utils.utf8_sub(line, 1, cursor.X + 1)
		end
		local sentence = line:reverse():match("^(.-[^%s])%s+[\"')%]]*[%.?!]")
		if sentence and #sentence > 0 then
			cursor.X = cursor.X - utf8.RuneCount(sentence:reverse()) + 1
		else
			cursor.X = 0
		end
		line = utils.utf8_sub(line, 1, cursor.X + 1)
	end

	update_virtual_cursor()
end

-- } : Move cursor forward by paragraph.
local function by_paragraph(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)

	if cursor.Y >= last_line_index then
		local line = buf:Line(cursor.Y)
		local length = utf8.RuneCount(line)
		if cursor.X >= length - 1 then
			bell.ring("no more paragraphs ahead")
			return
		end
		cursor.X = math.max(length - 1, 0)
	else
		for _ = 1, num do
			while cursor.Y < last_line_index and buf:Line(cursor.Y):match("^%s*$") do
				cursor.Y = cursor.Y + 1
			end
			while cursor.Y < last_line_index and buf:Line(cursor.Y):match("[^%s]") do
				cursor.Y = cursor.Y + 1
			end
		end
		cursor.X = 0
	end

	update_virtual_cursor()
end

-- { : Move cursor backward by paragraph.
local function backward_by_paragraph(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()

	for _ = 1, num do
		while cursor.Y > 0 and buf:Line(cursor.Y):match("^%s*$") do
			cursor.Y = cursor.Y - 1
		end
		while cursor.Y > 0 and buf:Line(cursor.Y):match("[^%s]") do
			cursor.Y = cursor.Y - 1
		end
	end
	cursor.X = 0

	update_virtual_cursor()
end

-- ]] : Move cursor forward by section.
local function by_section(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)
	if cursor.Y >= last_line_index then
		bell.ring("no more sections ahead")
		return
	end

	for _ = 1, num do
		if cursor.Y >= last_line_index then
			local line = buf:Line(cursor.Y)
			local length = utf8.RuneCount(line)
			cursor.X = math.max(length - 1, 0)
			break
		else
			while cursor.Y < last_line_index do
				cursor.Y = cursor.Y + 1
				local line = buf:Line(cursor.Y)
				cursor.X = 0
				if line:match("^{") then
					break
				end
			end
		end
	end

	update_virtual_cursor()
end

-- [[ : Move cursor backward by section.
local function backward_by_section(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	if cursor.Y < 1 then
		bell.ring("no more sections behind")
		return
	end

	for _ = 1, num do
		if cursor.Y < 1 then
			cursor.X = 0
			break
		else
			while cursor.Y > 0 do
				cursor.Y = cursor.Y - 1
				local line = buf:Line(cursor.Y)
				cursor.X = 0
				if line:match("^{") then
					break
				end
			end
		end
	end

	update_virtual_cursor()
end

--
-- Move in View
--

-- H : Move cursor to top of view.
local function to_top_of_view()
	mode.show()

	local pane = micro.CurPane()
	local v = pane:GetView()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	cursor.Y = v.StartLine.Line
	local line = buf:Line(cursor.Y)
	local spaces = line:match("^(%s*)")
	cursor.X = utf8.RuneCount(spaces)
end

-- M : Move cursor to middle of view.
local function to_middle_of_view()
	mode.show()

	local pane = micro.CurPane()
	local v = pane:GetView()
	local bf = pane:BufView()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)
	local height = math.min(bf.Height, last_line_index - v.StartLine.Line + 1)
	local offset = math.floor(height / 2)
	cursor.Y = v.StartLine.Line + offset
	local line = buf:Line(cursor.Y)
	local spaces = line:match("^(%s*)")
	cursor.X = utf8.RuneCount(spaces)
end

-- L : Move cursor to bottom of view.
local function to_bottom_of_view()
	mode.show()

	local pane = micro.CurPane()
	local v = pane:GetView()
	local bf = pane:BufView()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)
	local height = math.min(bf.Height, last_line_index - v.StartLine.Line + 1)
	local offset = height - 1
	cursor.Y = v.StartLine.Line + offset
	local line = buf:Line(cursor.Y)
	local spaces = line:match("^(%s*)")
	cursor.X = utf8.RuneCount(spaces)
end

-- <num>H : Move cursor below <num> lines from top of view.
local function to_below_top_of_view(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	local pane = micro.CurPane()
	local bf = pane:BufView()
	local buf = pane.Buf
	local last_line_index = utils.last_line_index(buf)
	local v = pane:GetView()
	local height = math.min(bf.Height, last_line_index - v.StartLine.Line + 1)
	if num > height then
		bell.ring("offset out of range: " .. num .. " > " .. height)
		return
	end

	mode.show()

	local cursor = buf:GetActiveCursor()
	local offset = num - 1
	cursor.Y = v.StartLine.Line + offset
	local line = buf:Line(cursor.Y)
	local spaces = line:match("^(%s*)")
	cursor.X = utf8.RuneCount(spaces)
end

-- <num>L : Move cursor above <num> lines from bottom of view.
local function to_above_bottom_of_view(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	local pane = micro.CurPane()
	local bf = pane:BufView()
	local buf = pane.Buf
	local last_line_index = utils.last_line_index(buf)
	local v = pane:GetView()
	local height = math.min(bf.Height, last_line_index - v.StartLine.Line + 1)
	if num > height then
		bell.ring("offset out of range: " .. num .. " > " .. height)
		return
	end

	mode.show()

	local cursor = buf:GetActiveCursor()
	local offset = height - num
	cursor.Y = math.min(v.StartLine.Line + offset, last_line_index)
	local line = buf:Line(cursor.Y)
	local spaces = line:match("^(%s*)")
	cursor.X = utf8.RuneCount(spaces)
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
M.by_loose_word_for_change = by_loose_word_for_change
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
