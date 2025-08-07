M = {}

local micro = import("micro")
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

local deleted_lines = {}

local function delete_lines(number)
	mode.show()

	deleted_lines = {}
	for i = 1, number do
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		local line = cursor:Buf():Line(cursor.Loc.Y)
		table.insert(deleted_lines, line)
		micro.CurPane():DeleteLine()

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
end

local function paste_below(number)
	mode.show()

	if #deleted_lines < 1 then
		micro.InfoBar():Error("no copied lines yet")
		return
	end

	mode.insert()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local saved_y
	local text = "\n" .. table.concat(deleted_lines, "\n")
	for _ = 1, number do
		saved_y = cursor.Loc.Y
		local line = cursor:Buf():Line(cursor.Loc.Y)
		cursor.Loc.X = utf8.RuneCount(line)
		cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), text)
		cursor.Loc.Y = saved_y + 1
	end

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(editor.TICK_DELAY, function()
			cursor.Loc.Y = saved_y + 1

			local line = cursor:Buf():Line(cursor.Loc.Y)
			local spaces = line:match("^(%s*).*$")
			cursor.Loc.X = #spaces
			virtual_cursor_x = cursor.Loc.X

			mode.command()
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(editor.TICK_DELAY, function()
			cursor.Loc.Y = saved_y + 1

			local line = cursor:Buf():Line(cursor.Loc.Y)
			local spaces = line:match("^(%s*).*$")
			cursor.Loc.X = #spaces
			virtual_cursor_x = cursor.Loc.X

			mode.command()
		end)
	end
end

local function paste_above(number)
	mode.show()

	if #deleted_lines < 1 then
		micro.InfoBar():Error("no copied lines yet")
		return
	end

	mode.insert()

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local saved_y
	local text = table.concat(deleted_lines, "\n") .. "\n"
	for _ = 1, number do
		saved_y = cursor.Loc.Y
		cursor.Loc.X = 0
		cursor:Buf():Insert(cursor.Loc:Move(0, cursor:Buf()), text)
		cursor.Loc.Y = saved_y
	end

	-- micro.After requires micro v2.0.14-rc1
	if type(micro.After) == "function" then
		micro.After(editor.TICK_DELAY, function()
			cursor.Loc.Y = saved_y

			local line = cursor:Buf():Line(cursor.Loc.Y)
			local spaces = line:match("^(%s*).*$")
			cursor.Loc.X = #spaces
			virtual_cursor_x = cursor.Loc.X

			mode.command()
		end)
	elseif
		-- time.AfterFunc requires micro before v2.0.14-rc1
		type(time.AfterFunc) == "function"
	then
		time.AfterFunc(editor.TICK_DELAY, function()
			cursor.Loc.Y = saved_y

			local line = cursor:Buf():Line(cursor.Loc.Y)
			local spaces = line:match("^(%s*).*$")
			cursor.Loc.X = #spaces
			virtual_cursor_x = cursor.Loc.X

			mode.command()
		end)
	end
end

M.delete_lines = delete_lines
M.copy_lines = copy_lines
M.paste_below = paste_below
M.paste_above = paste_above

return M
