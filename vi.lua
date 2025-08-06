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

	if text == "i" then
		vi_mode = InsertMode
		command_buffer = ""
		show_mode()

		ev.Deltas[1].Text = ""
		return true
	elseif text == "h" then
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		cursor:ResetSelection()

		if cursor.Loc.X > 0 then
			cursor.Loc.X = cursor.Loc.X - 1
		end

		virtual_cursor_x = cursor.Loc.X

		ev.Deltas[1].Text = ""
		return true
	elseif text == "j" then
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		cursor:ResetSelection()

		local last_line_index = cursor:Buf():LinesNum() - 1
		if cursor.Loc.Y == last_line_index - 1 then
			local line = cursor:Buf():Line(last_line_index)
			local length = utf8.RuneCount(line)
			if length > 0 then
				cursor.Loc.Y = cursor.Loc.Y + 1
			end
		elseif cursor.Loc.Y < last_line_index then
			cursor.Loc.Y = cursor.Loc.Y + 1
		end

		micro.CurPane():Relocate()
		local line = cursor:Buf():Line(cursor.Loc.Y)
		local length = utf8.RuneCount(line)
		cursor.Loc.X = math.min(virtual_cursor_x, math.max(length - 1, 0))

		ev.Deltas[1].Text = ""
		return true
	elseif text == "k" then
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		cursor:ResetSelection()

		if cursor.Loc.Y > 0 then
			cursor.Loc.Y = cursor.Loc.Y - 1
		end

		micro.CurPane():Relocate()
		local line = cursor:Buf():Line(cursor.Loc.Y)
		local length = utf8.RuneCount(line)
		cursor.Loc.X = math.min(virtual_cursor_x, math.max(length - 1, 0))

		ev.Deltas[1].Text = ""
		return true
	elseif text == "l" then
		local cursor = micro.CurPane().Buf:GetActiveCursor()
		cursor:ResetSelection()

		local line = cursor:Buf():Line(cursor.Loc.Y)
		local length = utf8.RuneCount(line)
		if cursor.Loc.X < length - 1 then
			cursor.Loc.X = cursor.Loc.X + 1
		end

		virtual_cursor_x = cursor.Loc.X

		ev.Deltas[1].Text = ""
		return true
	end

	command_buffer = command_buffer .. text

	show_mode()

	ev.Deltas[1].Text = ""
	return true
end

function init()
	config.MakeCommand("vi", ViCmd, config.NoComplete)
	config.TryBindKey("Escape", "Escape,Deselect,ClearInfo,RemoveAllMultiCursors,UnhighlightSearch,lua:vi.ViCmd", false)
	config.AddRuntimeFile("vi", config.RTHelp, "help/vi.md")
end
