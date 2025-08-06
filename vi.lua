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

	local last_line_index = cursor:Buf():LinesNum() - 1
	if cursor.Loc.Y == last_line_index then
		local line = cursor:Buf():Line(cursor.Loc.Y)
		local length = utf8.RuneCount(line)
		if length < 1 then
			cursor.Loc.Y = math.max(cursor.Loc.Y - 1, 0)

			micro.CurPane():Relocate()
		end
	end

	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(cursor.Loc.X, math.max(length - 1, 0))

	micro.CurPane():Relocate()
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

	micro.CurPane():Relocate()
	virtual_cursor_x = cursor.Loc.X
end

function move_right(number)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor:ResetSelection()

	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.min(cursor.Loc.X + number, math.max(length - 1, 0))

	micro.CurPane():Relocate()
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

	micro.CurPane():Relocate()
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

	micro.CurPane():Relocate()
end

function move_next_line_start(number)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor:ResetSelection()

	local last_line_index = cursor:Buf():LinesNum() - 1
	if cursor.Loc.Y == last_line_index then
		return -- vi error
	elseif cursor.Loc.Y == last_line_index - 1 then
		local line = cursor:Buf():Line(last_line_index)
		local length = utf8.RuneCount(line)
		if length < 1 then
			return -- vi error
		end
	end

	move_line_start()
	move_down(number)
end

function move_line_start()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor:ResetSelection()

	cursor.Loc.X = 0

	micro.CurPane():Relocate()
	virtual_cursor_x = cursor.Loc.X
end

-- XXX not work on indented lines
function move_line_end()
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor:ResetSelection()

	local line = cursor:Buf():Line(cursor.Loc.Y)
	local length = utf8.RuneCount(line)
	cursor.Loc.X = math.max(length - 1, 0)

	micro.CurPane():Relocate()
	virtual_cursor_x = cursor.Loc.X
end

-- XXX incompatible
function move_next_word(number)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor:ResetSelection()

	for _ = 1, number do
		local line = cursor:Buf():Line(cursor.Loc.Y)
		local length = utf8.RuneCount(line)

		if cursor.Loc.X == length - 1 then
			local last_line_index = cursor:Buf():LinesNum() - 1
			if cursor.Loc.Y == last_line_index - 1 then
				local line = cursor:Buf():Line(last_line_index)
				local length = utf8.RuneCount(line)
				if length < 1 then
					break -- vi error
				end
			end

			cursor.Loc.X = length
			cursor:WordRight() -- XXX micro method
		else
			cursor:WordRight() -- XXX micro method
			cursor.Loc.X = math.min(cursor.Loc.X + 1, math.max(length - 1, 0))
		end
	end

	micro.CurPane():Relocate()
	virtual_cursor_x = cursor.Loc.X
end

-- XXX incompatible
function move_prev_word(number)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	cursor:ResetSelection()

	for _ = 1, number do
		cursor:WordLeft() -- XXX micro method
	end

	micro.CurPane():Relocate()
	virtual_cursor_x = cursor.Loc.X
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

	local number_str, edit, move
	if command_buffer:match("^0$") then
		number_str, edit, move = "", "", "0"
	else
		number_str, edit, move = command_buffer:match("^(%d*)([iZ]*)([hjkl\n0%$wb]*)$")
	end

	if not number_str then
		show_mode()
		return true
	end

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
	elseif move == "\n" then
		command_buffer = ""
		show_mode()

		move_next_line_start(number)
		return true
	elseif move == "0" then
		command_buffer = ""
		show_mode()

		move_line_start()
		return true
	elseif move == "$" then
		command_buffer = ""
		show_mode()

		move_line_end()
		return true
	elseif move == "w" then
		command_buffer = ""
		show_mode()

		move_next_word(number)
		return true
	elseif move == "b" then
		command_buffer = ""
		show_mode()

		move_prev_word(number)
		return true
	elseif edit == "ZZ" then
		command_buffer = ""
		show_mode()

		micro.CurPane():QuitCmd({})
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
