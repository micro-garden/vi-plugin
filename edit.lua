M = {}

local micro = import("micro")
local buffer = import("micro/buffer")
local utf8 = import("unicode/utf8")
local time = import("time")

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local editor = require("editor")
local mode = require("mode")
local motion = require("motion")
local utils = require("utils")

local kill_buffer = nil
local kill_lines = nil

local function clear_kill_buffer()
	kill_buffer = {}
end

local function insert_killed_lines(lines)
	table.insert(kill_buffer, lines)
	kill_lines = true
end

local function insert_killed_chars(chars)
	table.insert(kill_buffer, chars)
	kill_lines = false
end

-- command: dd
local function delete_lines(number)
	mode.show()

	local pane = micro.CurPane()
	local buf = pane.buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)
	if cursor.Y + number - 1 > last_line_index then
		editor.bell("there are not " .. number .. " lines below, only " .. last_line_index - cursor.Y + 1)
		return
	end

	clear_kill_buffer()
	cursor.X = 0
	for i = 1, number do
		local line = buf:Line(cursor.Y)
		insert_killed_lines(line)
		pane:DeleteLine()
		last_line_index = utils.last_line_index(buf)
		cursor.Y = math.min(cursor.Y, last_line_index)
	end

	utils.after(editor.TICK_DURATION, function()
		local line = buf:Line(cursor.Y)
		local spaces = line:match("^(%s*)")
		cursor.X = utf8.RuneCount(spaces)
		motion.update_virtual_cursor()
	end)
end

-- command: yy Y
local function copy_lines(number)
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)
	if cursor.Y + number - 1 > last_line_index then
		editor.bell("there are not " .. number .. " lines below, only " .. last_line_index - cursor.Y + 1)
		return
	end

	clear_kill_buffer()
	for i = 1, number do
		local line = buf:Line(cursor.Y + i - 1)
		insert_killed_lines(line)
	end
end

-- command: x
local function delete_chars(number)
	mode.show()

	local pane = micro.CurPane()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	if length < 1 then
		editor.bell("no character in the line")
		return
	end

	local n = math.min(number, length - cursor.X)

	clear_kill_buffer()
	insert_killed_chars(utils.utf8_sub(line, cursor.X + 1, cursor.X + n))

	local saved_x = cursor.X

	for _ = 1, n do
		pane:Delete()
	end

	utils.after(editor.TICK_DURATION, function()
		line = buf:Line(cursor.Y)
		length = utf8.RuneCount(line)
		cursor.X = math.min(saved_x, math.max(length - 1, 0))
		motion.update_virtual_cursor()
	end)
end

-- command: X
local function delete_chars_backward(number)
	mode.show()

	local pane = micro.CurPane()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	if length < 1 then
		editor.bell("no character in the line")
		return
	end

	local n = math.min(number, cursor.X)

	clear_kill_buffer()
	insert_killed_chars(utils.utf8_sub(line, cursor.X - n + 1, cursor.X))

	local saved_x = cursor.X

	cursor.X = cursor.X - n
	for _ = 1, n do
		pane:Delete()
	end

	utils.after(editor.TICK_DURATION, function()
		line = buf:Line(cursor.Y)
		length = utf8.RuneCount(line)
		cursor.X = math.min(math.max(saved_x - n, 0), math.max(length - 1, 0))
		motion.update_virtual_cursor()
	end)
end

-- command: p
local function paste_below(number)
	mode.show()

	if not kill_buffer then
		editor.vi_error("kill buffer is empty yet")
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
	for _ = 1, number do
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

	utils.after(editor.TICK_DURATION, function()
		if kill_lines then
			cursor.Y = saved_y + 1

			line = buf:Line(cursor.Y)
			local spaces = line:match("^(%s*)")
			cursor.X = utf8.RuneCount(spaces)
			motion.update_virtual_cursor()
		else -- kill chars
			if saved_length < 1 then
				cursor.X = saved_x
			else
				cursor.X = saved_x + 1
			end
		end
		motion.update_virtual_cursor()

		mode.command()
	end)
end

-- command: P
local function paste_above(number)
	mode.show()

	if not kill_buffer then
		editor.vi_error("kill buffer is empty yet")
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
	for _ = 1, number do
		saved_y = cursor.Y
		if kill_lines then
			cursor.X = 0
		end
		buf:Insert(buffer.Loc(cursor.X, cursor.Y), text)
		if kill_lines then
			cursor.Y = saved_y
		end
	end

	utils.after(editor.TICK_DURATION, function()
		if kill_lines then
			cursor.Y = saved_y

			local line = buf:Line(cursor.Y)
			local spaces = line:match("^(%s*)")
			cursor.X = utf8.RuneCount(spaces)
		else -- kill chars
			cursor.X = saved_x
		end
		motion.update_virtual_cursor()

		mode.command()
	end)
end

-- command: d
local function delete_lines_region(start_y, end_y)
	if end_y < start_y then
		start_y, end_y = end_y, start_y -- swap
	end

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.X = 0
	cursor.Y = start_y
	delete_lines(end_y - start_y + 1)
end

-- command: y
local function copy_lines_region(start_y, end_y)
	if end_y < start_y then
		start_y, end_y = end_y, start_y -- swap
	end

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor.X = 0
	cursor.Y = start_y
	copy_lines(end_y - start_y + 1)
end

local function is_ordered(start_loc, end_loc)
	if start_loc.Y < end_loc.Y then
		return true
	elseif start_loc.Y > end_loc.Y then
		return false
	else -- start_loc.Y == end_loc.Y
		return start_loc.X <= end_loc.X
	end
end

-- command: d
local function delete_chars_region(start_loc, end_loc)
	mode.show()

	if not is_ordered(start_loc, end_loc) then
		start_loc, end_loc = end_loc, start_loc -- swap
	end

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local substr = buf:Substr(start_loc, end_loc)
	clear_kill_buffer()
	insert_killed_chars(substr)
	buf:Remove(start_loc, end_loc)

	utils.after(editor.TICK_DURATION, function()
		local line = buf:Line(cursor.Y)
		local length = utf8.RuneCount(line)
		cursor.X = math.min(cursor.X, math.max(length - 1, 0))
		motion.update_virtual_cursor()
	end)
end

-- command: y
local function copy_chars_region(start_loc, end_loc)
	mode.show()

	if not is_ordered(start_loc, end_loc) then
		start_loc, end_loc = end_loc, start_loc -- swap
	end

	local buf = micro.CurPane().Buf
	local substr = buf:Substr(start_loc, end_loc)
	clear_kill_buffer()
	insert_killed_chars(substr)
end

-- command: d$ D
local function delete_to_line_end()
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	if length < 1 then
		editor.bell("no characters in this line")
		return
	end

	clear_kill_buffer()
	insert_killed_chars(line:sub(1 + cursor.X))

	local start_loc = buffer.Loc(cursor.X, cursor.Y)
	local end_loc = buffer.Loc(length, cursor.Y)
	buf:Remove(start_loc, end_loc)

	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	cursor.X = math.min(cursor.X, math.max(length - 1, 0))
	motion.update_virtual_cursor()
end

-- command: y$
local function copy_to_line_end()
	mode.show()

	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	if length < 1 then
		editor.bell("no characters in this line")
		return
	end

	clear_kill_buffer()
	insert_killed_chars(line:sub(1 + cursor.X))
end

-- command: J
local function join_lines(number)
	mode.show()

	local pane = micro.CurPane()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local last_line_index = utils.last_line_index(buf)
	if cursor.Y >= last_line_index then
		editor.vi_error("no lines to join below")
		return
	end

	local n = number
	if n > 1 then
		n = n - 1
	end

	for _ = 1, n do
		if cursor.Y >= last_line_index then
			break
		end

		local line = buf:Line(cursor.Y)
		local length = utf8.RuneCount(line)
		cursor.X = length
		local next_line = buf:Line(cursor.Y + 1)
		local loc = buffer.Loc(cursor.X, cursor.Y)
		local spaces, body = next_line:match("^(%s*)(.*)$")
		if #body > 0 then
			buf:Insert(loc, " " .. body)
		end
		cursor.Y = cursor.Y + 1
		pane:DeleteLine()
		cursor.Y = cursor.Y - 1

		utils.after(editor.TICK_DURATION, function()
			cursor.Y = loc.Y
			line = buf:Line(cursor.Y)
			if length < 1 or #next_line < 1 then
				local current_length = utf8.RuneCount(line)
				cursor.X = math.max(current_length - 1, 0)
			else
				cursor.X = loc.X
			end
			motion.update_virtual_cursor()
		end)
	end
end

M.clear_kill_buffer = clear_kill_buffer
--M.insert_killed_lines = insert_killed_lines
M.insert_killed_chars = insert_killed_chars

M.delete_lines = delete_lines
M.copy_lines = copy_lines
M.delete_chars = delete_chars
M.delete_chars_backward = delete_chars_backward
M.paste_below = paste_below
M.paste_above = paste_above

M.delete_lines_region = delete_lines_region
M.copy_lines_region = copy_lines_region
M.delete_chars_region = delete_chars_region
M.copy_chars_region = copy_chars_region
M.delete_to_line_end = delete_to_line_end
M.copy_to_line_end = copy_to_line_end

M.join_lines = join_lines

return M
