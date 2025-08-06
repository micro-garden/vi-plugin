VERSION = "0.0.0"

local micro = import("micro")
local config = import("micro/config")
local utf8 = import("unicode/utf8")

-- internal constants
local TextEventInsert = 1
local TextEventReplace = 0
local TextEventRemove = -1

-- vi modes
local CommandMode = 0
local InsertMode = 1

-- states
local vi_mode = InsertMode
local command_buffer = ""
local command_number = 1
local command_edit = nil

local virtual_cursor_x = 0

local function show_mode()
	local mode_line
	if vi_mode == CommandMode then
		mode_line = "vi command mode"
	elseif vi_mode == InsertMode then
		mode_line = "vi insert mode"
	else -- program error
		micro.InfoBar():Error("show_mode: invalid mode = " .. vi_mode)
		return
	end
	micro.InfoBar():Message(mode_line .. " [" .. command_buffer .. "]")
end

function ViCmd()
	vi_mode = CommandMode
	command_buffer = ""
	command_number = 1
	command_edit = nil

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	virtual_cursor_x = cursor.Loc.X

	show_mode()
end

local function bytes_to_string(array)
	local buf = {}
	for i = 1, #array do
		table.insert(buf, string.char(array[i]))
	end
	return table.concat(buf)
end

function move_left(number)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor:ResetSelection()

	cursor.Loc.X = math.max(cursor.Loc.X - number, 0)

	virtual_cursor_x = cursor.Loc.X
end

function move_right(number)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor:ResetSelection()

	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(cursor.Loc.X + number, math.max(length - 1, 0))

	virtual_cursor_x = cursor.Loc.X
end

function move_up(number)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor:ResetSelection()

	cursor.Loc.Y = math.max(cursor.Loc.Y - number, 0)

	micro.CurPane():Relocate()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(virtual_cursor_x, math.max(length - 1, 0))
end

function move_down(number)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor:ResetSelection()

	local last_line_index = cursor:Buf():LinesNum() - 1
	local y = math.min(cursor.Loc.Y + number, last_line_index)
	if y == last_line_index then
		local line = cursor:Buf():Line(y)
		local length = utf8.RuneCount(line)
		if length < 1 then
			y = math.max(y - 1, 0)
		end
	end
	cursor.Loc.Y = y

	micro.CurPane():Relocate()
	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(virtual_cursor_x, math.max(length - 1, 0))
end

function onBeforeTextEvent(buf, ev)
	if vi_mode == InsertMode then
		return true
	end

	if ev.EventType == TextEventRemove or ev.EventType == TextEventReplace then
		return true
	end

	-- assert
	if ev.EventType ~= TextEventInsert then -- program error
		micro.InfoBar():Error("Invalid text event type = ev.EventType")
		return true
	end

	if #ev.Deltas ~= 1 then
		return true
	end

	-- Text is byte array
	local text = bytes_to_string(ev.Deltas[1].Text)

	-- pass through pasted long text
	if #text ~= 1 then
		return true
	end

	ev.Deltas[1].Text = ""

	command_buffer = command_buffer .. text

	local number_str, edit, move = command_buffer:match("^(%d*)([i]-)([hjkl]*)$")

	local number = 1
	if #number_str > 0 then
		number = tonumber(number_str)
	end

	if edit == "i" then
		vi_mode = InsertMode
		command_buffer = ""
		show_mode()

		command_number = number
		command_edit = edit
		return true
	elseif move == "h" then
		command_buffer = ""
		show_mode()

		move_left(number)
		return true
	elseif move == "j" then
		command_buffer = ""
		show_mode()

		move_down(number)
		return true
	elseif move == "k" then
		command_buffer = ""
		show_mode()

		move_up(number)
		return true
	elseif move == "l" then
		command_buffer = ""
		show_mode()

		move_right(number)
		return true
	end

	show_mode()
	return true
end

function init()
	config.MakeCommand("vi", ViCmd, config.NoComplete)
	config.TryBindKey("Escape", "Escape,Deselect,ClearInfo,RemoveAllMultiCursors,UnhighlightSearch,lua:vi.ViCmd", false)
	config.AddRuntimeFile("vi", config.RTHelp, "help/vi.md")
end
