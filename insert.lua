-- Insertion Commands

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
local snapshot = require("vi/snapshot")
local move = require("vi/move")

local saved = false
local saved_num = 1
local saved_replay = false

local saved_loc = nil
local saved_size = nil
local inserted_lines = {}

local CHARS_MODE = 1
local LINES_MODE = 2
local REPLACE_MODE = 3
local insert_mode = CHARS_MODE

--
local function size_with_linefeeds()
	local buf = micro.CurPane().Buf
	local linesnum = buf:LinesNum()
	local size = 0
	for i = 0, linesnum - 1 do
		local line = buf:Line(i)
		size = size + #line + 1
	end
	return size
end

--
local function save_state(num, replay)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	saved = true
	saved_num = num
	saved_replay = replay

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	if insert_mode == REPLACE_MODE then
		saved_loc = buffer.Loc(cursor.X + 1, cursor.Y)
	else
		saved_loc = buffer.Loc(cursor.X, cursor.Y)
	end
	saved_size = size_with_linefeeds()
end

--
local function extend(loc, num, replay)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	local n
	if replay then
		n = num
	else
		n = num - 1
	end
	local lines = {}

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local x = cursor.X
	local y = cursor.Y

	for _ = 1, n do
		for i = 1, #inserted_lines do
			table.insert(lines, inserted_lines[i])
			local length = utf8.RuneCount(inserted_lines[i])
			if i == 1 and insert_mode == CHARS_MODE or insert_mode == REPLACE_MODE then
				x = math.max(x + length - 1, 0)
			else
				x = math.max(length - 1, 0)
			end
			y = y + 1
		end
	end

	if replay and (insert_mode == CHARS_MODE or insert_mode == REPLACE_MODE) and #inserted_lines > 0 then
		y = y - 1
	end

	if replay then
		mode.insert()
	end

	if insert_mode == CHARS_MODE or insert_mode == REPLACE_MODE then
		buf:Insert(loc, table.concat(lines, "\n"))
	elseif insert_mode == LINES_MODE then
		buf:Insert(loc, table.concat(lines, "\n") .. "\n")
	else
		bell.program_error("invalid insert_mode == " .. insert_mode)
		return
	end

	if replay then
		mode.command()
	end

	cursor.X = x
	cursor.Y = y
	move.update_virtual_cursor()
end

--
local function resume(orig_loc)
	if saved_loc then
		local size = size_with_linefeeds()
		if size > saved_size then
			inserted_lines = {}
			local buf = micro.CurPane().Buf
			local x = saved_loc.X
			local y = saved_loc.Y
			local run = saved_size
			if insert_mode == CHARS_MODE or insert_mode == REPLACE_MODE then
				run = run - 1
				size = size - 1
			end
			while run < size do
				local line = buf:Line(y)
				local length = #line
				if run + length - x > size then
					x = size - run
					if y == saved_loc.Y then
						if insert_mode == REPLACE_MODE then
							table.insert(inserted_lines, line:sub(saved_loc.X, saved_loc.X + x - 1))
						else
							table.insert(inserted_lines, line:sub(saved_loc.X + 1, saved_loc.X + x))
						end
					else
						table.insert(inserted_lines, line:sub(1, x))
					end
					break
				end
				local subline = line:sub(x + 1)
				table.insert(inserted_lines, subline)
				run = run + #subline + 1
				x = 0
				y = y + 1
			end
		end
		saved_loc = nil
		saved_size = nil
	end

	if saved then
		extend(orig_loc, saved_num, saved_replay)

		saved = false
		saved_num = 1
		saved_replay = false
	end
end

--
local function chars_mode()
	insert_mode = CHARS_MODE
end

--
local function lines_mode()
	insert_mode = LINES_MODE
end

--
local function replace_mode()
	insert_mode = REPLACE_MODE
end

--
-- Enter Insert Mode
--

-- i : Switch to insert mode before cursor.
local function before(num, replay)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	snapshot.update()

	chars_mode()

	if replay then
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		local loc = buffer.Loc(cursor.X, cursor.Y)
		extend(loc, num, replay)
	else
		mode.insert()
		mode.show()

		save_state(num, replay)
	end
end

-- a : Switch to insert mode after cursor.
local function after(num, replay)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	snapshot.update()

	chars_mode()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	cursor.X = math.min(cursor.X + 1, math.max(length, 0))

	if replay then
		local loc = buffer.Loc(cursor.X, cursor.Y)
		extend(loc, num, replay)
	else
		mode.insert()
		mode.show()

		save_state(num, replay)
	end
end

-- I : Switch to insert mode before first non-blank character of current line.
local function before_non_blank(num, replay)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	snapshot.update()

	chars_mode()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local spaces = line:match("^(%s*)")
	cursor.X = utf8.RuneCount(spaces)

	if replay then
		local loc = buffer.Loc(cursor.X, cursor.Y)
		extend(loc, num, replay)
	else
		mode.insert()
		mode.show()

		save_state(num, replay)
	end
end

-- A : Switch to insert mode after end of current line.
local function after_end(num, replay)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	snapshot.update()

	chars_mode()

	move.to_end()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	cursor.X = math.min(cursor.X + 1, math.max(length, 0))

	if replay then
		local loc = buffer.Loc(cursor.X, cursor.Y)
		extend(loc, num, replay)
	else
		mode.insert()
		mode.show()

		save_state(num, replay)
	end
end

-- R : Switch to replace (overwrite) mode.
local function overwrite(num, replay)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	bell.not_planned("R (insert.overwrite)")
end

--
-- Open Line
--

-- o : Open a new line below and switch to insert mode.
local function open_below(num, replay)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	lines_mode()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	if replay then
		local linesnum = buf:LinesNum()
		local loc = buffer.Loc(0, math.min(cursor.Y + 1, linesnum - 1))
		extend(loc, num, replay)
	else
		mode.insert()
		mode.show()

		local line = buf:Line(cursor.Y)
		cursor.X = utf8.RuneCount(line)
		if cursor.Y >= buf:LinesNum() - 1 and #line > 0 then
			buf:Insert(buffer.Loc(cursor.X, cursor.Y), "\n\n")
		else
			buf:Insert(buffer.Loc(cursor.X, cursor.Y), "\n")
		end

		utils.next_tick(function()
			cursor.Y = math.max(cursor.Y - 1, 0)
			cursor.X = 0
			move.update_virtual_cursor()

			save_state(num, replay)
		end)
	end
end

-- O : Open a new line **above** and switch to insert mode.
local function open_above(num, replay)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	lines_mode()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	if replay then
		local loc = buffer.Loc(0, cursor.Y)
		extend(loc, num, replay)
	else
		mode.insert()
		mode.show()

		cursor.X = 0
		buf:Insert(buffer.Loc(cursor.X, cursor.Y), "\n")

		utils.next_tick(function()
			cursor.Y = math.max(cursor.Y - 2, 0)
			cursor.X = 0
			move.update_virtual_cursor()

			save_state(num, replay)
		end)
	end
end

-- internal use
-- (none) : Open a new line here and switch to insert mode.
local function open_here(num, replay)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	snapshot.update()

	lines_mode()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	if replay then
		local loc = buffer.Loc(0, cursor.Y)
		extend(loc, num, replay)
	else
		mode.insert()
		mode.show()

		cursor.X = 0
		buf:Insert(buffer.Loc(cursor.X, cursor.Y), "\n")

		utils.next_tick(function()
			cursor.Y = math.max(cursor.Y - 1, 0)
			cursor.X = 0
			move.update_virtual_cursor()

			save_state(num, replay)
		end)
	end
end

-- internal use
-- (none) : Switch to insert mode before cursor to be used by change commands.
local function before_replace(num, replay)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	replace_mode()

	if replay then
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		local loc = buffer.Loc(cursor.X, cursor.Y)
		extend(loc, num, replay)
	else
		mode.insert()
		mode.show()

		save_state(num, replay)
	end
end

-------------
-- Exports --
-------------

local M = {}

-- internal use
M.resume = resume
M.extend = extend
M.chars_mode = chars_mode
M.lines_mode = lines_mode
M.replace_mode = replace_mode

-- Enter Insert Mode
M.before = before
M.before_non_blank = before_non_blank
M.after = after
M.after_end = after_end
M.overwrite = overwrite
M.open_below = open_below
-- Open Line
M.open_above = open_above
M.open_here = open_here

-- internal use
M.before_replace = before_replace

return M
