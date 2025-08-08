M = {}

local micro = import("micro")
local buffer = import("micro/buffer")
local utf8 = import("unicode/utf8")
local time = import("time")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/vi/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local editor = require("editor")
local mode = require("mode")
local motion = require("motion")

local DELETED_NONE = 0
local DELETED_LINES = 1
local DELETED_WORDS = 2

local deleted_mode = DELETED_NONE
local deleted_lines = {}
local deleted_words = {}

local function delete_lines(number)
	mode.show()

	deleted_lines = {}
	for i = 1, number do
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		local line = cursor:Buf():Line(cursor.Loc.Y)
		table.insert(deleted_lines, line)
		micro.CurPane():DeleteLine()
		--[[
		local start_loc = buffer.Loc(0, cursor.Loc.Y)
		local end_loc = buffer.Loc(0, cursor.Loc.Y + 1)
		cursor:Buf():Remove(start_loc, end_loc)
		]]

		local last_line_index = cursor:Buf():LinesNum() - 1
		if cursor.Loc.Y == last_line_index then
			local line = cursor:Buf():Line(cursor.Loc.Y)
			local length = utf8.RuneCount(line)
			if length < 1 then
				cursor.Loc.Y = math.max(cursor.Loc.Y - 1, 0)
			end
		end
		local line = cursor:Buf():Line(cursor.Loc.Y)
		local spaces = line:match("^(%s*).*$")
		cursor.Loc.X = #spaces
		motion.update_virtual_cursor()
	end

	deleted_mode = DELETED_LINES
end

local function copy_lines(number)
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local last_line_index = cursor:Buf():LinesNum() - 1
	local line = cursor:Buf():Line(last_line_index)
	local length = utf8.RuneCount(line)
	if length < 1 then
		last_line_index = math.max(last_line_index - 1, 0)
	end
	if cursor.Loc.Y + number - 1 > last_line_index then
		micro.InfoBar():Error("line number out of range: " .. cursor.Loc.Y + number .. " > " .. last_line_index + 1)
		return
	end

	deleted_lines = {}
	for i = 1, number do
		local line = cursor:Buf():Line(cursor.Loc.Y + i - 1)
		table.insert(deleted_lines, line)
	end

	deleted_mode = DELETED_LINES
end

local function delete_chars(number)
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	if length < 1 then
		micro.InfoBar():Error("no character in the line")
		return
	end

	local saved_x = cursor.Loc.X

	deleted_words = {}

	local n = math.min(number, length - cursor.Loc.X)

	local str = line
	local start_offset = 0
	local cursor_x = cursor.Loc.X
	for _ = 1, cursor_x do
		local r, size = utf8.DecodeRuneInString(str)
		str = str:sub(1 + size)
		start_offset = start_offset + size
	end

	local end_offset = start_offset
	for _ = 1, n do
		local r, size = utf8.DecodeRuneInString(str)
		str = str:sub(1 + size)
		end_offset = end_offset + size
	end

	table.insert(deleted_words, line:sub(1 + start_offset, end_offset))

	for _ = 1, n do
		micro.CurPane():Delete()
	end

	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(cursor.Loc.X + 1, length - 1)

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(editor.TICK_DELAY, function()
			line = cursor:Buf():Line(cursor.Loc.Y)
			length = utf8.RuneCount(line)
			cursor.Loc.X = math.min(saved_x, math.max(length - 1, 0))
			motion.update_virtual_cursor()

			deleted_mode = DELETED_WORDS
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(editor.TICK_DELAY, function()
			line = cursor:Buf():Line(cursor.Loc.Y)
			length = utf8.RuneCount(line)
			cursor.Loc.X = math.min(saved_x, math.max(length - 1, 0))
			motion.update_virtual_cursor()

			deleted_mode = DELETED_WORDS
		end)
	end
end

local function delete_chars_backward(number)
	mode.show()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	if length < 1 then
		micro.InfoBar():Error("no character in the line")
		return
	end

	local cursor_x = cursor.Loc.X
	local saved_x = cursor_x

	deleted_words = {}

	local n = math.min(number, cursor_x)

	local str = line
	local end_offset = 0
	for _ = 1, cursor_x do
		local r, size = utf8.DecodeRuneInString(str)
		str = str:sub(1 + size)
		end_offset = end_offset + size
	end

	local start_offset = end_offset
	for _ = 1, n do
		local r, size = utf8.DecodeLastRuneInString(str)
		str = str:sub(1, -size - 1)
		start_offset = start_offset - size
	end

	table.insert(deleted_words, line:sub(1 + start_offset, end_offset))

	cursor.Loc.X = cursor.Loc.X - n
	for _ = 1, n do
		micro.CurPane():Delete()
	end

	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(editor.TICK_DELAY, function()
			cursor.Loc.X = math.max(saved_x - n, 0)
			motion.update_virtual_cursor()

			deleted_mode = DELETED_WORDS
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(editor.TICK_DELAY, function()
			cursor.Loc.X = math.max(saved_x - n, 0)
			motion.update_virtual_cursor()

			deleted_mode = DELETED_WORDS
		end)
	end
end

local function paste_below(number)
	mode.show()

	if deleted_mode == DELETED_NONE then
		micro.InfoBar():Error("no copied lines/words yet")
		return
	end

	local text
	if deleted_mode == DELETED_LINES then
		text = "\n" .. table.concat(deleted_lines, "\n")
	elseif deleted_mode == DELETED_WORDS then
		text = table.concat(deleted_words)
	else -- program error
		micro.InfoBar:Error("paste_below: invalid deleted mode = " .. deleted_mode)
		return
	end

	mode.insert()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local saved_length = utf8.RuneCount(line)
	local saved_x = cursor.Loc.X
	local saved_y
	for _ = 1, number do
		saved_y = cursor.Loc.Y
		if deleted_mode == DELETED_LINES then
			local line = cursor:Buf():Line(cursor.Loc.Y)
			cursor.Loc.X = utf8.RuneCount(line)
		elseif deleted_mode == DELETED_WORDS then
			local line = cursor:Buf():Line(cursor.Loc.Y)
			local length = utf8.RuneCount(line)
			cursor.Loc.X = math.min(saved_x + 1, math.max(length - 1, 0))
		end
		cursor:Buf():Insert(buffer.Loc(cursor.Loc.X, cursor.Loc.Y), text)
		if deleted_mode == DELETED_LINES then
			cursor.Loc.Y = saved_y + 1
		end
	end

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(editor.TICK_DELAY, function()
			if deleted_mode == DELETED_LINES then
				cursor.Loc.Y = saved_y + 1

				local line = cursor:Buf():Line(cursor.Loc.Y)
				local spaces = line:match("^(%s*).*$")
				cursor.Loc.X = #spaces
				motion.update_virtual_cursor()
			elseif deleted_mode == DELETED_WORDS then
				if saved_length < 1 then
					cursor.Loc.X = saved_x
				else
					cursor.Loc.X = saved_x + 1
				end
				motion.update_virtual_cursor()
			else
				micro.InfoBar:Error("paste_below After: invalid deleted mode = " .. deleted_mode)
			end

			mode.command()
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(editor.TICK_DELAY, function()
			if deleted_mode == DELETED_LINES then
				cursor.Loc.Y = saved_y + 1

				local line = cursor:Buf():Line(cursor.Loc.Y)
				local spaces = line:match("^(%s*).*$")
				cursor.Loc.X = #spaces
				motion.update_virtual_cursor()
			elseif deleted_mode == DELETED_WORDS then
				if saved_length < 1 then
					cursor.Loc.X = saved_x
				else
					cursor.Loc.X = saved_x + 1
				end
				motion.update_virtual_cursor()
			else
				micro.InfoBar:Error("paste_below After: invalid deleted mode = " .. deleted_mode)
			end

			mode.command()
		end)
	end
end

local function paste_above(number)
	mode.show()

	if deleted_mode == DELETED_NONE then
		micro.InfoBar():Error("no copied lines/words yet")
		return
	end

	local text
	if deleted_mode == DELETED_LINES then
		text = table.concat(deleted_lines, "\n") .. "\n"
	elseif deleted_mode == DELETED_WORDS then
		text = table.concat(deleted_words)
	else -- program errorlines
		micro.InfoBar:Error("paste_above: invalid deleted mode = " .. deleted_mode)
		return
	end

	mode.insert()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local saved_x = cursor.Loc.X
	local saved_y
	for _ = 1, number do
		saved_y = cursor.Loc.Y
		if deleted_mode == DELETED_LINES then
			cursor.Loc.X = 0
		end
		cursor:Buf():Insert(buffer.Loc(cursor.Loc.X, cursor.Loc.Y), text)
		if deleted_mode == DELETED_LINES then
			cursor.Loc.Y = saved_y
		end
	end

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(editor.TICK_DELAY, function()
			if deleted_mode == DELETED_LINES then
				cursor.Loc.Y = saved_y

				local line = cursor:Buf():Line(cursor.Loc.Y)
				local spaces = line:match("^(%s*).*$")
				cursor.Loc.X = #spaces
				motion.update_virtual_cursor()
			elseif deleted_mode == DELETED_WORDS then
				cursor.Loc.X = saved_x
				motion.update_virtual_cursor()
			else -- program error
				micro.InfoBar:Error("paste_above After: invalid deleted mode = " .. deleted_mode)
			end

			mode.command()
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(editor.TICK_DELAY, function()
			if deleted_mode == DELETED_LINES then
				cursor.Loc.Y = saved_y

				local line = cursor:Buf():Line(cursor.Loc.Y)
				local spaces = line:match("^(%s*).*$")
				cursor.Loc.X = #spaces
				motion.update_virtual_cursor()
			elseif deleted_mode == DELETED_WORDS then
				cursor.Loc.X = saved_x
				motion.update_virtual_cursor()
			else
				micro.InfoBar:Error("paste_above AfterFunc: invalid deleted mode = " .. deleted_mode)
			end

			mode.command()
		end)
	end
end

M.delete_lines = delete_lines
M.copy_lines = copy_lines
M.delete_chars = delete_chars
M.delete_chars_backward = delete_chars_backward
M.paste_below = paste_below
M.paste_above = paste_above

return M
