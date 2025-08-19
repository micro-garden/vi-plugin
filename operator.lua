-- Operator Commands

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
local move = require("vi/move")
local insert = require("vi/insert")

local kill_buffer = nil
local kill_lines = nil

--
local function clear_kill_buffer()
	kill_buffer = {}
end

--
local function insert_killed_lines(lines)
	table.insert(kill_buffer, lines)
	kill_lines = true
end

--
local function insert_killed_chars(chars)
	table.insert(kill_buffer, chars)
	kill_lines = false
end

--
-- Copy (Yank)
--

-- yy Y : Copy current line.
local function copy_line(num)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)
	if cursor.Y + num - 1 > last_line_index then
		bell.ring("cannot copy" .. num .. " lines, only " .. last_line_index - cursor.Y + 1 .. " below")
		return
	end

	clear_kill_buffer()
	for i = 1, num do
		local line = buf:Line(cursor.Y + i - 1)
		insert_killed_lines(line)
	end
end

-- y<mv> : Copy region from current cursor to destination of motion <mv>.
local function copy_region(start_loc, end_loc)
	mode.show()

	if not utils.is_locs_ordered(start_loc, end_loc) then
		start_loc, end_loc = end_loc, start_loc -- swap
	end

	local buf = micro.CurPane().Buf
	local substr = buf:Substr(start_loc, end_loc)
	clear_kill_buffer()
	insert_killed_chars(substr)
end

-- key: y<mv> : Copy line region from current cursor to destination of motion <mv>.
local function copy_line_region(start_y, end_y)
	if end_y < start_y then
		start_y, end_y = end_y, start_y -- swap
	end

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.X = 0
	cursor.Y = start_y
	copy_line(end_y - start_y + 1)
end

-- yw : Copy word.
local function copy_word(num)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local start_loc = buffer.Loc(cursor.X, cursor.Y)
	move.by_word(num)
	local end_loc = buffer.Loc(cursor.X, cursor.Y)
	cursor.X = start_loc.X
	cursor.Y = start_loc.Y
	copy_region(start_loc, end_loc)
end

-- y$ : Copy to end of current line.
local function copy_to_end()
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	if length < 1 then
		bell.ring("nothing to copy, line is empty")
		return
	end

	clear_kill_buffer()
	insert_killed_chars(line:sub(1 + cursor.X))
end

-- "<reg>yy : Copy current line into register <reg>.
local function copy_line_into_reg(reg, num)
	bell.planned('"<reg>yy (operator.copy_line_into_reg)')
end

--
-- Paste (Put)
--

-- p : Paste after cursor.
local function paste(num)
	mode.show()

	if not kill_buffer then
		bell.vi_info("nothing to paste yet")
		return
	end

	local text
	if kill_lines then
		text = "\n" .. table.concat(kill_buffer, "\n")
	else -- kill chars
		text = table.concat(kill_buffer)
	end

	mode.insert()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local saved_length = utf8.RuneCount(line)
	local saved_x = cursor.X
	local saved_y
	for _ = 1, num do
		saved_y = cursor.Y
		if kill_lines then
			line = buf:Line(cursor.Y)
			cursor.X = utf8.RuneCount(line)
		else -- kill chars
			line = buf:Line(cursor.Y)
			local length = utf8.RuneCount(line)
			cursor.X = math.min(saved_x + 1, math.max(length, 0))
		end
		buf:Insert(buffer.Loc(cursor.X, cursor.Y), text)
		if kill_lines then
			cursor.Y = saved_y + 1
		end
	end

	utils.next_tick(function()
		if kill_lines then
			cursor.Y = saved_y + 1

			line = buf:Line(cursor.Y)
			local spaces = line:match("^(%s*)")
			cursor.X = utf8.RuneCount(spaces)
			move.update_virtual_cursor()
		else -- kill chars
			if saved_length < 1 then
				cursor.X = saved_x
			else
				cursor.X = saved_x + 1
			end
		end
		move.update_virtual_cursor()

		mode.command()
	end)
end

-- P : Paste before cursor.
local function paste_before(num)
	mode.show()

	if not kill_buffer then
		bell.vi_info("nothing to paste yet")
		return
	end

	local text
	if kill_lines then
		text = table.concat(kill_buffer, "\n") .. "\n"
	else -- kill chars
		text = table.concat(kill_buffer)
	end

	mode.insert()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local saved_x = cursor.X
	local saved_y
	for _ = 1, num do
		saved_y = cursor.Y
		if kill_lines then
			cursor.X = 0
		end
		buf:Insert(buffer.Loc(cursor.X, cursor.Y), text)
		if kill_lines then
			cursor.Y = saved_y
		end
	end

	utils.next_tick(function()
		if kill_lines then
			cursor.Y = saved_y

			local line = buf:Line(cursor.Y)
			local spaces = line:match("^(%s*)")
			cursor.X = utf8.RuneCount(spaces)
		else -- kill chars
			cursor.X = saved_x
		end
		move.update_virtual_cursor()

		mode.command()
	end)
end

-- "<reg>p : Paste from register <reg>.
local function paste_from_reg(reg, num)
	bell.planned('"<reg>p (operator.paste_from_reg)')
end

--
-- Delete
--

-- x : Delete character under cursor.
local function delete(num)
	mode.show()

	local pane = micro.CurPane()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	if length < 1 then
		bell.ring("nothing to delete, line is empty")
		return
	end

	local n = math.min(num, length - cursor.X)

	clear_kill_buffer()
	insert_killed_chars(utils.utf8_sub(line, cursor.X + 1, cursor.X + n))

	local saved_x = cursor.X

	for _ = 1, n do
		pane:Delete()
	end

	utils.next_tick(function()
		line = buf:Line(cursor.Y)
		length = utf8.RuneCount(line)
		cursor.X = math.min(saved_x, math.max(length - 1, 0))
		move.update_virtual_cursor()
	end)
end

-- X : Delete character before cursor.
local function delete_before(num)
	mode.show()

	local pane = micro.CurPane()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	if length < 1 then
		bell.ring("nothing to delete, line is empty")
		return
	end

	local n = math.min(num, cursor.X)

	clear_kill_buffer()
	insert_killed_chars(utils.utf8_sub(line, cursor.X - n + 1, cursor.X))

	local saved_x = cursor.X

	cursor.X = cursor.X - n
	for _ = 1, n do
		pane:Delete()
	end

	utils.next_tick(function()
		line = buf:Line(cursor.Y)
		length = utf8.RuneCount(line)
		cursor.X = math.min(math.max(saved_x - n, 0), math.max(length - 1, 0))
		move.update_virtual_cursor()
	end)
end

-- dd : Delete current line.
local function delete_line(num)
	mode.show()

	local pane = micro.CurPane()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)
	if cursor.Y + num - 1 > last_line_index then
		bell.ring("cannot delete " .. num .. " lines, only " .. last_line_index - cursor.Y + 1 .. " below")
		return
	end

	clear_kill_buffer()
	cursor.X = 0
	for _ = 1, num do
		local line = buf:Line(cursor.Y)
		insert_killed_lines(line)
		pane:DeleteLine()
		last_line_index = utils.last_line_index(buf)
		cursor.Y = math.min(cursor.Y, last_line_index)
	end

	utils.next_tick(function()
		local line = buf:Line(cursor.Y)
		local spaces = line:match("^(%s*)")
		cursor.X = utf8.RuneCount(spaces)
		move.update_virtual_cursor()
	end)
end

-- d<mv> : Delete region from current cursor to destination of motion <mv>.
local function delete_region(start_loc, end_loc)
	mode.show()

	if not utils.is_locs_ordered(start_loc, end_loc) then
		start_loc, end_loc = end_loc, start_loc -- swap
	end

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local substr = buf:Substr(start_loc, end_loc)
	clear_kill_buffer()
	insert_killed_chars(substr)
	buf:Remove(start_loc, end_loc)

	utils.next_tick(function()
		local line = buf:Line(cursor.Y)
		local length = utf8.RuneCount(line)
		cursor.X = math.min(cursor.X, math.max(length - 1, 0))
		move.update_virtual_cursor()
	end)
end

-- d<mv> : Delete line region from current cursor to destination of motion <mv>.
local function delete_line_region(start_y, end_y)
	if end_y < start_y then
		start_y, end_y = end_y, start_y -- swap
	end

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.X = 0
	cursor.Y = start_y
	delete_line(end_y - start_y + 1)
end

-- dw : Delete word.
local function delete_word(num)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local loc_start = buffer.Loc(cursor.X, cursor.Y)
	move.by_word(num)
	local loc_end = buffer.Loc(cursor.X, cursor.Y)
	cursor.X = loc_start.X
	cursor.Y = loc_start.Y
	delete_region(loc_start, loc_end)
end

-- d$ D - Delete to end of current line.
local function delete_to_end()
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	if length < 1 then
		bell.ring("nothing to delete, line is empty")
		return
	end

	clear_kill_buffer()
	insert_killed_chars(line:sub(1 + cursor.X))

	local start_loc = buffer.Loc(cursor.X, cursor.Y)
	local end_loc = buffer.Loc(length, cursor.Y)
	buf:Remove(start_loc, end_loc)

	line = buf:Line(cursor.Y)
	length = utf8.RuneCount(line)
	cursor.X = math.min(cursor.X, math.max(length - 1, 0))
	move.update_virtual_cursor()
end

--
-- Change / Substitute
--

-- cc : Change current line.
local function change_line(num, replay)
	delete_line(num)
	insert.open_here(1, replay)
end

-- c<mv> : Change region from current cursor to destination of motion <mv>.
local function change_region(start_loc, end_loc, replay)
	if not utils.is_locs_ordered(start_loc, end_loc) then
		start_loc, end_loc = end_loc, start_loc -- swap
	end

	local buf = micro.CurPane().Buf
	local line = buf:Line(end_loc.Y)
	local length = utf8.RuneCount(line)
	local end_of_line = end_loc.Y >= length

	delete_region(start_loc, end_loc)

	utils.next_tick(function()
		local cursor = buf:GetActiveCursor()
		cursor.X = start_loc.X
		cursor.Y = start_loc.Y
		if end_of_line then
			insert.after(1, replay)
		else
			insert.before(1, replay)
		end
	end, 2)
end

-- c<mv> : Change line region from current cursor to destination of motion <mv>.
local function change_line_region(start_y, end_y, replay)
	delete_line_region(start_y, end_y)
	insert.open_here(1, replay)
end

-- cw : Change word.
local function change_word(num, replay)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local loc_start = buffer.Loc(cursor.X, cursor.Y)
	move.by_word_for_change(num)
	local loc_end = buffer.Loc(cursor.X, cursor.Y)
	cursor.X = loc_start.X
	cursor.Y = loc_start.Y
	change_region(loc_start, loc_end, replay)
end

-- C : Change to end of current line.
local function change_to_end(replay)
	delete_to_end()
	insert.after(1, replay)
end

-- s : Substitute one character under cursor.
local function subst(num, replay)
	insert.replace_mode()

	local pane = micro.CurPane()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)

	local n = math.min(num, length - cursor.X)

	clear_kill_buffer()
	insert_killed_chars(utils.utf8_sub(line, 1 + cursor.X, cursor.X + n))

	local saved_x = cursor.X
	local insert_after = cursor.X + num >= length

	for _ = 1, n do
		pane:Delete()
	end

	if replay then
		local loc = buffer.Loc(cursor.X, cursor.Y)
		insert.extend(loc, 1, replay)
	else
		mode.show()

		line = buf:Line(cursor.Y)
		length = utf8.RuneCount(line)
		cursor.X = math.min(cursor.X + 1, length - 1)

		utils.next_tick(function()
			line = buf:Line(cursor.Y)
			length = utf8.RuneCount(line)
			if insert_after then
				cursor.X = math.min(saved_x, math.max(length, 0))
			else
				cursor.X = math.min(saved_x, math.max(length - 1, 0))
			end
			move.update_virtual_cursor()

			insert.before_replace(1, replay)
		end)
	end
end

-- S : Substtute current line (equals cc).
local function subst_line(num, replay)
	change_line(num, replay)
end

-------------
-- Exports --
-------------

local M = {}

-- internal use
M.clear_kill_buffer = clear_kill_buffer
--M.insert_killed_lines = insert_killed_lines
M.insert_killed_chars = insert_killed_chars

-- Copy (Yank)
M.copy_word = copy_word
M.copy_line = copy_line
M.copy_line_into_reg = copy_line_into_reg
M.copy_region = copy_region
M.copy_line_region = copy_line_region
M.copy_to_end = copy_to_end

-- Paste (Put)
M.paste = paste
M.paste_before = paste_before
M.paste_from_rag = paste_from_reg

-- Delete
M.delete = delete
M.delete_before = delete_before
M.delete_word = delete_word
M.delete_line = delete_line
M.delete_region = delete_region
M.delete_line_region = delete_line_region
M.delete_to_end = delete_to_end

-- Change / Substitute
M.change_word = change_word
M.change_line = change_line
M.change_region = change_region
M.change_line_region = change_line_region
M.change_to_end = change_to_end
M.subst = subst
M.subst_line = subst_line

return M
